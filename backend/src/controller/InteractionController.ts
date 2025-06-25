import { Request, Response } from 'express';
import { AppDataSource } from '../data-source';
import { Interaction } from '../entity/Interaction';
import { Customer } from '../entity/Customer';
import { validationResult } from 'express-validator';
import { AuthRequest } from '../middleware/auth';

export class InteractionController {
    
    static async getAll(req: Request, res: Response) {
        try {
            const { type, customerId, userId, page = 1, limit = 10 } = req.query;
            
            const interactionRepository = AppDataSource.getRepository(Interaction);
            const queryBuilder = interactionRepository.createQueryBuilder('interaction')
                .leftJoinAndSelect('interaction.customer', 'customer')
                .leftJoinAndSelect('interaction.user', 'user');

            // Filtri
            if (type) {
                queryBuilder.where('interaction.type = :type', { type });
            }

            if (customerId) {
                queryBuilder.andWhere('interaction.customerId = :customerId', { customerId });
            }

            if (userId) {
                queryBuilder.andWhere('interaction.userId = :userId', { userId });
            }

            // Paginazione
            const skip = (Number(page) - 1) * Number(limit);
            queryBuilder.skip(skip).take(Number(limit));

            // Ordinamento per data di creazione
            queryBuilder.orderBy('interaction.createdAt', 'DESC');

            const [interactions, total] = await queryBuilder.getManyAndCount();

            res.json({
                interactions,
                pagination: {
                    page: Number(page),
                    limit: Number(limit),
                    total,
                    totalPages: Math.ceil(total / Number(limit))
                }
            });
        } catch (error) {
            console.error('Errore nel recupero interazioni:', error);
            res.status(500).json({ message: 'Errore interno del server' });
        }
    }

    static async getById(req: Request, res: Response) {
        try {
            const { id } = req.params;
            const interactionRepository = AppDataSource.getRepository(Interaction);
            
            const interaction = await interactionRepository.findOne({
                where: { id: Number(id) },
                relations: ['customer', 'user']
            });

            if (!interaction) {
                return res.status(404).json({ message: 'Interazione non trovata' });
            }

            res.json(interaction);
        } catch (error) {
            console.error('Errore nel recupero interazione:', error);
            res.status(500).json({ message: 'Errore interno del server' });
        }
    }

    static async create(req: AuthRequest, res: Response) {
        try {
            const errors = validationResult(req);
            if (!errors.isEmpty()) {
                return res.status(400).json({ errors: errors.array() });
            }

            const { customerId } = req.body;
            
            // Verifica che il cliente esista
            const customerRepository = AppDataSource.getRepository(Customer);
            const customer = await customerRepository.findOne({ where: { id: customerId } });
            
            if (!customer) {
                return res.status(400).json({ message: 'Cliente non trovato' });
            }

            const interactionRepository = AppDataSource.getRepository(Interaction);
            const newInteraction = interactionRepository.create({
                ...req.body,
                userId: req.user?.id
            });
            
            const savedInteraction = await interactionRepository.save(newInteraction) as unknown as Interaction;
            
            // Ricarica con le relazioni
            const interactionWithRelations = await interactionRepository.findOne({
                where: { id: savedInteraction.id },
                relations: ['customer', 'user']
            });
            
            res.status(201).json({
                message: 'Interazione creata con successo',
                interaction: interactionWithRelations
            });
        } catch (error) {
            console.error('Errore nella creazione interazione:', error);
            res.status(500).json({ message: 'Errore interno del server' });
        }
    }

    static async update(req: Request, res: Response) {
        try {
            const errors = validationResult(req);
            if (!errors.isEmpty()) {
                return res.status(400).json({ errors: errors.array() });
            }

            const { id } = req.params;
            const interactionRepository = AppDataSource.getRepository(Interaction);
            
            let interaction = await interactionRepository.findOne({ 
                where: { id: Number(id) },
                relations: ['customer', 'user']
            });
            
            if (!interaction) {
                return res.status(404).json({ message: 'Interazione non trovata' });
            }

            interactionRepository.merge(interaction, req.body);
            await interactionRepository.save(interaction);

            res.json({
                message: 'Interazione aggiornata con successo',
                interaction
            });
        } catch (error) {
            console.error('Errore nell\'aggiornamento interazione:', error);
            res.status(500).json({ message: 'Errore interno del server' });
        }
    }

    static async delete(req: Request, res: Response) {
        try {
            const { id } = req.params;
            const interactionRepository = AppDataSource.getRepository(Interaction);
            
            const interaction = await interactionRepository.findOne({ where: { id: Number(id) } });
            if (!interaction) {
                return res.status(404).json({ message: 'Interazione non trovata' });
            }

            await interactionRepository.remove(interaction);
            
            res.json({ message: 'Interazione eliminata con successo' });
        } catch (error) {
            console.error('Errore nell\'eliminazione interazione:', error);
            res.status(500).json({ message: 'Errore interno del server' });
        }
    }

    static async getByCustomer(req: Request, res: Response) {
        try {
            const { customerId } = req.params;
            const interactionRepository = AppDataSource.getRepository(Interaction);
            
            const interactions = await interactionRepository.find({
                where: { customerId: Number(customerId) },
                relations: ['user'],
                order: { createdAt: 'DESC' }
            });

            res.json(interactions);
        } catch (error) {
            console.error('Errore nel recupero interazioni per cliente:', error);
            res.status(500).json({ message: 'Errore interno del server' });
        }
    }

    static async getRecentInteractions(req: Request, res: Response) {
        try {
            const { limit = 10 } = req.query;
            const interactionRepository = AppDataSource.getRepository(Interaction);
            
            const interactions = await interactionRepository.find({
                relations: ['customer', 'user'],
                order: { createdAt: 'DESC' },
                take: Number(limit)
            });

            res.json(interactions);
        } catch (error) {
            console.error('Errore nel recupero interazioni recenti:', error);
            res.status(500).json({ message: 'Errore interno del server' });
        }
    }
}