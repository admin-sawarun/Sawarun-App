import rateLimit from 'express-rate-limit';

/** General API limiter. */
export const apiLimiter = rateLimit({ 
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 300,
  standardHeaders: true,
  legacyHeaders: false,
  message: { ok: false, error: 'Too many requests, please slow down.' },
});

/**
 * Stricter limiter for the AI analysis endpoint — each call costs real
 * OpenAI money, so we cap per-window usage harder.
 */
export const aiLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  message: { ok: false, error: 'Too many analysis requests, please wait a moment.' },
});

/**
 * Limiter for user reports (abuse/spam protection). Runs after requireAuth,
 * so it is keyed per signed-in user rather than per IP.
 */
export const reportLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 30,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) => req.user?.uid || req.ip,
  message: { ok: false, error: 'Too many reports, please try again later.' },
});
