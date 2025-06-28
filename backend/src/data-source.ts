import "dotenv/config";
import { DataSource } from "typeorm";
import { User } from "./entity/User";
import { Customer } from "./entity/Customer";
import { Opportunity } from "./entity/Opportunity";
import { Activity } from "./entity/Activity";
import { Interaction } from "./entity/Interaction";

export const AppDataSource = new DataSource({
    type: "postgres",
    host: process.env.DB_HOST || "localhost",
    port: Number(process.env.DB_PORT) || 5432,
    username: process.env.DB_USERNAME || "postgres",
    password: process.env.DB_PASSWORD || "postgres",
    database: process.env.DB_DATABASE || "crm",
    synchronize: true, // ATTENZIONE: usare solo in sviluppo
    logging: false,
    entities: [User, Customer, Opportunity, Activity, Interaction],
    migrations: [],
    subscribers: [],
});