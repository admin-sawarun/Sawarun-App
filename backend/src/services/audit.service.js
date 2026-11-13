import { db, admin } from '../config/firebase.js';

/** Keep audit `details` small: shallow copy, strings capped, at most 20 keys. */
function compact(details) {
  if (!details || typeof details !== 'object') return {};
  const out = {};
  for (const [k, v] of Object.entries(details).slice(0, 20)) {
    if (v === undefined) continue;
    if (typeof v === 'string') out[k] = v.slice(0, 300);
    else if (v === null || typeof v === 'number' || typeof v === 'boolean') out[k] = v;
    else {
      try {
        const s = JSON.stringify(v);
        out[k] = s.length <= 1000 ? JSON.parse(s) : s.slice(0, 1000);
      } catch {
        out[k] = String(v).slice(0, 300);
      }
    }
  }
  return out;
}

/**
 * Record an admin mutation in adminAudit/{autoId}:
 *   { adminUid, adminEmail, action, targetType, targetId, details, at }
 * [target] is { type, id }. Fire-and-forget: never throws into the request.
 */
export function logAdminAction(req, action, target = {}, details = {}) {
  try {
    db.collection('adminAudit')
      .add({
        adminUid: req.user?.uid || null,
        adminEmail: req.user?.email || null,
        action,
        targetType: target.type || null,
        targetId: target.id != null ? String(target.id) : null,
        details: compact(details),
        at: admin.firestore.FieldValue.serverTimestamp(),
      })
      .catch((err) => console.warn('[audit] write failed:', err.code || '', err.message));
  } catch (err) {
    console.warn('[audit] write failed:', err.message);
  }
}
