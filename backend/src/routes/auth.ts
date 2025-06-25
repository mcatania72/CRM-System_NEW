import { Router } from 'express';
import { body } from 'express-validator';
import { AuthController } from '../controller/AuthController';
import { authenticateToken } from '../middleware/auth';

const router = Router();

// Validazioni per la registrazione
const registerValidation = [
    body('email').isEmail().withMessage('Email non valida'),
    body('password').isLength({ min: 6 }).withMessage('Password deve essere di almeno 6 caratteri'),
    body('firstName').notEmpty().withMessage('Nome richiesto'),
    body('lastName').notEmpty().withMessage('Cognome richiesto')
];

// Validazioni per il login
const loginValidation = [
    body('email').isEmail().withMessage('Email non valida'),
    body('password').notEmpty().withMessage('Password richiesta')
];

// Routes pubbliche
router.post('/register', registerValidation, AuthController.register);
router.post('/login', loginValidation, AuthController.login);

// Routes protette
router.get('/profile', authenticateToken, AuthController.getProfile);
router.get('/users', authenticateToken, AuthController.getUsers);

export default router;
