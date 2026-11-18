import { z } from 'zod';
import { db, admin } from '../config/firebase.js';
import { ApiError } from '../utils/ApiError.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { logAdminAction } from '../services/audit.service.js';
import { bumpDailyStats } from '../services/stats.service.js';

/**
 * Trending Fashion (CR-1): an admin-CURATED feed shown on Home and its own
 * page. Unlike "Trending Brands" (auto, by click count), every card here is
 * placed by the admin, who attaches the affiliate link it opens.
 *
 * Firestore: trendingFashion/{id}
 *   { title, subtitle, imageUrl, affiliateUrl, order, hidden, clicks,
 *     createdAt, updatedAt }
 *
 * Public endpoints sit under /api/affiliate (requireAuth); admin CRUD sits
 * under /api/admin (requireAuth + adminOnly).
 */

const COLLECTION = 'trendingFashion';

/** order asc, then newest first — in memory, so no composite index is needed. */
function sortCurated(a, b) {
  const byOrder = (a.order ?? 0) - (b.order ?? 0);
  if (byOrder !== 0) return byOrder;
  return (b.createdAt?.seconds || 0) - (a.createdAt?.seconds || 0);
}

/* ─────────────── public ─────────────── */

/**
 * GET /api/affiliate/trending-fashion
 * Visible curated cards for the app. The affiliate URL is intentionally NOT
 * returned here — the app calls /click to record the tap and get the URL.
 */
export const listTrendingFashion = asyncHandler(async (_req, res) => {
  const snap = await db.collection(COLLECTION).where('hidden', '==', false).get();
  const items = snap.docs
    .map((d) => ({ id: d.id, ...d.data() }))
    .sort(sortCurated)
    .map((it) => ({
      id: it.id,
      title: it.title || '',
      subtitle: it.subtitle || '',
      imageUrl: it.imageUrl || '',
    }));
  res.json({ ok: true, data: items });
});

const ClickBody = z.object({ id: z.string().min(1) });

/**
 * POST /api/affiliate/trending-fashion/click  body: { id }
 * Records the click (for admin analytics) and returns the affiliate URL to open.
 */
export const trackTrendingFashionClick = asyncHandler(async (req, res) => {
  const parsed = ClickBody.safeParse(req.body);
  if (!parsed.success) throw ApiError.badRequest('id is required');

  const ref = db.collection(COLLECTION).doc(parsed.data.id);
  const snap = await ref.get();
  if (!snap.exists) throw ApiError.notFound('Item not found');
  const item = snap.data();
  if (item.hidden) throw ApiError.forbidden('Item is not available');

  await ref.update({ clicks: admin.firestore.FieldValue.increment(1) });
  db.collection('affiliateClicks')
    .add({
      trendingFashionId: ref.id,
      userId: req.user.uid,
      at: admin.firestore.FieldValue.serverTimestamp(),
    })
    .catch((err) => console.warn('[trendingFashion] click log failed:', err.message));
  bumpDailyStats({ clicks: 1 });

  res.json({ ok: true, data: { url: item.affiliateUrl || '' } });
});

/* ─────────────── admin CRUD ─────────────── */

/** GET /api/admin/trending-fashion — every card, hidden ones included. */
export const adminListTrendingFashion = asyncHandler(async (_req, res) => {
  const snap = await db.collection(COLLECTION).get();
  const items = snap.docs
    .map((d) => ({ id: d.id, ...d.data() }))
    .sort(sortCurated)
    .map((it) => ({
      id: it.id,
      title: it.title || '',
      subtitle: it.subtitle || '',
      imageUrl: it.imageUrl || '',
      affiliateUrl: it.affiliateUrl || '',
      order: it.order ?? 0,
      hidden: it.hidden === true,
      clicks: it.clicks || 0,
    }));
  res.json({ ok: true, data: items });
});

const CreateBody = z.object({
  title: z.string().trim().min(1).max(120),
  subtitle: z.string().trim().max(160).optional().or(z.literal('')),
  imageUrl: z.string().url().optional().or(z.literal('')),
  affiliateUrl: z.string().url(),
  order: z.coerce.number().int().optional(),
  hidden: z.boolean().optional(),
});

/** POST /api/admin/trending-fashion — add a curated card. */
export const createTrendingFashion = asyncHandler(async (req, res) => {
  const parsed = CreateBody.safeParse(req.body);
  if (!parsed.success) {
    throw ApiError.badRequest('A title and a valid affiliate link (https://…) are required');
  }
  const p = parsed.data;

  const ref = await db.collection(COLLECTION).add({
    title: p.title,
    subtitle: p.subtitle || '',
    imageUrl: p.imageUrl || '',
    affiliateUrl: p.affiliateUrl,
    order: p.order ?? 0,
    hidden: p.hidden === true,
    clicks: 0,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  logAdminAction(req, 'trendingFashion.create', { type: 'trendingFashion', id: ref.id }, { title: p.title });
  res.status(201).json({ ok: true, data: { id: ref.id } });
});

const UpdateBody = z
  .object({
    title: z.string().trim().min(1).max(120).optional(),
    subtitle: z.string().trim().max(160).optional(),
    imageUrl: z.string().url().optional().or(z.literal('')),
    affiliateUrl: z.string().url().optional(),
    order: z.coerce.number().int().optional(),
    hidden: z.boolean().optional(),
  })
  .refine((d) => Object.keys(d).length > 0, { message: 'No fields to update' });

/** PATCH /api/admin/trending-fashion/:id — edit, reorder, or show/hide. */
export const updateTrendingFashion = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const parsed = UpdateBody.safeParse(req.body);
  if (!parsed.success) throw ApiError.badRequest('Invalid update');

  const ref = db.collection(COLLECTION).doc(id);
  const snap = await ref.get();
  if (!snap.exists) throw ApiError.notFound('Item not found');

  await ref.update({ ...parsed.data, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
  logAdminAction(req, 'trendingFashion.update', { type: 'trendingFashion', id }, parsed.data);
  res.json({ ok: true });
});

/** DELETE /api/admin/trending-fashion/:id — remove a card. */
export const deleteTrendingFashion = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const ref = db.collection(COLLECTION).doc(id);
  const snap = await ref.get();
  if (!snap.exists) throw ApiError.notFound('Item not found');

  await ref.delete();
  logAdminAction(req, 'trendingFashion.delete', { type: 'trendingFashion', id }, { title: snap.get('title') || null });
  res.json({ ok: true });
});
