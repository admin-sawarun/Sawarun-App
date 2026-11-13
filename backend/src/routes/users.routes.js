import { Router } from 'express';
import { requireAuth } from '../middleware/auth.js';
import { deleteMe } from '../controllers/users.controller.js';

const router = Router();

// Permanent account deletion (Google Play / App Store requirement).
router.delete('/me', requireAuth, deleteMe);

export default router;
