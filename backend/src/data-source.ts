import { DataSource } from "typeorm";
import { User } from "./entity/User";
import { Customer } from "./entity/Customer";
import { Opportunity } from "./entity/Opportunity";
import { Activity } from "./entity/Activity";
import { Interaction } from "./entity/Interaction";

export const AppDataSource = new DataSource({
    type: "sqlite",
    database: "database.sqlite",
    synchronize: true,
    logging: false,
    entities: [User, Customer, Opportunity, Activity, Interaction],
    migrations: [],
    subscribers: [],
});