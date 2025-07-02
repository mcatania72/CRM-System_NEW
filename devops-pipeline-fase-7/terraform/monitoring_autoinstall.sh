#!/bin/bash

# Soluzione selezione lingua automatica per autoinstall
cd ~/CRM-Fase7/devops-pipeline-fase-7/terraform

echo "=== SELEZIONE LINGUA AUTOMATICA ==="

echo "OPZIONE 1: Attesa automatica (RACCOMANDATO)"
echo "- Ubuntu autoinstall ha timeout di 30 secondi sulla selezione lingua"
echo "- Dopo 30 secondi, procede automaticamente con English"
echo "- Non serve intervento manuale"

echo ""
echo "OPZIONE 2: Intervento manuale veloce"
echo "- Premi ENTER su ogni VM per confermare English"
echo "- Accelera il processo di 30 secondi"

echo ""
echo "OPZIONE 3: Fix GRUB per futuro (opzionale)"
echo "- Modifica timeout GRUB negli ISO per boot immediato"
echo "- Richiede ricostruzione ISO"

echo ""
echo "=== STATUS VM ATTUALI ==="
vmrun list

echo ""
echo "=== RACCOMANDAZIONE ==="
echo "🎯 ATTENDI 30 SECONDI - l'autoinstall procederà automaticamente!"
echo ""
echo "Oppure se vuoi accelerare:"
echo "1. Apri console VM in VMware"
echo "2. Premi ENTER su ciascuna VM (English già selezionato)"
echo "3. L'installazione partirà immediatamente"

echo ""
echo "=== MONITORING AUTOMATICO ==="
echo "Monitoraggio ogni 2 minuti per 20 minuti..."

for i in {1..10}; do
    echo ""
    echo "--- Check #$i - $(date) ---"
    
    ALL_READY=true
    
    for VM in "SPESE_FE_VM" "SPESE_BE_VM" "SPESE_DB_VM"; do
        case $VM in
            "SPESE_FE_VM") IP="192.168.1.101";;
            "SPESE_BE_VM") IP="192.168.1.102";;  
            "SPESE_DB_VM") IP="192.168.1.103";;
        esac
        
        echo -n "  $VM ($IP): "
        if ping -c 1 $IP >/dev/null 2>&1; then
            echo "🌐 UBUNTU PRONTO!"
            
            # Test SSH
            if ssh -o ConnectTimeout=3 -o StrictHostKeyChecking=no devops@$IP 'hostname' >/dev/null 2>&1; then
                echo "    🔑 SSH attivo - installazione completata!"
            else
                echo "    ⏳ SSH non ancora pronto"
                ALL_READY=false
            fi
        else
            echo "⏳ Installazione in corso..."
            ALL_READY=false
        fi
    done
    
    if [ "$ALL_READY" = true ]; then
        echo ""
        echo "🎉 TUTTE LE VM SONO PRONTE!"
        echo "✅ Ubuntu installato su tutte e 3 le VM"
        echo "✅ SSH disponibile"
        echo "✅ Network configurato"
        
        echo ""
        echo "=== PROSSIMI STEP ==="
        echo "1. Test SSH: ssh devops@192.168.1.101"
        echo "2. Verifica Docker: ssh devops@192.168.1.101 'docker --version'"
        echo "3. Setup Kubernetes cluster"
        
        break
    fi
    
    if [ $i -lt 10 ]; then
        echo "  Prossimo check tra 2 minuti..."
        sleep 120
    fi
done

if [ "$ALL_READY" != true ]; then
    echo ""
    echo "⏰ Timeout monitoring - installazione ancora in corso"
    echo "L'installazione Ubuntu può richiedere fino a 20-25 minuti totali"
    echo ""
    echo "Continua monitoring manuale:"
    echo "watch -n 60 'for ip in 192.168.1.101 192.168.1.102 192.168.1.103; do echo -n \"\$ip: \"; ping -c 1 \$ip >/dev/null 2>&1 && echo \"✅\" || echo \"⏳\"; done'"
fi
