import { firebaseAuth, db, admin } from "../config/firebase.js";
import { ApiError } from "../utils/ApiError.js";
import { asyncHandler } from "../utils/asyncHandler.js";
import { isProd } from "../config/env.js";

/**
 * Activity tracking for the admin "Daily Active Users" metric.
 * users/{uid}.lastActiveAt is written at most once per hour per uid (per
 * process). Fire-and-forget: it never blocks or fails the request.
 */
const ACTIVITY_INTERVAL_MS = 60 * 60 * 1000;
const lastActivityWrite = new Map();

function recordActivity(uid) {
  const now = Date.now();
  const last = lastActivityWrite.get(uid);
  if (last && now - last < ACTIVITY_INTERVAL_MS) return;
  lastActivityWrite.set(uid, now);

  // Keep the map from growing without bound on a long-lived process.
  if (lastActivityWrite.size > 50_000) {
    for (const [key, at] of lastActivityWrite) {
      if (now - at >= ACTIVITY_INTERVAL_MS) lastActivityWrite.delete(key);
    }
  }

  db.collection("users")
    .doc(uid)
    .set(
      { lastActiveAt: admin.firestore.FieldValue.serverTimestamp() },
      { merge: true }
    )
    .catch((err) => {
      lastActivityWrite.delete(uid);
      console.warn("[auth] lastActiveAt update failed:", err.code || "", err.message);
    });
}

/** Forget a uid's activity throttle (used after account deletion). */
export function forgetActivity(uid) {
  lastActivityWrite.delete(uid);
}

export const requireAuth = asyncHandler(async (req, _res, next) => {
  const header = req.headers.authorization || "";
  const [scheme, token] = header.split(" ");

  if (scheme !== "Bearer" || !token) {
    throw ApiError.unauthorized("Missing or malformed Authorization header");
  }

  let decoded;

  try {
    // checkRevoked=true: tokens of banned/suspended users (refresh tokens
    // revoked) and disabled accounts are rejected immediately.
    decoded = await firebaseAuth.verifyIdToken(token, true);
  } catch (err) {
    // Log the real reason server-side; surface it in dev to speed debugging.
    console.error("[auth] verifyIdToken failed:", err.code, "-", err.message);
    if (err.code === "auth/user-disabled") {
      throw ApiError.forbidden("This account has been disabled");
    }
    if (err.code === "auth/id-token-revoked") {
      throw ApiError.unauthorized("Session has been revoked. Please sign in again.");
    }
    throw ApiError.unauthorized(
      isProd ? "Invalid or expired token" : `Token verification failed: ${err.message}`
    );
  }

  req.user = {
    uid: decoded.uid,
    email: decoded.email || null,
    name: decoded.name || null,
    photoURL: decoded.picture || null,
    phoneNumber: decoded.phone_number || null,
    provider: decoded.firebase?.sign_in_provider || null,
    isAdmin: decoded.admin === true,
  };

  // Skip the activity write for account deletion so it can't recreate the doc.
  if (!(req.method === "DELETE" && req.originalUrl.split("?")[0] === "/api/users/me")) {
    recordActivity(decoded.uid);
  }

  next();
});
