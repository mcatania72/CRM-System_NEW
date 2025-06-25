import { Router } from 'express';
import { body } from 'express-validator';
import { ActivityController } from '../controller/ActivityController';
import { authenticateToken } from '../middleware/auth';

const router = Router();

// Validazioni per le attività
const activityValidation = [
    body('title').notEmpty().withMessage('Titolo richiesto'),
    body('type').isIn(['call', 'email', 'meeting', 'followup', 'task']).withMessage('Tipo attività non valido'),
    body('dueDate').isISO8601().withMessage('Data di scadenza non valida'),
    body('assignedToId').isInt().withMessage('ID utente assegnato richiesto'),
    body('priority').isInt({ min: 1, max: 3 }).withMessage('Priorità deve essere 1, 2 o 3')
];

// Applica autenticazione a tutte le routes
router.use(authenticateToken);

// Routes per le attività
router.get('/', ActivityController.getAll);
router.get('/my-activities', ActivityController.getMyActivities);
router.get('/upcoming', ActivityController.getUpcoming);
router.get('/:id', ActivityController.getById);
router.post('/', activityValidation, ActivityController.create);
router.put('/:id', activityValidation, ActivityController.update);
router.delete('/:id', ActivityController.delete);

export default router;