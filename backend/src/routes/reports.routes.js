import { Router } from 'express';
import { requireAuth } from '../middleware/auth.js';
import { reportLimiter } from '../middleware/rateLimit.js';
import { createReport } from '../controllers/reports.controller.js';

const router = Router();

// Users report a profile, post or chat message for admin review.
router.post('/', requireAuth, reportLimiter, createReport);

export default router;
