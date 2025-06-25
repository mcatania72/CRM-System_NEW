import { Router } from 'express';
import { DashboardController } from '../controller/DashboardController';
import { authenticateToken } from '../middleware/auth';

const router = Router();

// Applica autenticazione a tutte le routes
router.use(authenticateToken);

// Routes per dashboard e report
router.get('/stats', DashboardController.getDashboardStats);
router.get('/reports', DashboardController.getReports);

export default router;