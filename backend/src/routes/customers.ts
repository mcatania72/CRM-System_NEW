import { Router } from 'express';
import { body } from 'express-validator';
import { CustomerController } from '../controller/CustomerController';
import { authenticateToken } from '../middleware/auth';

const router = Router();

// Validazioni per i clienti
const customerValidation = [
    body('name').notEmpty().withMessage('Nome richiesto'),
    body('email').optional().isEmail().withMessage('Email non valida'),
    body('phone').optional().isMobilePhone('any').withMessage('Numero di telefono non valido')
];

// Applica autenticazione a tutte le routes
router.use(authenticateToken);

// Routes per i clienti
router.get('/', CustomerController.getAll);
router.get('/stats', CustomerController.getStats);
router.get('/:id', CustomerController.getById);
router.post('/', customerValidation, CustomerController.create);
router.put('/:id', customerValidation, CustomerController.update);
router.delete('/:id', CustomerController.delete);

export default router;