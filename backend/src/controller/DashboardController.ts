import { Request, Response } from 'express';
import { AppDataSource } from '../data-source';
import { Customer, CustomerStatus } from '../entity/Customer';
import { Opportunity, OpportunityStage } from '../entity/Opportunity';
import { Activity, ActivityStatus } from '../entity/Activity';
import { Interaction } from '../entity/Interaction';
import { AuthRequest } from '../middleware/auth';

export class DashboardController {
    
    static async getDashboardStats(req: AuthRequest, res: Response) {
        try {
            const customerRepository = AppDataSource.getRepository(Customer);
            const opportunityRepository = AppDataSource.getRepository(Opportunity);
            const activityRepository = AppDataSource.getRepository(Activity);
            const interactionRepository = AppDataSource.getRepository(Interaction);

            // Statistiche clienti
            const totalCustomers = await customerRepository.count();
            const activeCustomers = await customerRepository.count({ where: { status: CustomerStatus.ACTIVE } });
            const newCustomersThisMonth = await customerRepository
                .createQueryBuilder('customer')
                .where('customer.createdAt >= :startOfMonth', { 
                    startOfMonth: new Date(new Date().getFullYear(), new Date().getMonth(), 1) 
                })
                .getCount();

            // Statistiche opportunità
            const totalOpportunities = await opportunityRepository.count();
            const openOpportunities = await opportunityRepository
                .createQueryBuilder('opportunity')
                .where('opportunity.stage NOT IN (:...closedStages)', { 
                    closedStages: [OpportunityStage.CLOSED_WON, OpportunityStage.CLOSED_LOST] 
                })
                .getCount();

            const totalValue = await opportunityRepository
                .createQueryBuilder('opportunity')
                .select('SUM(opportunity.value)', 'total')
                .getRawOne();

            const wonOpportunities = await opportunityRepository.count({ 
                where: { stage: OpportunityStage.CLOSED_WON } 
            });

            // Statistiche attività
            const totalActivities = await activityRepository.count();
            const pendingActivities = await activityRepository.count({ 
                where: { status: ActivityStatus.PENDING } 
            });

            const overdueTasks = await activityRepository
                .createQueryBuilder('activity')
                .where('activity.dueDate < :today', { today: new Date() })
                .andWhere('activity.status != :completed', { completed: ActivityStatus.COMPLETED })
                .getCount();

            // Interazioni recenti
            const recentInteractions = await interactionRepository.count();
            const interactionsThisWeek = await interactionRepository
                .createQueryBuilder('interaction')
                .where('interaction.createdAt >= :startOfWeek', { 
                    startOfWeek: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000) 
                })
                .getCount();

            // Opportunità per stadio
            const opportunitiesByStage = await opportunityRepository
                .createQueryBuilder('opportunity')
                .select('opportunity.stage', 'stage')
                .addSelect('COUNT(*)', 'count')
                .addSelect('SUM(opportunity.value)', 'totalValue')
                .groupBy('opportunity.stage')
                .getRawMany();

            // Attività per tipo
            const activitiesByType = await activityRepository
                .createQueryBuilder('activity')
                .select('activity.type', 'type')
                .addSelect('COUNT(*)', 'count')
                .groupBy('activity.type')
                .getRawMany();

            // Trend mensile clienti (ultimi 6 mesi)
            const customerTrend = await customerRepository
                .createQueryBuilder('customer')
                .select(`strftime('%Y-%m', customer.createdAt)`, 'month')
                .addSelect('COUNT(*)', 'count')
                .where('customer.createdAt >= :sixMonthsAgo', { 
                    sixMonthsAgo: new Date(Date.now() - 6 * 30 * 24 * 60 * 60 * 1000) 
                })
                .groupBy('month')
                .orderBy('month', 'ASC')
                .getRawMany();

            // Performance vendite mensile
            const salesPerformance = await opportunityRepository
                .createQueryBuilder('opportunity')
                .select(`strftime('%Y-%m', opportunity.actualCloseDate)`, 'month')
                .addSelect('COUNT(*)', 'count')
                .addSelect('SUM(opportunity.value)', 'totalValue')
                .where('opportunity.stage = :stage', { stage: OpportunityStage.CLOSED_WON })
                .andWhere('opportunity.actualCloseDate >= :sixMonthsAgo', { 
                    sixMonthsAgo: new Date(Date.now() - 6 * 30 * 24 * 60 * 60 * 1000) 
                })
                .groupBy('month')
                .orderBy('month', 'ASC')
                .getRawMany();

            res.json({
                customers: {
                    total: totalCustomers,
                    active: activeCustomers,
                    newThisMonth: newCustomersThisMonth
                },
                opportunities: {
                    total: totalOpportunities,
                    open: openOpportunities,
                    totalValue: totalValue.total || 0,
                    won: wonOpportunities
                },
                activities: {
                    total: totalActivities,
                    pending: pendingActivities,
                    overdue: overdueTasks
                },
                interactions: {
                    total: recentInteractions,
                    thisWeek: interactionsThisWeek
                },
                charts: {
                    opportunitiesByStage,
                    activitiesByType,
                    customerTrend,
                    salesPerformance
                }
            });
        } catch (error) {
            console.error('Errore nel recupero statistiche dashboard:', error);
            res.status(500).json({ message: 'Errore interno del server' });
        }
    }

    static async getReports(req: Request, res: Response) {
        try {
            const { type, startDate, endDate, format = 'json' } = req.query;

            let report = {};

            switch (type) {
                case 'customers':
                    report = await DashboardController.generateCustomerReport(
                        startDate as string, 
                        endDate as string
                    );
                    break;
                case 'opportunities':
                    report = await DashboardController.generateOpportunityReport(
                        startDate as string, 
                        endDate as string
                    );
                    break;
                case 'activities':
                    report = await DashboardController.generateActivityReport(
                        startDate as string, 
                        endDate as string
                    );
                    break;
                case 'sales':
                    report = await DashboardController.generateSalesReport(
                        startDate as string, 
                        endDate as string
                    );
                    break;
                default:
                    return res.status(400).json({ message: 'Tipo di report non valido' });
            }

            res.json(report);
        } catch (error) {
            console.error('Errore nella generazione report:', error);
            res.status(500).json({ message: 'Errore interno del server' });
        }
    }

    private static async generateCustomerReport(startDate: string, endDate: string) {
        const customerRepository = AppDataSource.getRepository(Customer);
        const queryBuilder = customerRepository.createQueryBuilder('customer');

        if (startDate) {
            queryBuilder.where('customer.createdAt >= :startDate', { startDate });
        }
        if (endDate) {
            queryBuilder.andWhere('customer.createdAt <= :endDate', { endDate });
        }

        const customers = await queryBuilder.getMany();
        
        const summary = {
            totalCustomers: customers.length,
            byStatus: customers.reduce((acc: any, customer) => {
                acc[customer.status] = (acc[customer.status] || 0) + 1;
                return acc;
            }, {}),
            byIndustry: customers.reduce((acc: any, customer) => {
                const industry = customer.industry || 'Non specificato';
                acc[industry] = (acc[industry] || 0) + 1;
                return acc;
            }, {})
        };

        return {
            title: 'Report Clienti',
            period: { startDate, endDate },
            summary,
            data: customers
        };
    }

    private static async generateOpportunityReport(startDate: string, endDate: string) {
        const opportunityRepository = AppDataSource.getRepository(Opportunity);
        const queryBuilder = opportunityRepository.createQueryBuilder('opportunity')
            .leftJoinAndSelect('opportunity.customer', 'customer');

        if (startDate) {
            queryBuilder.where('opportunity.createdAt >= :startDate', { startDate });
        }
        if (endDate) {
            queryBuilder.andWhere('opportunity.createdAt <= :endDate', { endDate });
        }

        const opportunities = await queryBuilder.getMany();

        const summary = {
            totalOpportunities: opportunities.length,
            totalValue: opportunities.reduce((sum, opp) => sum + Number(opp.value), 0),
            byStage: opportunities.reduce((acc: any, opp) => {
                acc[opp.stage] = (acc[opp.stage] || 0) + 1;
                return acc;
            }, {}),
            averageValue: opportunities.length ? 
                opportunities.reduce((sum, opp) => sum + Number(opp.value), 0) / opportunities.length : 0
        };

        return {
            title: 'Report Opportunità',
            period: { startDate, endDate },
            summary,
            data: opportunities
        };
    }

    private static async generateActivityReport(startDate: string, endDate: string) {
        const activityRepository = AppDataSource.getRepository(Activity);
        const queryBuilder = activityRepository.createQueryBuilder('activity')
            .leftJoinAndSelect('activity.assignedTo', 'user');

        if (startDate) {
            queryBuilder.where('activity.createdAt >= :startDate', { startDate });
        }
        if (endDate) {
            queryBuilder.andWhere('activity.createdAt <= :endDate', { endDate });
        }

        const activities = await queryBuilder.getMany();

        const summary = {
            totalActivities: activities.length,
            byStatus: activities.reduce((acc: any, activity) => {
                acc[activity.status] = (acc[activity.status] || 0) + 1;
                return acc;
            }, {}),
            byType: activities.reduce((acc: any, activity) => {
                acc[activity.type] = (acc[activity.type] || 0) + 1;
                return acc;
            }, {}),
            completionRate: activities.length ? 
                (activities.filter(a => a.status === 'completed').length / activities.length) * 100 : 0
        };

        return {
            title: 'Report Attività',
            period: { startDate, endDate },
            summary,
            data: activities
        };
    }

    private static async generateSalesReport(startDate: string, endDate: string) {
        const opportunityRepository = AppDataSource.getRepository(Opportunity);
        const queryBuilder = opportunityRepository.createQueryBuilder('opportunity')
            .leftJoinAndSelect('opportunity.customer', 'customer')
            .where('opportunity.stage = :stage', { stage: 'closed_won' });

        if (startDate) {
            queryBuilder.andWhere('opportunity.actualCloseDate >= :startDate', { startDate });
        }
        if (endDate) {
            queryBuilder.andWhere('opportunity.actualCloseDate <= :endDate', { endDate });
        }

        const closedOpportunities = await queryBuilder.getMany();

        const summary = {
            totalSales: closedOpportunities.length,
            totalRevenue: closedOpportunities.reduce((sum, opp) => sum + Number(opp.value), 0),
            averageDealSize: closedOpportunities.length ? 
                closedOpportunities.reduce((sum, opp) => sum + Number(opp.value), 0) / closedOpportunities.length : 0,
            topCustomers: closedOpportunities.reduce((acc: any, opp) => {
                if (opp.customer && opp.customer.id) {
                    const customerId = opp.customer.id;
                    if (!acc[customerId]) {
                        acc[customerId] = {
                            customer: opp.customer.name,
                            deals: 0,
                            revenue: 0
                        };
                    }
                    acc[customerId].deals += 1;
                    acc[customerId].revenue += Number(opp.value);
                }
                return acc;
            }, {})
        };

        return {
            title: 'Report Vendite',
            period: { startDate, endDate },
            summary,
            data: closedOpportunities
        };
    }
}