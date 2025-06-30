# 📁 SCRIPT OBSOLETI - FASE 6

Questa cartella contiene gli script utilizzati durante la fase di sviluppo e troubleshooting per risolvere il problema di accesso da host Windows alle porte NodePort di k3s.

## 🎯 PROBLEMA RISOLTO

**Problema**: Le porte NodePort 30002/30003 di k3s funzionavano solo da DEV_VM ma non da host Windows.

**Root Cause**: k3s usa iptables NAT che non funziona correttamente per il traffico esterno host→VM.

**Soluzione Finale**: Port-forward strutturale su porte originali 30002/30003 tramite `portforward-original-ports.sh`.

## 📋 SCRIPT TENTATI (OBSOLETI)

### 🚪 Egress Gateway (Fallito)
- `egress-gateway.sh` - Primo tentativo egress gateway
- `egress-gateway-fixed.sh` - Fix security context
- `egress-gateway-security-fix.sh` - Fix permessi container  
- `egress-gateway-original-ports.sh` - Dual-port gateway

**Problema**: Aggiungevano complessità senza risolvere il problema di base.

### 🔧 NodePort Fix (Fallito)
- `fix-nodeport-binding.sh` - Tentativo fix binding k3s
- `nodeport-safe.sh` - Restart sicuro k3s
- `analyze-network-binding.sh` - Analisi binding rete

**Problema**: k3s NodePort funzionava già correttamente, il problema era altrove.

### 🌐 Network Debug (Parzialmente Riuscito)
- `host-vm-network-debug.sh` - Debug network host-VM

**Stato**: Funzionava ma usava porte dinamiche. Logica integrata in `portforward-original-ports.sh`.

## ✅ SOLUZIONE FINALE

**Script Attivo**: `../portforward-original-ports.sh`

**Caratteristiche**:
- Port-forward diretto sulle porte originali 30002/30003
- Binding su 0.0.0.0 per accesso esterno
- Firewall automatico UFW
- Modalità manuale e systemd
- Cleanup intelligente

## 🗑️ MANTENIMENTO

Questi script sono mantenuti per:
- **Documentazione storica** del processo di troubleshooting
- **Riferimento tecnico** per problemi simili
- **Analisi** delle soluzioni tentate

**Non utilizzare in produzione** - usare sempre `portforward-original-ports.sh`.
