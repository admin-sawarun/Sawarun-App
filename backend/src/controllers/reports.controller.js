import { z } from 'zod';
import { db, admin } from '../config/firebase.js';
import { ApiError } from '../utils/ApiError.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { deleteByUrl } from '../services/storage.service.js';
import { applyModeration } from './admin.controller.js';
import { removePost } from '../services/moderation.service.js';
import { logAdminAction } from '../services/audit.service.js';

// removePost lives in services/moderation.service.js (shared with the admin
// posts endpoint); re-exported here for backward compatibility.
export { removePost };

const REASONS = ['spam', 'harassment', 'nudity', 'hate', 'violence', 'fake', 'other'];

const ReportBody = z.object({
  // 'analysis' = an AI outfit report the user flags (Play AI-generated content policy).
  targetType: z.enum(['user', 'post', 'message', 'analysis']),
  // For messages, targetId may be "<chatId>/<messageId>" or just the message id
  // (we then locate the chat via the reported user's threads).
  targetId: z.string().trim().min(1).max(300),
  targetUid: z.string().trim().min(1).max(128),
  reason: z.enum(REASONS),
  details: z.string().trim().max(500).optional(),
});

/**
 * POST /api/reports
 * body: { targetType, targetId, targetUid, reason, details? } → { ok, id }
 */
export const createReport = asyncHandler(async (req, res) => {
  const parsed = ReportBody.safeParse(req.body);
  if (!parsed.success) {
    throw ApiError.badRequest('Invalid report', parsed.error.flatten().fieldErrors);
  }
  const r = parsed.data;
  const me = req.user.uid;

  if (r.targetUid === me || (r.targetType === 'user' && r.targetId === me)) {
    throw ApiError.badRequest('You cannot report yourself');
  }

  const ref = await db.collection('reports').add({
    reporterUid: me,
    targetType: r.targetType,
    targetId: r.targetId,
    targetUid: r.targetUid,
    reason: r.reason,
    details: r.details || '',
    status: 'open',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  res.status(201).json({ ok: true, id: ref.id });
});

/* ─────────────── Admin ─────────────── */

function displayName(u) {
  if (!u) return null;
  return u.name || u.username || u.displayName || u.email || u.phone || 'Savarun User';
}

/** GET /api/admin/reports?status=open|resolved — newest first, max 200. */
export const listReports = asyncHandler(async (req, res) => {
  const status = req.query.status === 'resolved' ? 'resolved' : 'open';

  // Filter only (no orderBy) so no composite index is needed; sort in memory.
  const snap = await db.collection('reports').where('status', '==', status).limit(1000).get();
  const reports = snap.docs
    .map((d) => {
      const data = d.data();
      return {
        id: d.id,
        ...data,
        createdAt: data.createdAt?.toDate?.().toISOString() ?? null,
        resolvedAt: data.resolvedAt?.toDate?.().toISOString() ?? null,
      };
    })
    .sort((a, b) => (b.createdAt || '').localeCompare(a.createdAt || ''))
    .slice(0, 200);

  // Attach reporter/target display names with a single batched read.
  const uids = [...new Set(reports.flatMap((r) => [r.reporterUid, r.targetUid]).filter(Boolean))];
  const names = {};
  if (uids.length) {
    try {
      const docs = await db.getAll(...uids.map((u) => db.collection('users').doc(u)));
      for (const d of docs) if (d.exists) names[d.id] = displayName(d.data());
    } catch (err) {
      console.warn('[reports] name lookup failed:', err.message);
    }
  }

  res.json({
    ok: true,
    data: reports.map((r) => ({
      ...r,
      reporterName: r.reporterUid ? names[r.reporterUid] || 'Unknown user' : 'Deleted user',
      targetName: names[r.targetUid] || 'Unknown user',
    })),
  });
});

const ResolveBody = z.object({
  action: z.enum(['dismiss', 'remove_content', 'ban_user']),
});

/** POST /api/admin/reports/:id/resolve  body: { action } */
export const resolveReport = asyncHandler(async (req, res) => {
  const parsed = ResolveBody.safeParse(req.body);
  if (!parsed.success) throw ApiError.badRequest('action must be dismiss|remove_content|ban_user');
  const { action } = parsed.data;

  const ref = db.collection('reports').doc(req.params.id);
  const snap = await ref.get();
  if (!snap.exists) throw ApiError.notFound('Report not found');
  const report = snap.data();

  let contentRemoved = false;
  if (action === 'remove_content') {
    if (report.targetType === 'post') {
      contentRemoved = await removePost(report.targetId);
    } else if (report.targetType === 'message') {
      contentRemoved = await removeMessage(report.targetId, report.targetUid);
    } else {
      throw ApiError.badRequest('This report has no content to remove; use dismiss' + (report.targetType === 'user' ? ' or ban_user' : ''));
    }
  } else if (action === 'ban_user') {
    if (report.targetType === 'analysis') throw ApiError.badRequest('An AI result report has no user to ban; review it and dismiss');
    if (!report.targetUid) throw ApiError.badRequest('Report has no target user');
    try {
      await applyModeration(report.targetUid, 'ban', req.user.uid);
    } catch (err) {
      if (err.code !== 'auth/user-not-found') throw err;
    }
  }

  await ref.update({
    status: 'resolved',
    action,
    resolvedBy: req.user.uid,
    resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  logAdminAction(req, 'report.resolve', { type: 'report', id: ref.id }, {
    action,
    reportTargetType: report.targetType || null,
    reportTargetId: report.targetId || null,
    targetUid: report.targetUid || null,
    contentRemoved,
  });

  res.json({ ok: true, data: { id: ref.id, status: 'resolved', action, contentRemoved } });
});

/** Delete a chat message (and its image). targetId is "<chatId>/<msgId>" or a bare message id. */
async function removeMessage(targetId, targetUid) {
  let candidates = [];
  let msgId = targetId;
  if (targetId.includes('/')) {
    const parts = targetId.split('/').filter(Boolean);
    // Accept "chats/<chatId>/messages/<msgId>" or "<chatId>/<msgId>".
    msgId = parts[parts.length - 1];
    candidates = [parts.length >= 4 ? parts[1] : parts[0]];
  } else if (targetUid) {
    const chats = await db.collection('chats').where('participants', 'array-contains', targetUid).get();
    candidates = chats.docs.map((d) => d.id);
  }

  for (const chatId of candidates) {
    const msgRef = db.collection('chats').doc(chatId).collection('messages').doc(msgId);
    const msg = await msgRef.get();
    if (!msg.exists) continue;
    await msgRef.delete();
    await deleteByUrl(msg.data().imageUrl);
    return true;
  }
  return false;
}
