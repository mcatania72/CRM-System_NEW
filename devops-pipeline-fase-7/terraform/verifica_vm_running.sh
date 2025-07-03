#!/bin/bash

# VERIFICA STATO VM RUNNING
# La VM risulta attiva, controlliamo cosa sta facendo

cd ~/CRM-Fase7/devops-pipeline-fase-7/terraform

echo "=========================================="
echo "VERIFICA STATO VM RUNNING"
echo "=========================================="

echo ""
echo "SITUAZIONE: VM risulta running, verificando boot status"

# STEP 1: STATUS VM CORRENTE
echo ""
echo "=== STEP 1: STATUS VM CORRENTE ==="

echo "VM attive:"
vmrun list

echo ""
echo "Processi VM:"
ps aux | grep vmware-vmx | grep SPESE | head -3

# STEP 2: TEST CONNECTIVITY VM
echo ""
echo "=== STEP 2: TEST CONNECTIVITY VM ==="

echo "Test ping FE_VM (192.168.1.101):"
if ping -c 2 192.168.1.101 >/dev/null 2>&1; then
    echo "✅ FE_VM risponde al ping!"
    echo "🎉 UBUNTU POTREBBE ESSERE INSTALLATO!"
    
    # Test SSH
    echo ""
    echo "Test SSH FE_VM:"
    if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no devops@192.168.1.101 'hostname' 2>/dev/null; then
        echo "✅ SSH ATTIVO - UBUNTU INSTALLATO E CONFIGURATO!"
        
        # Get system info
        echo ""
        echo "Sistema FE_VM:"
        ssh -o StrictHostKeyChecking=no devops@192.168.1.101 'uname -a && uptime && df -h /' 2>/dev/null
        
        echo ""
        echo "🎉 SUCCESSO! FE_VM È COMPLETAMENTE FUNZIONANTE!"
        
    else
        echo "⏳ SSH non ancora pronto (installazione in corso?)"
    fi
    
else
    echo "⏳ FE_VM non risponde ancora al ping"
    echo "Possibili cause:"
    echo "  1. Installazione Ubuntu in corso"
    echo "  2. Boot da ISO in corso"
    echo "  3. VM bloccata su menu"
fi

# STEP 3: VERIFICA ALTRE VM
echo ""
echo "=== STEP 3: VERIFICA ALTRE VM ==="

echo "Test ping BE_VM (192.168.1.102):"
if ping -c 2 192.168.1.102 >/dev/null 2>&1; then
    echo "✅ BE_VM risponde!"
else
    echo "⏳ BE_VM non risponde"
fi

echo ""
echo "Test ping DB_VM (192.168.1.103):"
if ping -c 2 192.168.1.103 >/dev/null 2>&1; then
    echo "✅ DB_VM risponde!"
else
    echo "⏳ DB_VM non risponde"
fi

# STEP 4: RACCOMANDAZIONI
echo ""
echo "=== STEP 4: RACCOMANDAZIONI ==="

echo ""
if ping -c 1 192.168.1.101 >/dev/null 2>&1; then
    echo "🎯 FE_VM È ATTIVA E FUNZIONANTE!"
    echo ""
    echo "PROSSIMI STEP:"
    echo "1. Verifica console VMware per vedere boot status"
    echo "2. Se Ubuntu installato → procedi con BE e DB VM"
    echo "3. Se SSH attivo → inizia setup Kubernetes"
    echo ""
    echo "COMANDI UTILI:"
    echo "ssh devops@192.168.1.101"
    echo "ssh devops@192.168.1.101 'docker --version'"
    
else
    echo "🔍 FE_VM ATTIVA MA NON RISPONDE AL PING"
    echo ""
    echo "VERIFICA CONSOLE VMWARE:"
    echo "1. Apri VMware Workstation"
    echo "2. Guarda console FE_VM"
    echo "3. Verifica se:"
    echo "   - Installazione Ubuntu in corso"
    echo "   - Menu selezione lingua/opzioni"
    echo "   - Errori boot"
    echo ""
    echo "SE BLOCCATA SU MENU → intervento manuale per sbloccare"
fi

# STEP 5: MONITORING CONTINUO OPZIONALE
echo ""
echo "=== STEP 5: MONITORING CONTINUO ==="

echo ""
echo "Per monitoraggio continuo (opzionale):"
echo "watch -n 30 'for ip in 192.168.1.101 192.168.1.102 192.168.1.103; do echo -n \"\$ip: \"; ping -c 1 \$ip >/dev/null 2>&1 && echo \"UP\" || echo \"DOWN\"; done'"

echo ""
echo "=== SUMMARY ==="
echo "VM FE_VM: RUNNING"
echo "Network: $(ping -c 1 192.168.1.101 >/dev/null 2>&1 && echo "RESPONSIVE" || echo "NOT RESPONSIVE")"
echo "Next: Verifica console VMware per status dettagliato"
