import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, UpdateDateColumn, OneToMany } from "typeorm";
import { Activity } from "./Activity";
import { Interaction } from "./Interaction";

export enum UserRole {
    ADMIN = "admin",
    SALESPERSON = "salesperson",
    MANAGER = "manager"
}

@Entity()
export class User {
    @PrimaryGeneratedColumn()
    id!: number;

    @Column({ unique: true })
    email!: string;

    @Column()
    password!: string;

    @Column()
    firstName!: string;

    @Column()
    lastName!: string;

    @Column({
        type: "simple-enum",
        enum: UserRole,
        default: UserRole.SALESPERSON
    })
    role!: UserRole;

    @Column({ default: true })
    isActive!: boolean;

    @CreateDateColumn()
    createdAt!: Date;

    @UpdateDateColumn()
    updatedAt!: Date;

    @OneToMany(() => Activity, activity => activity.assignedTo)
    activities!: Activity[];

    @OneToMany(() => Interaction, interaction => interaction.user)
    interactions!: Interaction[];
}