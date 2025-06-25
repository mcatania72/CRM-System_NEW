import { Router } from 'express';
import { body } from 'express-validator';
import { OpportunityController } from '../controller/OpportunityController';
import { authenticateToken } from '../middleware/auth';

const router = Router();

// Validazioni per le opportunità
const opportunityValidation = [
    body('title').notEmpty().withMessage('Titolo richiesto'),
    body('value').isNumeric().withMessage('Valore deve essere numerico'),
    body('probability').isInt({ min: 0, max: 100 }).withMessage('Probabilità deve essere tra 0 e 100'),
    body('customerId').isInt().withMessage('ID cliente richiesto')
];

// Applica autenticazione a tutte le routes
router.use(authenticateToken);

// Routes per le opportunità
router.get('/', OpportunityController.getAll);
router.get('/stats', OpportunityController.getStats);
router.get('/:id', OpportunityController.getById);
router.post('/', opportunityValidation, OpportunityController.create);
router.put('/:id', opportunityValidation, OpportunityController.update);
router.delete('/:id', OpportunityController.delete);

export default router;