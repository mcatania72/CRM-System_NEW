# =============================================================================
# TERRAFORM MAIN CONFIGURATION - UBUNTU AUTOINSTALL V8 ZERO TOUCH
# =============================================================================

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.1"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.1"
    }
  }
}

# =============================================================================
# VARIABLES
# =============================================================================

variable "vm_base_name" {
  description = "Base name for VMs"
  type        = string
  default     = "SPESE"
}

variable "vm_network" {
  description = "Network configuration for VMs"
  type = object({
    subnet   = string
    gateway  = string
    dns      = list(string)
  })
  default = {
    subnet  = "192.168.1.0/24"
    gateway = "192.168.1.1"
    dns     = ["8.8.8.8", "8.8.4.4"]
  }
}

variable "vm_specs" {
  description = "VM specifications"
  type = object({
    memory_gb = number
    cpu_cores = number
    disk_gb   = number
  })
  default = {
    memory_gb = 4
    cpu_cores = 2
    disk_gb   = 25
  }
}

variable "ubuntu_iso_path" {
  description = "Path to Ubuntu 22.04 Server ISO file"
  type        = string
  default     = "/home/devops/images/ubuntu-22.04.3-live-server-amd64.iso"
}

variable "username" {
  description = "Username for VMs"
  type        = string
  default     = "devops"
}

variable "password" {
  description = "Password for VMs"
  type        = string
  default     = "devops"
  sensitive   = true
}

# =============================================================================
# LOCAL VALUES
# =============================================================================

locals {
  vms = {
    "FE" = {
      name        = "${var.vm_base_name}_FE_VM"
      ip_address  = "192.168.1.101"
      role        = "master"
      description = "Kubernetes Master + Frontend"
    }
    "BE" = {
      name        = "${var.vm_base_name}_BE_VM"
      ip_address  = "192.168.1.102"
      role        = "worker"
      description = "Kubernetes Worker + Backend"
    }
    "DB" = {
      name        = "${var.vm_base_name}_DB_VM"
      ip_address  = "192.168.1.103"
      role        = "worker"
      description = "Kubernetes Worker + Database"
    }
  }
  
  vm_common = {
    memory_mb = var.vm_specs.memory_gb * 1024
    num_cpus  = var.vm_specs.cpu_cores
    disk_size = var.vm_specs.disk_gb * 1024
  }
}

# =============================================================================
# STEP 1: CREATE AUTOINSTALL ISO FOR EACH VM
# =============================================================================

# Script per creare ISO autoinstall con hash dinamico
resource "local_file" "create_iso_script" {
  for_each = local.vms
  
  filename = "${path.module}/create-iso-${each.key}.sh"
  file_permission = "0755"
  
  content = templatefile("${path.module}/templates/create-autoinstall-iso.sh.tpl", {
    vm_name          = each.value.name
    ip_address       = each.value.ip_address
    vm_role          = each.value.role
    username         = var.username
    password         = var.password
    ubuntu_iso_path  = var.ubuntu_iso_path
  })
}

# Crea ISO autoinstall personalizzato per ogni VM
resource "null_resource" "create_autoinstall_iso" {
  for_each = local.vms

  triggers = {
    vm_name = each.value.name
  }

  provisioner "local-exec" {
    command = "${local_file.create_iso_script[each.key].filename}"
  }

  depends_on = [
    local_file.create_iso_script
  ]
}

# =============================================================================
# STEP 2: CREATE VM CREATION SCRIPTS
# =============================================================================

resource "local_file" "vm_creation_script" {
  for_each = local.vms
  
  filename = "${path.module}/create-vm-${each.key}.sh"
  file_permission = "0755"
  
  content = templatefile("${path.module}/templates/create-vm-autoinstall.sh.tpl", {
    vm_name         = each.value.name
    vm_description  = each.value.description
    memory_mb       = local.vm_common.memory_mb
    num_cpus        = local.vm_common.num_cpus
    disk_size_mb    = local.vm_common.disk_size
    autoinstall_iso = "./SPESE_${each.key}_VM-autoinstall.iso"
    ip_address      = each.value.ip_address
    vm_role         = each.value.role
    username        = var.username
  })
}

# =============================================================================
# STEP 3: CREATE VMS
# =============================================================================

resource "null_resource" "create_vms" {
  for_each = local.vms
  
  depends_on = [
    null_resource.create_autoinstall_iso,
    local_file.vm_creation_script
  ]
  
  triggers = {
    vm_name = each.value.name
  }
  
  provisioner "local-exec" {
    command     = "./create-vm-${each.key}.sh"
    working_dir = path.module
  }
  
  provisioner "local-exec" {
    when        = destroy
    command     = "vmrun stop '~/VMware_VMs/${self.triggers.vm_name}/${self.triggers.vm_name}.vmx' 2>/dev/null || true; vmrun deleteVM '~/VMware_VMs/${self.triggers.vm_name}/${self.triggers.vm_name}.vmx' 2>/dev/null || true"
    working_dir = path.module
    on_failure  = continue
  }
}

# =============================================================================
# STEP 4: WAIT FOR INSTALLATION COMPLETION
# =============================================================================

resource "null_resource" "wait_for_vms" {
  for_each = local.vms
  
  depends_on = [null_resource.create_vms]
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for VM ${each.value.name} installation to complete..."
      
      # Wait for SSH to be ready (indicates installation complete)
      TIMEOUT=1800  # 30 minutes
      ELAPSED=0
      INTERVAL=30
      
      while [ $ELAPSED -lt $TIMEOUT ]; do
        if ping -c 1 ${each.value.ip_address} >/dev/null 2>&1; then
          echo "VM ${each.value.name} responding to ping"
          
          if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
             ${var.username}@${each.value.ip_address} 'echo "SSH ready"' >/dev/null 2>&1; then
            echo "✅ ${each.value.name} installation completed and SSH ready!"
            break
          fi
        fi
        
        sleep $INTERVAL
        ELAPSED=$((ELAPSED + INTERVAL))
        echo "Installation progress: $((ELAPSED / 60)) minutes elapsed..."
      done
      
      if [ $ELAPSED -ge $TIMEOUT ]; then
        echo "❌ Installation timeout for ${each.value.name}"
        exit 1
      fi
    EOT
  }
}

# =============================================================================
# OUTPUTS
# =============================================================================

output "vm_details" {
  description = "Details of created VMs"
  value = {
    for k, v in local.vms : k => {
      name        = v.name
      ip_address  = v.ip_address
      role        = v.role
      description = v.description
      ssh_command = "ssh ${var.username}@${v.ip_address}"
    }
  }
}

output "access_info" {
  description = "Access information"
  value = {
    username = var.username
    password = "Use the password you set"
    note     = "VMs are ready for Kubernetes deployment"
  }
  sensitive = true
}

output "next_steps" {
  description = "Next steps for deployment"
  value = [
    "1. Verify VMs are accessible: ssh ${var.username}@<VM_IP>",
    "2. Deploy Kubernetes cluster",
    "3. Deploy CRM application"
  ]
}
