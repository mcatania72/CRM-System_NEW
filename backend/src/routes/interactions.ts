import { Router } from 'express';
import { body } from 'express-validator';
import { InteractionController } from '../controller/InteractionController';
import { authenticateToken } from '../middleware/auth';

const router = Router();

// Validazioni per le interazioni
const interactionValidation = [
    body('type').isIn(['call', 'email', 'meeting', 'note']).withMessage('Tipo interazione non valido'),
    body('subject').notEmpty().withMessage('Oggetto richiesto'),
    body('content').notEmpty().withMessage('Contenuto richiesto'),
    body('customerId').isInt().withMessage('ID cliente richiesto')
];

// Applica autenticazione a tutte le routes
router.use(authenticateToken);

// Routes per le interazioni
router.get('/', InteractionController.getAll);
router.get('/recent', InteractionController.getRecentInteractions);
router.get('/customer/:customerId', InteractionController.getByCustomer);
router.get('/:id', InteractionController.getById);
router.post('/', interactionValidation, InteractionController.create);
router.put('/:id', interactionValidation, InteractionController.update);
router.delete('/:id', InteractionController.delete);

export default router;