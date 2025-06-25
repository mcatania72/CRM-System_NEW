import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, UpdateDateColumn, ManyToOne } from "typeorm";
import { Customer } from "./Customer";

export enum OpportunityStage {
    PROSPECT = "prospect",
    QUALIFIED = "qualified",
    PROPOSAL = "proposal",
    NEGOTIATION = "negotiation",
    CLOSED_WON = "closed_won",
    CLOSED_LOST = "closed_lost"
}

@Entity()
export class Opportunity {
    @PrimaryGeneratedColumn()
    id!: number;

    @Column()
    title!: string;

    @Column({ type: "text", nullable: true })
    description?: string;

    @Column({ type: "decimal", precision: 10, scale: 2 })
    value!: number;

    @Column({ type: "int", default: 0 })
    probability!: number; // 0-100

    @Column({
        type: "simple-enum",
        enum: OpportunityStage,
        default: OpportunityStage.PROSPECT
    })
    stage!: OpportunityStage;

    @Column({ nullable: true })
    expectedCloseDate?: Date;

    @Column({ nullable: true })
    actualCloseDate?: Date;

    @CreateDateColumn()
    createdAt!: Date;

    @UpdateDateColumn()
    updatedAt!: Date;

    @ManyToOne(() => Customer, customer => customer.opportunities)
    customer!: Customer;

    @Column()
    customerId!: number;
}
