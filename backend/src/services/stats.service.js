import { db, admin } from '../config/firebase.js';

/**
 * Cheap write-time counters for the admin dashboard.
 *
 *   activity/{YYYY-MM-DD}/users/{uid}  = { at }          one doc per active user per day
 *   statsDaily/{YYYY-MM-DD}            = { analyses, clicks, posts, styles: { <Style>: n } }
 *
 * Days are calendar days in Asia/Kolkata (IST, UTC+5:30, no DST).
 * Every writer here is fire-and-forget: it never throws into a request.
 */

const IST_OFFSET_MS = 330 * 60 * 1000;
const DAY_MS = 24 * 60 * 60 * 1000;

/** 'YYYY-MM-DD' of [date] in IST. */
export function istDay(date = new Date()) {
  return new Date(date.getTime() + IST_OFFSET_MS).toISOString().slice(0, 10);
}

/** The instant an IST day ('YYYY-MM-DD') starts. */
export function istDayStart(day) {
  return new Date(Date.parse(`${day}T00:00:00.000Z`) - IST_OFFSET_MS);
}

/** The last [n] IST days, oldest → newest, ending today. */
export function lastIstDays(n, now = new Date()) {
  const today = istDayStart(istDay(now)).getTime();
  const days = [];
  for (let i = n - 1; i >= 0; i--) days.push(istDay(new Date(today - i * DAY_MS)));
  return days;
}

/** Turn a style name into a safe, readable map key ('' if nothing usable). */
export function styleKey(name) {
  return String(name || '')
    .replace(/[^A-Za-z0-9 &\-]/g, '')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, 40);
}

/** Mark [uid] active today (idempotent). */
export function recordActiveDay(uid) {
  db.collection('activity')
    .doc(istDay())
    .collection('users')
    .doc(uid)
    .set({ at: admin.firestore.FieldValue.serverTimestamp() })
    .catch((err) => console.warn('[stats] activity write failed:', err.code || '', err.message));
}

/**
 * Increment today's statsDaily counters.
 * @param {{analyses?: number, clicks?: number, posts?: number, style?: string}} inc
 */
export function bumpDailyStats({ analyses, clicks, posts, style } = {}) {
  const inc = admin.firestore.FieldValue.increment;
  const data = {};
  if (analyses) data.analyses = inc(analyses);
  if (clicks) data.clicks = inc(clicks);
  if (posts) data.posts = inc(posts);
  const key = styleKey(style);
  if (key) data.styles = { [key]: inc(1) };
  if (!Object.keys(data).length) return;
  try {
    db.collection('statsDaily')
      .doc(istDay())
      .set(data, { merge: true })
      .catch((err) => console.warn('[stats] statsDaily write failed:', err.code || '', err.message));
  } catch (err) {
    console.warn('[stats] statsDaily write failed:', err.message);
  }
}

/** Firestore Timestamp | Date | ISO string | {seconds} → Date (or null). */
export function toDate(v) {
  if (!v) return null;
  if (typeof v.toDate === 'function') return v.toDate();
  if (v instanceof Date) return v;
  if (typeof v === 'string' || typeof v === 'number') {
    const d = new Date(v);
    return Number.isNaN(d.getTime()) ? null : d;
  }
  if (typeof v.seconds === 'number') return new Date(v.seconds * 1000);
  if (typeof v._seconds === 'number') return new Date(v._seconds * 1000);
  return null;
}

/** → ISO string or null. */
export function toIso(v) {
  return toDate(v)?.toISOString() || null;
}
