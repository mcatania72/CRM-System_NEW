import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, ManyToOne } from "typeorm";
import { Customer } from "./Customer";
import { User } from "./User";

export enum InteractionType {
    CALL = "call",
    EMAIL = "email",
    MEETING = "meeting",
    NOTE = "note"
}

@Entity()
export class Interaction {
    @PrimaryGeneratedColumn()
    id!: number;

    @Column({
        type: "simple-enum",
        enum: InteractionType
    })
    type!: InteractionType;

    @Column()
    subject!: string;

    @Column({ type: "text" })
    content!: string;

    @Column({ nullable: true })
    attachments?: string; // JSON string of file paths

    @CreateDateColumn()
    createdAt!: Date;

    @ManyToOne(() => Customer, customer => customer.interactions)
    customer!: Customer;

    @Column()
    customerId!: number;

    @ManyToOne(() => User, user => user.interactions)
    user!: User;

    @Column()
    userId!: number;
}
