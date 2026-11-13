import { z } from 'zod';
import { db, admin, firebaseAuth } from '../config/firebase.js';
import { ApiError } from '../utils/ApiError.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { getWeights, setWeights } from '../services/fitScore.service.js';

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
    computeTrendingStyles(),
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

  res.json({
    ok: true,
    data: { totalUsers: usersCount, dailyActiveUsers: dau, trendingStyles, topProducts },
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

/** GET /api/admin/users?limit=50 — all users with activity + moderation status. */
export const listUsers = asyncHandler(async (req, res) => {
  const limit = Math.min(Number(req.query.limit) || 50, 200);
  const snap = await db.collection('users').limit(limit).get();
  const contacts = await getContacts(
    snap.docs.map((d) => d.id),
    Object.fromEntries(snap.docs.map((d) => [d.id, d.data()]))
  );
  const users = snap.docs.map((d) => {
    const u = d.data();
    return {
      uid: d.id,
      name: u.name || u.username || 'Savarun User',
      email: contacts[d.id]?.email || null,
      phone: contacts[d.id]?.phone || null,
      photoURL: u.photoURL || null,
      style: u.style || null,
      status: u.status || 'active',
      followers: u.followers || 0,
    };
  });
  res.json({ ok: true, data: users });
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

/** GET /api/admin/products — every product, including hidden/unapproved. */
export const listAllProducts = asyncHandler(async (_req, res) => {
  const snap = await db.collection('products').limit(200).get();
  const products = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
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
  res.json({ ok: true, data: { id: ref.id, approved: approved.data } });
});

/* ─────────────── Brand & Product Management ─────────────── */

/** POST /api/admin/brands/:id/decision  body: { decision: 'approve'|'reject', note? } */
const DecisionBody = z.object({
  decision: z.enum(['approve', 'reject']),
  note: z.string().optional(),
});

export const decideBrand = asyncHandler(async (req, res) => {
  const parsed = DecisionBody.safeParse(req.body);
  if (!parsed.success) throw ApiError.badRequest('decision must be "approve" or "reject"');

  const ref = db.collection('brands').doc(req.params.id);
  const snap = await ref.get();
  if (!snap.exists) throw ApiError.notFound('Brand not found');

  const status = parsed.data.decision === 'approve' ? 'approved' : 'rejected';
  await ref.update({
    status,
    reviewNote: parsed.data.note || null,
    reviewedBy: req.user.uid,
    reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  res.json({ ok: true, data: { id: ref.id, status } });
});

/** PATCH /api/admin/products/:id/visibility  body: { hidden: boolean } */
export const setProductVisibility = asyncHandler(async (req, res) => {
  const hidden = z.boolean().safeParse(req.body?.hidden);
  if (!hidden.success) throw ApiError.badRequest('hidden (boolean) is required');

  const ref = db.collection('products').doc(req.params.id);
  const snap = await ref.get();
  if (!snap.exists) throw ApiError.notFound('Product not found');

  await ref.update({ hidden: hidden.data });
  res.json({ ok: true, data: { id: ref.id, hidden: hidden.data } });
});

/** PUT /api/admin/featured-brand  body: { brandId: string } */
export const setFeaturedBrand = asyncHandler(async (req, res) => {
  const brandId = z.string().min(1).safeParse(req.body?.brandId);
  if (!brandId.success) throw ApiError.badRequest('brandId is required');

  await db.collection('config').doc('home').set({ featuredBrandId: brandId.data }, { merge: true });
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
  res.json({ ok: true, data: { uid: req.params.uid, admin: isAdmin.data } });
});
