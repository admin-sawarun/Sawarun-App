import { Router } from 'express';
import { requireAuth } from '../middleware/auth.js';
import { adminOnly } from '../middleware/adminOnly.js';
import {
  getAnalytics,
  getTimeseries,
  getUserDetail,
  listUsers,
  listBrands,
  listAllProducts,
  setProductApproval,
  decideBrand,
  setProductVisibility,
  setFeaturedBrand,
  getFitWeights,
  updateFitWeights,
  moderateUser,
  setUserAdmin,
} from '../controllers/admin.controller.js';
import { listReports, resolveReport } from '../controllers/reports.controller.js';

const router = Router();

// Every admin route requires a logged-in user WITH the admin claim.
router.use(requireAuth, adminOnly);

router.get('/analytics', getAnalytics);
router.get('/analytics/timeseries', getTimeseries);

router.get('/users', listUsers);
router.get('/users/:uid', getUserDetail);
router.get('/brands', listBrands);
router.get('/products', listAllProducts);

router.post('/brands/:id/decision', decideBrand);
router.patch('/products/:id/visibility', setProductVisibility);
router.patch('/products/:id/approval', setProductApproval);
router.put('/featured-brand', setFeaturedBrand);

router.get('/fit-weights', getFitWeights);
router.put('/fit-weights', updateFitWeights);

router.post('/users/:uid/moderate', moderateUser);
router.post('/users/:uid/set-admin', setUserAdmin);

// Content moderation queue (user reports).
router.get('/reports', listReports);
router.post('/reports/:id/resolve', resolveReport);

export default router;
