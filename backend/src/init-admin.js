#!/bin/bash

# init-admin.js
# Script per creare utente admin nel database CRM

const { AppDataSource } = require('./dist/data-source');
const { User, UserRole } = require('./dist/entity/User');
const bcrypt = require('bcryptjs');

async function createAdminUser() {
    try {
        console.log('🔗 Connessione al database...');
        await AppDataSource.initialize();
        console.log('✅ Database connesso con successo');

        const userRepository = AppDataSource.getRepository(User);
        
        // Verifica se l'admin esiste già
        const existingAdmin = await userRepository.findOne({ 
            where: { email: 'admin@crm.local' } 
        });

        if (existingAdmin) {
            console.log('ℹ️  Utente admin già esistente');
            console.log('📧 Email: admin@crm.local');
            console.log('🔑 Password: admin123');
            await AppDataSource.destroy();
            return;
        }

        // Crea hash della password
        console.log('🔐 Creazione hash password...');
        const hashedPassword = await bcrypt.hash('admin123', 10);

        // Crea nuovo utente admin
        const admin = new User();
        admin.email = 'admin@crm.local';
        admin.password = hashedPassword;
        admin.firstName = 'Admin';
        admin.lastName = 'CRM';
        admin.role = UserRole.ADMIN;
        admin.isActive = true;

        await userRepository.save(admin);

        console.log('🎉 Utente admin creato con successo!');
        console.log('📧 Email: admin@crm.local');
        console.log('🔑 Password: admin123');
        console.log('👤 Ruolo: ADMIN');

    } catch (error) {
        console.error('❌ Errore nella creazione utente admin:', error.message);
        process.exit(1);
    } finally {
        await AppDataSource.destroy();
        console.log('🔌 Connessione database chiusa');
    }
}

// Esegui la funzione
createAdminUser();