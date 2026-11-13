import { z } from 'zod';
import { db, admin, firebaseAuth } from '../config/firebase.js';
import { ApiError } from '../utils/ApiError.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { getWeights, setWeights } from '../services/fitScore.service.js';
import { istDay, istDayStart, lastIstDays, toDate, toIso } from '../services/stats.service.js';
import { logAdminAction } from '../services/audit.service.js';

/* ─────────────── Analytics Dashboard ─────────────── */

/**
 * GET /api/admin/analytics
 * Total users, daily-active count, trending style categories, top affiliate products.
 */
export const getAnalytics = asyncHandler(async (_req, res) => {
  const since = new Date(Date.now() - 24 * 60 * 60 * 1000);

  const [usersCount, dau, trendingStyles, topProducts] = await Promise.all([
    db.collection('users').count().get().then((s) => s.data().count),
    db
      .collection('users')
      .where('lastActiveAt', '>=', since)
      .count()
      .get()
      .then((s) => s.data().count)
      .catch(() => 0),
    computeWeeklyTrendingStyles(),
    // Top products by clicks — sort in memory to avoid needing an index and
    // to stay safe when the collection is empty.
    db
      .collection('products')
      .get()
      .then((snap) =>
        snap.docs
          .map((d) => ({ id: d.id, name: d.data().name, clicks: d.data().clicks || 0 }))
          .sort((a, b) => b.clicks - a.clicks)
          .slice(0, 5)
      )
      .catch(() => []),
  ]);

  const weekAgo = new Date(Date.now() - 7 * DAY_MS);
  const [totalPosts, totalAnalyses, activeToday, newUsersThisWeek] = await Promise.all([
    countOf(db.collection('posts')),
    countOf(db.collectionGroup('outfitHistory')),
    countOf(db.collection('activity').doc(istDay()).collection('users')),
    countUsersCreatedSince(weekAgo),
  ]);

  res.json({
    ok: true,
    data: {
      totalUsers: usersCount,
      dailyActiveUsers: dau,
      trendingStyles,
      topProducts,
      totalPosts,
      totalAnalyses,
      activeToday,
      newUsersThisWeek,
    },
  });
});

const DAY_MS = 24 * 60 * 60 * 1000;

/** count() aggregation → number, or null if the query fails (e.g. missing index). */
async function countOf(query) {
  try {
    return (await query.count().get()).data().count;
  } catch (err) {
    console.warn('[admin] count failed:', err.code || '', err.message);
    return null;
  }
}

/** users created at/after [since] — createdAt may be a Timestamp or an ISO string. */
async function countUsersCreatedSince(since) {
  const [ts, iso] = await Promise.all([
    countOf(db.collection('users').where('createdAt', '>=', admin.firestore.Timestamp.fromDate(since))),
    countOf(
      db
        .collection('users')
        .where('createdAt', '>=', since.toISOString())
        .where('createdAt', '<=', '')
    ),
  ]);
  if (ts == null && iso == null) return null;
  return (ts || 0) + (iso || 0);
}

/** Users docs with createdAt >= [since] (Timestamp or ISO string), merged. */
async function usersCreatedSince(since) {
  const [a, b] = await Promise.all([
    db
      .collection('users')
      .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(since))
      .select('createdAt')
      .get()
      .then((s) => s.docs)
      .catch(() => []),
    db
      .collection('users')
      .where('createdAt', '>=', since.toISOString())
      .where('createdAt', '<=', '')
      .select('createdAt')
      .get()
      .then((s) => s.docs)
      .catch(() => []),
  ]);
  return [...a, ...b];
}

/** Trending styles this week: sum of statsDaily.styles for the last 7 IST days. */
async function computeWeeklyTrendingStyles() {
  try {
    const days = lastIstDays(7);
    const snaps = await db.getAll(...days.map((d) => db.collection('statsDaily').doc(d)));
    const counts = new Map();
    for (const s of snaps) {
      const styles = s.exists ? s.data().styles || {} : {};
      for (const [category, n] of Object.entries(styles)) {
        counts.set(category, (counts.get(category) || 0) + (Number(n) || 0));
      }
    }
    if (counts.size) {
      return [...counts.entries()]
        .map(([category, weight]) => ({ category, weight }))
        .sort((a, b) => b.weight - a.weight)
        .slice(0, 8);
    }
  } catch (err) {
    console.warn('[admin] statsDaily trending failed:', err.message);
  }
  return computeTrendingStyles();
}

/**
 * GET /api/admin/analytics/timeseries?days=30   (1..90)
 * → { days: ['YYYY-MM-DD' oldest→newest, IST], signups, activeUsers, analyses, posts, clicks }
 */
export const getTimeseries = asyncHandler(async (req, res) => {
  const n = Math.min(Math.max(parseInt(req.query.days, 10) || 30, 1), 90);
  const days = lastIstDays(n);
  const index = new Map(days.map((d, i) => [d, i]));
  const start = istDayStart(days[0]);
  const startTs = admin.firestore.Timestamp.fromDate(start);
  const zeros = () => days.map(() => 0);

  /** Group docs by the IST day of [field] into a fresh series. */
  const groupBy = (docs, field) => {
    const out = zeros();
    for (const doc of docs) {
      const at = toDate(doc.get(field));
      if (!at) continue;
      const i = index.get(istDay(at));
      if (i !== undefined) out[i] += 1;
    }
    return out;
  };

  const [userDocs, activeUsers, statSnaps, postDocs] = await Promise.all([
    usersCreatedSince(start),
    Promise.all(
      days.map((d) => countOf(db.collection('activity').doc(d).collection('users')).then((c) => c || 0))
    ),
    db.getAll(...days.map((d) => db.collection('statsDaily').doc(d))),
    // Posts are created client-side, so count them straight from posts.createdAt.
    db
      .collection('posts')
      .where('createdAt', '>=', startTs)
      .select('createdAt')
      .get()
      .then((s) => s.docs)
      .catch(() => []),
  ]);

  const analyses = zeros();
  const statClicks = zeros();
  let clicksTrackedEveryDay = true;
  statSnaps.forEach((s, i) => {
    const data = s.exists ? s.data() : {};
    analyses[i] = Number(data.analyses) || 0;
    if (typeof data.clicks === 'number') statClicks[i] = data.clicks;
    else clicksTrackedEveryDay = false;
  });

  // statsDaily.clicks only exists from the day counters were deployed; fill
  // older days from the raw affiliateClicks log (field `at`).
  let clicks = statClicks;
  if (!clicksTrackedEveryDay) {
    const clickDocs = await db
      .collection('affiliateClicks')
      .where('at', '>=', startTs)
      .select('at')
      .get()
      .then((s) => s.docs)
      .catch(() => []);
    const logged = groupBy(clickDocs, 'at');
    clicks = statClicks.map((v, i) => Math.max(v, logged[i]));
  }

  res.json({
    ok: true,
    data: {
      days,
      signups: groupBy(userDocs, 'createdAt'),
      activeUsers,
      analyses,
      posts: groupBy(postDocs, 'createdAt'),
      clicks,
    },
  });
});

/** Aggregate style categories from recent outfit analyses across all users. */
async function computeTrendingStyles() {
  // No orderBy → no collection-group index required. We only aggregate style
  // percentages, so ordering doesn't matter.
  let snap;
  try {
    snap = await db.collectionGroup('outfitHistory').limit(500).get();
  } catch {
    return [];
  }
  const counts = new Map();
  for (const doc of snap.docs) {
    for (const s of doc.data().styleDna || []) {
      if (!s.category) continue;
      counts.set(s.category, (counts.get(s.category) || 0) + (Number(s.percentage) || 0));
    }
  }
  return [...counts.entries()]
    .map(([category, weight]) => ({ category, weight }))
    .sort((a, b) => b.weight - a.weight)
    .slice(0, 8);
    
}

/* ─────────────── Listings for the dashboard ─────────────── */

/**
 * Resolve email/phone for a set of users. Order of precedence:
 *   1. users/{uid}/private/contact  { email, phone }   (current schema)
 *   2. top-level users/{uid}.email / .phone             (older docs)
 *   3. Firebase Auth record email / phoneNumber          (only if still missing)
 * @param {string[]} uids
 * @param {Record<string, object>} [userDocs]  already-loaded users/{uid} data
 * @returns {Promise<Record<string, {email: string|null, phone: string|null}>>}
 */
async function getContacts(uids, userDocs = {}) {
  const contacts = {};
  if (!uids.length) return contacts;

  let snaps = [];
  try {
    snaps = await db.getAll(
      ...uids.map((uid) => db.collection('users').doc(uid).collection('private').doc('contact'))
    );
  } catch (err) {
    console.warn('[admin] contact lookup failed:', err.message);
  }
  const privateByUid = {};
  for (const s of snaps) if (s.exists) privateByUid[s.ref.parent.parent.id] = s.data();

  for (const uid of uids) {
    const p = privateByUid[uid] || {};
    const u = userDocs[uid] || {};
    contacts[uid] = { email: p.email || u.email || null, phone: p.phone || u.phone || null };
  }

  // Auth fallback for anyone still missing both, batched 100 at a time.
  const missing = uids.filter((uid) => !contacts[uid].email && !contacts[uid].phone);
  for (let i = 0; i < missing.length; i += 100) {
    try {
      const { users } = await firebaseAuth.getUsers(missing.slice(i, i + 100).map((uid) => ({ uid })));
      for (const au of users) {
        contacts[au.uid] = {
          email: contacts[au.uid].email || au.email || null,
          phone: contacts[au.uid].phone || au.phoneNumber || null,
        };
      }
    } catch (err) {
      console.warn('[admin] auth contact fallback failed:', err.message);
    }
  }
  return contacts;
}

const USER_STATUSES = ['active', 'banned', 'suspended', 'verified'];
const USER_SCAN_CAP = 2000;

/** Newest first; docs without a parseable createdAt sort last (by id for stability). */
function byCreatedDesc(a, b) {
  const ta = toDate(a.get('createdAt'))?.getTime() ?? -1;
  const tb = toDate(b.get('createdAt'))?.getTime() ?? -1;
  return tb - ta || (a.id < b.id ? -1 : a.id > b.id ? 1 : 0);
}

/**
 * GET /api/admin/users?q=&status=active|banned|suspended|verified&limit=50&cursor=<uid>
 * Users newest first with contact, moderation status and activity.
 * → { ok, data: [...], nextCursor: uid | null }
 *
 * Without q/status this pages through Firestore (orderBy createdAt desc,
 * startAfter cursor). With q/status it scans up to 2000 users in memory, then
 * pages the filtered list by cursor. postsCount/analysesCount are included
 * only when limit <= 50.
 */
export const listUsers = asyncHandler(async (req, res) => {
  const limit = Math.min(Math.max(parseInt(req.query.limit, 10) || 50, 1), 200);
  const q = (req.query.q || '').toString().trim().toLowerCase();
  const statusRaw = (req.query.status || '').toString().trim().toLowerCase();
  const status = USER_STATUSES.includes(statusRaw) ? statusRaw : '';
  const cursor = (req.query.cursor || '').toString().trim();

  let pageDocs;
  let nextCursor = null;
  let contacts;

  if (!q && !status) {
    let query = db.collection('users').orderBy('createdAt', 'desc');
    if (cursor) {
      const cur = await db.collection('users').doc(cursor).get();
      if (cur.exists && cur.get('createdAt') != null) query = query.startAfter(cur);
    }
    const snap = await query.limit(limit + 1).get();
    pageDocs = snap.docs.slice(0, limit);
    if (snap.docs.length > limit) {
      nextCursor = pageDocs[pageDocs.length - 1].id;
    } else {
      // Last page: orderBy skips docs that have no createdAt — append them so
      // older profiles stay visible (they are not paged further).
      const all = await db.collection('users').limit(USER_SCAN_CAP).get();
      const seen = new Set(pageDocs.map((d) => d.id));
      pageDocs = pageDocs.concat(
        all.docs.filter((d) => d.get('createdAt') == null && !seen.has(d.id))
      );
    }
    contacts = await getContacts(
      pageDocs.map((d) => d.id),
      Object.fromEntries(pageDocs.map((d) => [d.id, d.data()]))
    );
  } else {
    const all = (await db.collection('users').limit(USER_SCAN_CAP).get()).docs.sort(byCreatedDesc);
    let filtered = status
      ? all.filter((d) => (d.get('status') || 'active') === status)
      : all;
    if (q) {
      contacts = await getContacts(
        filtered.map((d) => d.id),
        Object.fromEntries(filtered.map((d) => [d.id, d.data()]))
      );
      filtered = filtered.filter((d) => {
        const u = d.data();
        const c = contacts[d.id] || {};
        return [u.name, u.username, c.email, c.phone, d.id].some(
          (v) => v && String(v).toLowerCase().includes(q)
        );
      });
    }
    let from = 0;
    if (cursor) {
      const i = filtered.findIndex((d) => d.id === cursor);
      if (i >= 0) from = i + 1;
    }
    pageDocs = filtered.slice(from, from + limit);
    if (from + limit < filtered.length) nextCursor = pageDocs[pageDocs.length - 1].id;
    if (!contacts) {
      contacts = await getContacts(
        pageDocs.map((d) => d.id),
        Object.fromEntries(pageDocs.map((d) => [d.id, d.data()]))
      );
    }
  }

  let counts = {};
  if (limit <= 50 && pageDocs.length) {
    const pairs = await Promise.all(
      pageDocs.map(async (d) => {
        const [postsCount, analysesCount] = await Promise.all([
          countOf(db.collection('posts').where('authorUid', '==', d.id)),
          countOf(db.collection('users').doc(d.id).collection('outfitHistory')),
        ]);
        return [d.id, { postsCount, analysesCount }];
      })
    );
    counts = Object.fromEntries(pairs);
  }

  const users = pageDocs.map((d) => ({
    ...userSummary(d, contacts[d.id]),
    ...(counts[d.id] || {}),
  }));
  res.json({ ok: true, data: users, nextCursor });
});

function userSummary(d, contact = {}) {
  const u = d.data();
  return {
    uid: d.id,
    name: u.name || u.username || 'Savarun User',
    username: u.username || null,
    email: contact?.email || null,
    phone: contact?.phone || null,
    photoURL: u.photoURL || u.photoUrl || null,
    style: u.style || null,
    status: u.status || 'active',
    followers: u.followers || 0,
    lastActiveAt: toIso(u.lastActiveAt),
    createdAt: toIso(u.createdAt),
  };
}

/**
 * GET /api/admin/users/:uid — full profile for the dashboard detail view.
 */
export const getUserDetail = asyncHandler(async (req, res) => {
  const { uid } = req.params;
  const userRef = db.collection('users').doc(uid);

  const [snap, authUser] = await Promise.all([
    userRef.get(),
    firebaseAuth.getUser(uid).catch(() => null),
  ]);
  if (!snap.exists && !authUser) throw ApiError.notFound('User not found');

  const u = snap.exists ? snap.data() : {};
  const [contacts, posts, outfitHistory, wardrobe, followers, following, recentPosts, recentAnalyses] =
    await Promise.all([
      getContacts([uid], { [uid]: u }),
      countOf(db.collection('posts').where('authorUid', '==', uid)),
      countOf(userRef.collection('outfitHistory')),
      countOf(userRef.collection('wardrobe')),
      countOf(db.collection('follows').where('followingUid', '==', uid)),
      countOf(db.collection('follows').where('followerUid', '==', uid)),
      // Equality-only query (no composite index); newest 5 picked in memory.
      db
        .collection('posts')
        .where('authorUid', '==', uid)
        .limit(300)
        .get()
        .then((s) =>
          s.docs
            .sort(byCreatedDesc)
            .slice(0, 5)
            .map((d) => ({ id: d.id, imageUrl: d.get('imageUrl') || null, createdAt: toIso(d.get('createdAt')) }))
        )
        .catch(() => []),
      userRef
        .collection('outfitHistory')
        .orderBy('createdAt', 'desc')
        .limit(5)
        .get()
        .then((s) =>
          s.docs.map((d) => ({
            id: d.id,
            fitScore: d.get('fitScore') ?? null,
            imageUrl: d.get('imageUrl') || null,
            createdAt: toIso(d.get('createdAt')),
          }))
        )
        .catch(() => []),
    ]);

  const { followers: _f, following: _g, ...profile } = u;
  for (const k of Object.keys(profile)) {
    // Timestamps → ISO so the payload is plain JSON.
    if (profile[k] && typeof profile[k].toDate === 'function') profile[k] = toIso(profile[k]);
  }

  res.json({
    ok: true,
    data: {
      ...profile,
      uid,
      name: u.name || u.username || authUser?.displayName || 'Savarun User',
      username: u.username || null,
      photoURL: u.photoURL || u.photoUrl || authUser?.photoURL || null,
      email: contacts[uid]?.email || authUser?.email || null,
      phone: contacts[uid]?.phone || authUser?.phoneNumber || null,
      status: u.status || 'active',
      disabled: authUser?.disabled ?? null,
      claims: { admin: authUser?.customClaims?.admin === true },
      counts: { posts, outfitHistory, wardrobe, followers, following },
      lastActiveAt: toIso(u.lastActiveAt),
      lastSignInAt: authUser?.metadata?.lastSignInTime
        ? new Date(authUser.metadata.lastSignInTime).toISOString()
        : null,
      createdAt: toIso(u.createdAt) ||
        (authUser?.metadata?.creationTime ? new Date(authUser.metadata.creationTime).toISOString() : null),
      recentPosts,
      recentAnalyses,
    },
  });
});

/** GET /api/admin/brands?status=pending — brand applications with applicant info. */
export const listBrands = asyncHandler(async (req, res) => {
  const status = (req.query.status || '').toString().trim();
  let query = db.collection('brands');
  if (status) query = query.where('status', '==', status);
  const snap = await query.limit(200).get();
  const brands = snap.docs.map((d) => ({ id: d.id, ...d.data() }));

  // Attach the applicant's name/email so the admin knows who requested each
  // brand. Look up each unique owner once.
  const ownerIds = [...new Set(brands.map((b) => b.ownerUid).filter(Boolean))];
  const owners = {};
  if (ownerIds.length) {
    const userSnaps = await db.getAll(...ownerIds.map((uid) => db.collection('users').doc(uid)));
    const userDocs = {};
    for (const s of userSnaps) if (s.exists) userDocs[s.id] = s.data();
    const contacts = await getContacts(ownerIds, userDocs);
    for (const uid of ownerIds) {
      const data = userDocs[uid];
      if (!data && !contacts[uid]?.email && !contacts[uid]?.phone) continue;
      owners[uid] = {
        name: data?.name || data?.username || 'Savarun User',
        email: contacts[uid]?.email || null,
        phone: contacts[uid]?.phone || null,
      };
    }
  }

  const withOwners = brands.map((b) => ({
    ...b,
    ownerName: owners[b.ownerUid]?.name || 'Unknown user',
    ownerEmail: owners[b.ownerUid]?.email || null,
    // Phone as a fallback identifier for users who logged in by phone.
    ownerContact:
      owners[b.ownerUid]?.email || owners[b.ownerUid]?.phone || null,
  }));

  res.json({ ok: true, data: withOwners });
});

/**
 * GET /api/admin/products?brandId=&category= — every product, including
 * hidden/unapproved. category matches case-insensitively.
 */
export const listAllProducts = asyncHandler(async (req, res) => {
  const brandId = (req.query.brandId || '').toString().trim();
  const category = (req.query.category || '').toString().trim().toLowerCase();
  let query = db.collection('products');
  if (brandId) query = query.where('brandId', '==', brandId);
  const snap = await query.limit(brandId ? 500 : 200).get();
  let products = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
  if (category) {
    products = products.filter(
      (p) => (p.categoryLower || String(p.category || '').toLowerCase()) === category
    );
  }
  res.json({ ok: true, data: products });
});

/** PATCH /api/admin/products/:id/approval  body: { approved: boolean } */
export const setProductApproval = asyncHandler(async (req, res) => {
  const approved = z.boolean().safeParse(req.body?.approved);
  if (!approved.success) throw ApiError.badRequest('approved (boolean) is required');
  const ref = db.collection('products').doc(req.params.id);
  const snap = await ref.get();
  if (!snap.exists) throw ApiError.notFound('Product not found');
  await ref.update({ approved: approved.data });
  logAdminAction(req, 'product.approval', { type: 'product', id: ref.id }, {
    approved: approved.data,
    name: snap.get('name') || null,
  });
  res.json({ ok: true, data: { id: ref.id, approved: approved.data } });
});

/* ─────────────── Brand & Product Management ─────────────── */

/**
 * POST /api/admin/brands/:id/decision
 *   body: { decision: 'approve'|'approved'|'reject'|'rejected'|'revoke'|'revoked', note? }
 * 'revoked' hides every product of the brand (hidden=true, marked
 * hiddenByRevoke) and blocks new listings; re-approving un-hides exactly the
 * products the revoke hid.
 */
const DecisionBody = z.object({
  decision: z.enum(['approve', 'approved', 'reject', 'rejected', 'revoke', 'revoked']),
  note: z.string().optional(),
});
const DECISION_STATUS = {
  approve: 'approved',
  approved: 'approved',
  reject: 'rejected',
  rejected: 'rejected',
  revoke: 'revoked',
  revoked: 'revoked',
};

export const decideBrand = asyncHandler(async (req, res) => {
  const parsed = DecisionBody.safeParse(req.body);
  if (!parsed.success) {
    throw ApiError.badRequest('decision must be "approve", "reject" or "revoked"');
  }

  const ref = db.collection('brands').doc(req.params.id);
  const snap = await ref.get();
  if (!snap.exists) throw ApiError.notFound('Brand not found');

  const status = DECISION_STATUS[parsed.data.decision];
  await ref.update({
    status,
    reviewNote: parsed.data.note || null,
    reviewedBy: req.user.uid,
    reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  let productsUpdated = 0;
  if (status === 'revoked' || status === 'approved') {
    const products = await db.collection('products').where('brandId', '==', ref.id).get();
    const del = admin.firestore.FieldValue.delete();
    const targets = products.docs.filter((d) =>
      status === 'revoked' ? d.get('hidden') !== true : d.get('hiddenByRevoke') === true
    );
    for (let i = 0; i < targets.length; i += 400) {
      const batch = db.batch();
      for (const d of targets.slice(i, i + 400)) {
        batch.update(
          d.ref,
          status === 'revoked' ? { hidden: true, hiddenByRevoke: true } : { hidden: false, hiddenByRevoke: del }
        );
      }
      await batch.commit();
    }
    productsUpdated = targets.length;
  }

  logAdminAction(req, 'brand.decision', { type: 'brand', id: ref.id }, {
    status,
    note: parsed.data.note || null,
    name: snap.get('name') || null,
    productsUpdated,
  });

  res.json({ ok: true, data: { id: ref.id, status, productsUpdated } });
});

/** PATCH /api/admin/products/:id/visibility  body: { hidden: boolean } */
export const setProductVisibility = asyncHandler(async (req, res) => {
  const hidden = z.boolean().safeParse(req.body?.hidden);
  if (!hidden.success) throw ApiError.badRequest('hidden (boolean) is required');

  const ref = db.collection('products').doc(req.params.id);
  const snap = await ref.get();
  if (!snap.exists) throw ApiError.notFound('Product not found');

  await ref.update({ hidden: hidden.data });
  logAdminAction(req, 'product.visibility', { type: 'product', id: ref.id }, {
    hidden: hidden.data,
    name: snap.get('name') || null,
  });
  res.json({ ok: true, data: { id: ref.id, hidden: hidden.data } });
});

/** PUT /api/admin/featured-brand  body: { brandId: string } */
export const setFeaturedBrand = asyncHandler(async (req, res) => {
  const brandId = z.string().min(1).safeParse(req.body?.brandId);
  if (!brandId.success) throw ApiError.badRequest('brandId is required');

  await db.collection('config').doc('home').set({ featuredBrandId: brandId.data }, { merge: true });
  logAdminAction(req, 'brand.featured', { type: 'brand', id: brandId.data });
  res.json({ ok: true, data: { featuredBrandId: brandId.data } });
});

/* ─────────────── AI Trend Tuning ─────────────── */

/** GET /api/admin/fit-weights */
export const getFitWeights = asyncHandler(async (_req, res) => {
  res.json({ ok: true, data: await getWeights() });
});

/** PUT /api/admin/fit-weights  body: { trendMatch?, colorHarmony?, ... } */
export const updateFitWeights = asyncHandler(async (req, res) => {
  try {
    const updated = await setWeights(req.body || {});
    logAdminAction(req, 'fitWeights.update', { type: 'config', id: 'fitScoreWeights' }, { weights: updated });
    res.json({ ok: true, data: updated });
  } catch (err) {
    throw ApiError.badRequest(err.message);
  }
});

/* ─────────────── User Management ─────────────── */

/** POST /api/admin/users/:uid/moderate  body: { action: 'ban'|'suspend'|'verify'|'reinstate' } */
const ModerateBody = z.object({
  action: z.enum(['ban', 'suspend', 'verify', 'reinstate']),
});

export const moderateUser = asyncHandler(async (req, res) => {
  const parsed = ModerateBody.safeParse(req.body);
  if (!parsed.success) throw ApiError.badRequest('action must be ban|suspend|verify|reinstate');

  const { uid } = req.params;
  const status = await applyModeration(uid, parsed.data.action, req.user.uid);
  logAdminAction(req, 'user.moderate', { type: 'user', id: uid }, { action: parsed.data.action, status });
  res.json({ ok: true, data: { uid, status } });
});

/**
 * Apply a moderation action to a user (shared by the moderate endpoint and
 * report resolution). Returns the new profile status.
 */
export async function applyModeration(uid, action, byUid) {
  // Reflect status in Firestore profile.
  const statusMap = { ban: 'banned', suspend: 'suspended', verify: 'verified', reinstate: 'active' };
  await db.collection('users').doc(uid).set(
    { status: statusMap[action], moderatedBy: byUid, moderatedAt: admin.firestore.FieldValue.serverTimestamp() },
    { merge: true }
  );

  // Banned/suspended users are disabled at the Auth level so tokens stop working.
  if (action === 'ban' || action === 'suspend') {
    await firebaseAuth.updateUser(uid, { disabled: true });
    await firebaseAuth.revokeRefreshTokens(uid);
  } else if (action === 'reinstate') {
    await firebaseAuth.updateUser(uid, { disabled: false });
  }
  return statusMap[action];
}

/** POST /api/admin/users/:uid/set-admin  body: { admin: boolean } — grant/revoke dashboard access. */
export const setUserAdmin = asyncHandler(async (req, res) => {
  const isAdmin = z.boolean().safeParse(req.body?.admin);
  if (!isAdmin.success) throw ApiError.badRequest('admin (boolean) is required');

  await firebaseAuth.setCustomUserClaims(req.params.uid, { admin: isAdmin.data });
  logAdminAction(req, 'user.setAdmin', { type: 'user', id: req.params.uid }, { admin: isAdmin.data });
  res.json({ ok: true, data: { uid: req.params.uid, admin: isAdmin.data } });
});
