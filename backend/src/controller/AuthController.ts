import { Request, Response } from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { AppDataSource } from '../data-source';
import { User, UserRole } from '../entity/User';
import { validationResult } from 'express-validator';

export class AuthController {
    
    static async register(req: Request, res: Response) {
        try {
            const errors = validationResult(req);
            if (!errors.isEmpty()) {
                return res.status(400).json({ errors: errors.array() });
            }

            const { email, password, firstName, lastName, role } = req.body;
            
            const userRepository = AppDataSource.getRepository(User);
            
            // Controlla se l'utente esiste già
            const existingUser = await userRepository.findOne({ where: { email } });
            if (existingUser) {
                return res.status(400).json({ message: 'Utente già esistente' });
            }

            // Hash password
            const saltRounds = 10;
            const hashedPassword = await bcrypt.hash(password, saltRounds);

            // Crea nuovo utente
            const user = new User();
            user.email = email;
            user.password = hashedPassword;
            user.firstName = firstName;
            user.lastName = lastName;
            user.role = role || UserRole.SALESPERSON;

            await userRepository.save(user);

            // Genera JWT token
            const token = jwt.sign(
                { userId: user.id, email: user.email },
                process.env.JWT_SECRET || 'fallback-secret',
                { expiresIn: '24h' }
            );

            res.status(201).json({
                message: 'Utente registrato con successo',
                token,
                user: {
                    id: user.id,
                    email: user.email,
                    firstName: user.firstName,
                    lastName: user.lastName,
                    role: user.role
                }
            });
        } catch (error) {
            console.error('Errore nella registrazione:', error);
            res.status(500).json({ message: 'Errore interno del server' });
        }
    }

    static async login(req: Request, res: Response) {
        try {
            const errors = validationResult(req);
            if (!errors.isEmpty()) {
                return res.status(400).json({ errors: errors.array() });
            }

            const { email, password } = req.body;
            
            const userRepository = AppDataSource.getRepository(User);
            const user = await userRepository.findOne({ where: { email } });

            if (!user || !user.isActive) {
                return res.status(401).json({ message: 'Credenziali non valide' });
            }

            // Verifica password
            const isPasswordValid = await bcrypt.compare(password, user.password);
            if (!isPasswordValid) {
                return res.status(401).json({ message: 'Credenziali non valide' });
            }

            // Genera JWT token
            const token = jwt.sign(
                { userId: user.id, email: user.email },
                process.env.JWT_SECRET || 'fallback-secret',
                { expiresIn: '24h' }
            );

            res.json({
                message: 'Login effettuato con successo',
                token,
                user: {
                    id: user.id,
                    email: user.email,
                    firstName: user.firstName,
                    lastName: user.lastName,
                    role: user.role
                }
            });
        } catch (error) {
            console.error('Errore nel login:', error);
            res.status(500).json({ message: 'Errore interno del server' });
        }
    }

    static async getProfile(req: any, res: Response) {
        try {
            const user = req.user;
            res.json({
                id: user.id,
                email: user.email,
                firstName: user.firstName,
                lastName: user.lastName,
                role: user.role,
                createdAt: user.createdAt
            });
        } catch (error) {
            console.error('Errore nel recupero profilo:', error);
            res.status(500).json({ message: 'Errore interno del server' });
        }
    }

    static async getUsers(req: Request, res: Response) {
        try {
            const userRepository = AppDataSource.getRepository(User);
            const users = await userRepository.find({
                where: { isActive: true },
                select: ['id', 'email', 'firstName', 'lastName', 'role', 'createdAt']
            });
            
            res.json(users);
        } catch (error) {
            console.error('Errore nel recupero utenti:', error);
            res.status(500).json({ message: 'Errore interno del server' });
        }
    }
}