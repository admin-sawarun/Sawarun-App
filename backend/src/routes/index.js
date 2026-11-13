import { Router } from 'express';
import analysisRoutes from './analysis.routes.js';
import wardrobeRoutes from './wardrobe.routes.js';
import affiliateRoutes from './affiliate.routes.js';
import adminRoutes from './admin.routes.js';
import authRoutes from "./auth.routes.js";
import uploadRoutes from "./upload.routes.js";
import postsRoutes from "./posts.routes.js";
import usersRoutes from "./users.routes.js";
import reportsRoutes from "./reports.routes.js";

const router = Router();

router.get('/', (_req, res) => {
  res.json({
    ok: true,
    service: 'savarun-backend',
    modules: ['analysis', 'wardrobe', 'affiliate', 'admin', 'auth', 'uploads', 'posts', 'users', 'reports'],
  });
});

router.use('/analysis', analysisRoutes);
router.use('/wardrobe', wardrobeRoutes);
router.use('/affiliate', affiliateRoutes);
router.use('/admin', adminRoutes);
router.use("/auth", authRoutes);
router.use("/uploads", uploadRoutes);
router.use("/posts", postsRoutes);
router.use("/users", usersRoutes);
router.use("/reports", reportsRoutes);

export default router;
