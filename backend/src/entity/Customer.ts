import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, UpdateDateColumn, OneToMany } from "typeorm";
import { Opportunity } from "./Opportunity";
import { Interaction } from "./Interaction";

export enum CustomerStatus {
    PROSPECT = "prospect",
    ACTIVE = "active",
    INACTIVE = "inactive",
    LOST = "lost"
}

@Entity()
export class Customer {
    @PrimaryGeneratedColumn()
    id!: number;

    @Column()
    name!: string;

    @Column({ nullable: true })
    company?: string;

    @Column({ nullable: true })
    industry?: string;

    @Column({ nullable: true })
    email?: string;

    @Column({ nullable: true })
    phone?: string;

    @Column({ nullable: true })
    address?: string;

    @Column({ nullable: true })
    city?: string;

    @Column({ nullable: true })
    country?: string;

    @Column({
        type: "simple-enum",
        enum: CustomerStatus,
        default: CustomerStatus.PROSPECT
    })
    status!: CustomerStatus;

    @Column({ type: "text", nullable: true })
    notes?: string;

    @CreateDateColumn()
    createdAt!: Date;

    @UpdateDateColumn()
    updatedAt!: Date;

    @OneToMany(() => Opportunity, opportunity => opportunity.customer)
    opportunities!: Opportunity[];

    @OneToMany(() => Interaction, interaction => interaction.customer)
    interactions!: Interaction[];
}