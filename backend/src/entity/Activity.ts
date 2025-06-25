import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, UpdateDateColumn, ManyToOne } from "typeorm";
import { User } from "./User";

export enum ActivityType {
    CALL = "call",
    EMAIL = "email",
    MEETING = "meeting",
    FOLLOWUP = "followup",
    TASK = "task"
}

export enum ActivityStatus {
    PENDING = "pending",
    IN_PROGRESS = "in_progress",
    COMPLETED = "completed",
    CANCELLED = "cancelled"
}

@Entity()
export class Activity {
    @PrimaryGeneratedColumn()
    id!: number;

    @Column()
    title!: string;

    @Column({ type: "text", nullable: true })
    description?: string;

    @Column({
        type: "simple-enum",
        enum: ActivityType
    })
    type!: ActivityType;

    @Column({
        type: "simple-enum",
        enum: ActivityStatus,
        default: ActivityStatus.PENDING
    })
    status!: ActivityStatus;

    @Column()
    dueDate!: Date;

    @Column({ nullable: true })
    completedDate?: Date;

    @Column({ type: "int", default: 1 }) // 1=Low, 2=Medium, 3=High
    priority!: number;

    @CreateDateColumn()
    createdAt!: Date;

    @UpdateDateColumn()
    updatedAt!: Date;

    @ManyToOne(() => User, user => user.activities)
    assignedTo!: User;

    @Column()
    assignedToId!: number;
}
