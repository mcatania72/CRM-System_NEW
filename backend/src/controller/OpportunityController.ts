import { Request, Response } from 'express';
import { AppDataSource } from '../data-source';
import { Opportunity } from '../entity/Opportunity';
import { Customer } from '../entity/Customer';
import { validationResult } from 'express-validator';

export class OpportunityController {
    
    static async getAll(req: Request, res: Response) {
        try {
            const { stage, customerId, page = 1, limit = 10 } = req.query;
            
            const opportunityRepository = AppDataSource.getRepository(Opportunity);
            const queryBuilder = opportunityRepository.createQueryBuilder('opportunity')
                .leftJoinAndSelect('opportunity.customer', 'customer');

            // Filtri
            if (stage) {
                queryBuilder.where('opportunity.stage = :stage', { stage });
            }

            if (customerId) {
                queryBuilder.andWhere('opportunity.customerId = :customerId', { customerId });
            }

            // Paginazione
            const skip = (Number(page) - 1) * Number(limit);
            queryBuilder.skip(skip).take(Number(limit));

            // Ordinamento
            queryBuilder.orderBy('opportunity.createdAt', 'DESC');

            const [opportunities, total] = await queryBuilder.getManyAndCount();

            res.json({
                opportunities,
                pagination: {
                    page: Number(page),
                    limit: Number(limit),
                    total,
                    totalPages: Math.ceil(total / Number(limit))
                }
            });
        } catch (error) {
            console.error('Errore nel recupero opportunità:', error);
            res.status(500).json({ message: 'Errore interno del server' });
        }
    }

    static async getById(req: Request, res: Response) {
        try {
            const { id } = req.params;
            const opportunityRepository = AppDataSource.getRepository(Opportunity);
            
            const opportunity = await opportunityRepository.findOne({
                where: { id: Number(id) },
                relations: ['customer']
            });

            if (!opportunity) {
                return res.status(404).json({ message: 'Opportunità non trovata' });
            }

            res.json(opportunity);
        } catch (error) {
            console.error('Errore nel recupero opportunità:', error);
            res.status(500).json({ message: 'Errore interno del server' });
        }
    }

    static async create(req: Request, res: Response) {
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

            const opportunityRepository = AppDataSource.getRepository(Opportunity);
            const newOpportunity = opportunityRepository.create(req.body);
            
            // Salva e ottieni l'entità salvata
            const savedOpportunity = await opportunityRepository.save(newOpportunity) as unknown as Opportunity;
            
            // Ora newOpportunity dovrebbe avere l'id assegnato
            const opportunityWithRelations = await opportunityRepository.findOne({
                where: { id: savedOpportunity.id },
                relations: ['customer']
            });
            
            res.status(201).json({
                message: 'Opportunità creata con successo',
                opportunity: opportunityWithRelations
            });
        } catch (error) {
            console.error('Errore nella creazione opportunità:', error);
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
            const opportunityRepository = AppDataSource.getRepository(Opportunity);
            
            let opportunity = await opportunityRepository.findOne({ 
                where: { id: Number(id) },
                relations: ['customer']
            });
            
            if (!opportunity) {
                return res.status(404).json({ message: 'Opportunità non trovata' });
            }

            opportunityRepository.merge(opportunity, req.body);
            await opportunityRepository.save(opportunity);

            res.json({
                message: 'Opportunità aggiornata con successo',
                opportunity
            });
        } catch (error) {
            console.error('Errore nell\'aggiornamento opportunità:', error);
            res.status(500).json({ message: 'Errore interno del server' });
        }
    }

    static async delete(req: Request, res: Response) {
        try {
            const { id } = req.params;
            const opportunityRepository = AppDataSource.getRepository(Opportunity);
            
            const opportunity = await opportunityRepository.findOne({ where: { id: Number(id) } });
            if (!opportunity) {
                return res.status(404).json({ message: 'Opportunità non trovata' });
            }

            await opportunityRepository.remove(opportunity);
            
            res.json({ message: 'Opportunità eliminata con successo' });
        } catch (error) {
            console.error('Errore nell\'eliminazione opportunità:', error);
            res.status(500).json({ message: 'Errore interno del server' });
        }
    }

    static async getStats(req: Request, res: Response) {
        try {
            const opportunityRepository = AppDataSource.getRepository(Opportunity);
            
            const totalOpportunities = await opportunityRepository.count();
            
            const stageStats = await opportunityRepository
                .createQueryBuilder('opportunity')
                .select('opportunity.stage', 'stage')
                .addSelect('COUNT(*)', 'count')
                .addSelect('SUM(opportunity.value)', 'totalValue')
                .groupBy('opportunity.stage')
                .getRawMany();

            const totalValue = await opportunityRepository
                .createQueryBuilder('opportunity')
                .select('SUM(opportunity.value)', 'total')
                .getRawOne();

            const averageValue = await opportunityRepository
                .createQueryBuilder('opportunity')
                .select('AVG(opportunity.value)', 'average')
                .getRawOne();

            res.json({
                totalOpportunities,
                totalValue: totalValue.total || 0,
                averageValue: averageValue.average || 0,
                stageStats
            });
        } catch (error) {
            console.error('Errore nel recupero statistiche opportunità:', error);
            res.status(500).json({ message: 'Errore interno del server' });
        }
    }
}