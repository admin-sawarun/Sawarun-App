import { readFileSync } from 'node:fs';
import { z } from 'zod';
import { db, admin, firebaseAuth } from '../config/firebase.js';
import { env } from '../config/env.js';
import { ApiError } from '../utils/ApiError.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { istDay, istDayStart, lastIstDays, toIso } from '../services/stats.service.js';
import { removePost } from '../services/moderation.service.js';
import { logAdminAction } from '../services/audit.service.js';

/**
 * Admin console endpoints: posts moderation, analyses log, affiliate
 * performance, admin team, audit log and system info.
 * All mounted under /api/admin (requireAuth + adminOnly).
 */

const BACKEND_VERSION = (() => {
  try {
    return JSON.parse(readFileSync(new URL('../../package.json', import.meta.url), 'utf8')).version || null;
  } catch {
    return null;
  }
})();

/* ─────────────── helpers ─────────────── */

function intParam(v, def, min, max) {
  const n = parseInt(v, 10);
  return Math.min(Math.max(Number.isFinite(n) ? n : def, min), max);
}

/**
 * Page a query ordered by [field] desc using a doc-id cursor.
 * → { docs, nextCursor }
 */
async function pageByCursor(collection, field, limit, cursor) {
  let query = db.collection(collection).orderBy(field, 'desc');
  if (cursor) {
    const cur = await db.collection(collection).doc(cursor).get();
    if (cur.exists && cur.get(field) != null) query = query.startAfter(cur);
  }
  const snap = await query.limit(limit + 1).get();
  const docs = snap.docs.slice(0, limit);
  const nextCursor = snap.docs.length > limit ? docs[docs.length - 1].id : null;
  return { docs, nextCursor };
}

/** uid → users/{uid} data for a set of uids (missing ones omitted). */
async function loadUsers(uids) {
  const unique = [...new Set(uids.filter(Boolean))];
  const out = {};
  if (!unique.length) return out;
  try {
    const snaps = await db.getAll(...unique.map((u) => db.collection('users').doc(u)));
    for (const s of snaps) if (s.exists) out[s.id] = s.data();
  } catch (err) {
    console.warn('[admin] user lookup failed:', err.message);
  }
  return out;
}

/** id → doc data for a collection (missing ones omitted). */
async function loadDocs(collection, ids) {
  const unique = [...new Set(ids.filter(Boolean))];
  const out = {};
  if (!unique.length) return out;
  try {
    const snaps = await db.getAll(...unique.map((id) => db.collection(collection).doc(id)));
    for (const s of snaps) if (s.exists) out[s.id] = s.data();
  } catch (err) {
    console.warn(`[admin] ${collection} lookup failed:`, err.message);
  }
  return out;
}

async function countOf(query) {
  try {
    return (await query.count().get()).data().count;
  } catch (err) {
    console.warn('[admin] count failed:', err.code || '', err.message);
    return null;
  }
}

/* ─────────────── 1. Posts moderation ─────────────── */

/**
 * GET /api/admin/posts?limit=40&cursor=<postId>&q=<text>
 * → { ok, data: [{ id, imageUrl, caption, style, likes, createdAt, authorUid,
 *                   authorName, authorUsername, authorPhotoURL }], nextCursor }
 * q filters the fetched page in memory (caption / author name / username).
 */
export const listPosts = asyncHandler(async (req, res) => {
  const limit = intParam(req.query.limit, 40, 1, 100);
  const cursor = (req.query.cursor || '').toString().trim();
  const q = (req.query.q || '').toString().trim().toLowerCase();

  const { docs, nextCursor } = await pageByCursor('posts', 'createdAt', limit, cursor);
  const users = await loadUsers(docs.map((d) => d.get('authorUid')));

  let posts = docs.map((d) => {
    const p = d.data();
    const u = users[p.authorUid] || {};
    return {
      id: d.id,
      imageUrl: p.imageUrl || null,
      caption: p.caption || '',
      style: p.style || null,
      likes: Number(p.likes) || 0,
      createdAt: toIso(p.createdAt),
      authorUid: p.authorUid || null,
      authorName: p.authorName || u.name || u.username || 'Savarun User',
      authorUsername: u.username || null,
      authorPhotoURL: p.authorPhoto || u.photoURL || u.photoUrl || null,
    };
  });
  if (q) {
    posts = posts.filter((p) =>
      [p.caption, p.authorName, p.authorUsername].some((v) => v && String(v).toLowerCase().includes(q))
    );
  }

  res.json({ ok: true, data: posts, nextCursor });
});

/** DELETE /api/admin/posts/:id — post + its postLikes + its Storage image. */
export const deletePost = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const snap = await db.collection('posts').doc(id).get();
  if (!snap.exists) throw ApiError.notFound('Post not found');
  const authorUid = snap.get('authorUid') || null;
  const caption = snap.get('caption') || '';
  await removePost(id);
  logAdminAction(req, 'post.delete', { type: 'post', id }, { authorUid, caption });
  res.json({ ok: true });
});

/* ─────────────── 2. Outfit analyses log ─────────────── */

/**
 * GET /api/admin/analyses?limit=40&cursor=<id>
 * → { ok, data: [{ id, uid, userName, userPhotoURL, fitScore, topStyle, styleDna, imageUrl, createdAt }], nextCursor }
 */
export const listAnalyses = asyncHandler(async (req, res) => {
  const limit = intParam(req.query.limit, 40, 1, 100);
  const cursor = (req.query.cursor || '').toString().trim();

  const { docs, nextCursor } = await pageByCursor('analysesLog', 'createdAt', limit, cursor);
  const users = await loadUsers(docs.map((d) => d.get('uid')));

  const data = docs.map((d) => {
    const a = d.data();
    const u = users[a.uid] || null;
    return {
      id: d.id,
      uid: a.uid || null,
      userName: u ? u.name || u.username || 'Savarun User' : 'Deleted user',
      userPhotoURL: u ? u.photoURL || u.photoUrl || null : null,
      fitScore: a.fitScore ?? null,
      topStyle: a.topStyle || null,
      styleDna: Array.isArray(a.styleDna) ? a.styleDna : [],
      imageUrl: a.imageUrl || null,
      createdAt: toIso(a.createdAt),
    };
  });

  res.json({ ok: true, data, nextCursor });
});

const SUMMARY_CAP = 5000;

/**
 * GET /api/admin/analyses/summary?days=30   (1..365)
 * → { ok, data: { total, averageScore, buckets: {'0-39','40-59','60-79','80-100'}, topStyles: [{style, count}] } }
 * Computed over at most 5000 analysesLog docs with createdAt >= start of the window (IST days).
 */
export const analysesSummary = asyncHandler(async (req, res) => {
  const n = intParam(req.query.days, 30, 1, 365);
  const start = istDayStart(lastIstDays(n)[0]);

  const snap = await db
    .collection('analysesLog')
    .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(start))
    .select('fitScore', 'topStyle')
    .limit(SUMMARY_CAP)
    .get();

  const buckets = { '0-39': 0, '40-59': 0, '60-79': 0, '80-100': 0 };
  const styles = new Map();
  let sum = 0;
  let scored = 0;
  for (const d of snap.docs) {
    const score = Number(d.get('fitScore'));
    if (Number.isFinite(score)) {
      sum += score;
      scored += 1;
      if (score < 40) buckets['0-39'] += 1;
      else if (score < 60) buckets['40-59'] += 1;
      else if (score < 80) buckets['60-79'] += 1;
      else buckets['80-100'] += 1;
    }
    const style = d.get('topStyle');
    if (style) styles.set(style, (styles.get(style) || 0) + 1);
  }

  res.json({
    ok: true,
    data: {
      total: snap.size,
      averageScore: scored ? Math.round((sum / scored) * 10) / 10 : 0,
      buckets,
      topStyles: [...styles.entries()]
        .map(([style, count]) => ({ style, count }))
        .sort((a, b) => b.count - a.count)
        .slice(0, 10),
    },
  });
});

/* ─────────────── 3. Affiliate performance ─────────────── */

const CLICK_SCAN_CAP = 50000;

/**
 * GET /api/admin/affiliate/performance?days=30   (1..365)
 * → { ok, data: { totalClicks, days: [YYYY-MM-DD], clicks: [n],
 *                 topProducts: [{id, name, brandName, imageUrl, clicks}], topBrands: [{id, name, clicks}] } }
 * From the affiliateClicks log (field `at`), days in Asia/Kolkata.
 */
export const affiliatePerformance = asyncHandler(async (req, res) => {
  const n = intParam(req.query.days, 30, 1, 365);
  const days = lastIstDays(n);
  const index = new Map(days.map((d, i) => [d, i]));
  const start = istDayStart(days[0]);

  const snap = await db
    .collection('affiliateClicks')
    .where('at', '>=', admin.firestore.Timestamp.fromDate(start))
    .select('at', 'productId', 'brandId')
    .limit(CLICK_SCAN_CAP)
    .get();

  const clicks = days.map(() => 0);
  const byProduct = new Map();
  const byBrand = new Map();
  for (const d of snap.docs) {
    const at = d.get('at')?.toDate?.();
    if (at) {
      const i = index.get(istDay(at));
      if (i !== undefined) clicks[i] += 1;
    }
    const pid = d.get('productId');
    const bid = d.get('brandId');
    if (pid) byProduct.set(pid, (byProduct.get(pid) || 0) + 1);
    if (bid) byBrand.set(bid, (byBrand.get(bid) || 0) + 1);
  }

  const top = (m) =>
    [...m.entries()]
      .sort((a, b) => b[1] - a[1])
      .slice(0, 10);
  const topP = top(byProduct);
  const topB = top(byBrand);
  const [products, brands] = await Promise.all([
    loadDocs('products', topP.map(([id]) => id)),
    loadDocs('brands', topB.map(([id]) => id)),
  ]);
  // Fallback brand names from products when a brand doc is gone.
  const brandNameFromProducts = {};
  for (const p of Object.values(products)) {
    if (p.brandId && p.brandName) brandNameFromProducts[p.brandId] = p.brandName;
  }

  res.json({
    ok: true,
    data: {
      totalClicks: snap.size,
      days,
      clicks,
      topProducts: topP.map(([id, count]) => ({
        id,
        name: products[id]?.name || 'Deleted product',
        brandName: products[id]?.brandName || null,
        imageUrl: products[id]?.imageUrl || null,
        clicks: count,
      })),
      topBrands: topB.map(([id, count]) => ({
        id,
        name: brands[id]?.name || brandNameFromProducts[id] || 'Deleted brand',
        clicks: count,
      })),
    },
  });
});

/* ─────────────── 4. Admin team ─────────────── */

/** Every Firebase Auth user with customClaims.admin === true. */
async function listAdminUsers() {
  const out = [];
  let pageToken;
  do {
    const page = await firebaseAuth.listUsers(1000, pageToken);
    for (const u of page.users) if (u.customClaims?.admin === true) out.push(u);
    pageToken = page.pageToken;
  } while (pageToken);
  return out;
}

const metaIso = (v) => (v ? new Date(v).toISOString() : null);

/** GET /api/admin/admins → { ok, data: [{ uid, email, displayName, lastSignInAt, createdAt, disabled }] } */
export const listAdmins = asyncHandler(async (_req, res) => {
  const admins = await listAdminUsers();
  res.json({
    ok: true,
    data: admins.map((u) => ({
      uid: u.uid,
      email: u.email || null,
      displayName: u.displayName || null,
      lastSignInAt: metaIso(u.metadata?.lastSignInTime),
      createdAt: metaIso(u.metadata?.creationTime),
      disabled: !!u.disabled,
    })),
  });
});

const AddAdminBody = z.object({
  email: z.string().trim().toLowerCase().email(),
  password: z.string().optional(),
});

/**
 * POST /api/admin/admins  body: { email, password? }
 * Existing user → grant the admin claim. Unknown email + password (≥8) →
 * create the user (emailVerified) and grant. → { ok, data: { uid, email, created } }
 */
export const addAdmin = asyncHandler(async (req, res) => {
  const parsed = AddAdminBody.safeParse(req.body);
  if (!parsed.success) throw ApiError.badRequest('A valid email is required');
  const { email, password } = parsed.data;

  let user = null;
  let created = false;
  try {
    user = await firebaseAuth.getUserByEmail(email);
  } catch (err) {
    if (err.code !== 'auth/user-not-found') throw err;
  }

  if (!user) {
    if (!password) throw ApiError.badRequest('User not found — give a password to create it');
    if (password.length < 8) throw ApiError.badRequest('Password must be at least 8 characters');
    user = await firebaseAuth.createUser({ email, password, emailVerified: true });
    created = true;
  }

  await firebaseAuth.setCustomUserClaims(user.uid, { ...(user.customClaims || {}), admin: true });
  logAdminAction(req, 'admin.add', { type: 'user', id: user.uid }, { email, created });
  res.json({ ok: true, data: { uid: user.uid, email: user.email || email, created } });
});

/** DELETE /api/admin/admins/:uid — remove the admin claim + revoke sessions. */
export const removeAdmin = asyncHandler(async (req, res) => {
  const { uid } = req.params;
  if (uid === req.user.uid) throw ApiError.badRequest('You cannot remove yourself as admin');

  let user;
  try {
    user = await firebaseAuth.getUser(uid);
  } catch (err) {
    if (err.code === 'auth/user-not-found') throw ApiError.notFound('User not found');
    throw err;
  }
  if (user.customClaims?.admin !== true) throw ApiError.badRequest('This user is not an admin');

  const admins = await listAdminUsers();
  if (admins.filter((u) => u.uid !== uid).length === 0) {
    throw ApiError.badRequest('Cannot remove the last remaining admin');
  }

  const { admin: _drop, ...rest } = user.customClaims || {};
  await firebaseAuth.setCustomUserClaims(uid, Object.keys(rest).length ? rest : null);
  await firebaseAuth.revokeRefreshTokens(uid);
  logAdminAction(req, 'admin.remove', { type: 'user', id: uid }, { email: user.email || null });
  res.json({ ok: true });
});

/* ─────────────── 5. Audit log ─────────────── */

/**
 * GET /api/admin/audit?limit=50&cursor=<id>
 * → { ok, data: [{ id, adminEmail, action, targetType, targetId, details, at }], nextCursor }
 */
export const listAudit = asyncHandler(async (req, res) => {
  const limit = intParam(req.query.limit, 50, 1, 200);
  const cursor = (req.query.cursor || '').toString().trim();
  const { docs, nextCursor } = await pageByCursor('adminAudit', 'at', limit, cursor);
  res.json({
    ok: true,
    data: docs.map((d) => {
      const a = d.data();
      return {
        id: d.id,
        adminEmail: a.adminEmail || null,
        action: a.action || null,
        targetType: a.targetType || null,
        targetId: a.targetId || null,
        details: a.details || {},
        at: toIso(a.at),
      };
    }),
    nextCursor,
  });
});

/* ─────────────── 6. System info ─────────────── */

/** GET /api/admin/system — non-secret runtime info only (never keys). */
export const getSystem = asyncHandler(async (_req, res) => {
  const provider = env.ai.provider;
  const cfg = await db.collection('config').doc('home').get().catch(() => null);
  const featuredId = cfg?.exists ? cfg.get('featuredBrandId') : null;
  let featuredBrand = null;
  if (featuredId) {
    const b = await db.collection('brands').doc(featuredId).get().catch(() => null);
    featuredBrand = { id: featuredId, name: b?.exists ? b.get('name') || null : null };
  }

  const [users, brands, products, posts] = await Promise.all([
    countOf(db.collection('users')),
    countOf(db.collection('brands')),
    countOf(db.collection('products')),
    countOf(db.collection('posts')),
  ]);

  res.json({
    ok: true,
    data: {
      backendVersion: BACKEND_VERSION,
      nodeEnv: env.nodeEnv,
      aiProvider: provider,
      aiModel: env.ai[provider]?.visionModel || null,
      storageDriver: env.storage.driver,
      featuredBrand,
      counts: { users, brands, products, posts },
      links: {
        privacy: '/privacy-policy',
        terms: '/terms',
        accountDeletion: '/account-deletion',
        childSafety: '/child-safety',
      },
      serverTime: new Date().toISOString(),
    },
  });
});
