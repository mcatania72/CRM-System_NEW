# =============================================================================
# TERRAFORM MAIN CONFIGURATION - FASE 7 (FIXED)
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
  description = "Path to Ubuntu 22.04 ISO file"
  type        = string
  default     = "/home/devops/images/ubuntu-22.04.3-live-server-amd64.iso"
}

variable "vm_credentials" {
  description = "VM login credentials"
  type = object({
    username = string
    password = string
  })
  default = {
    username = "devops"
    password = "devops123"
  }
  sensitive = true
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
      services    = ["k8s-master", "frontend", "ingress-controller"]
    }
    "BE" = {
      name        = "${var.vm_base_name}_BE_VM"
      ip_address  = "192.168.1.102"
      role        = "worker"
      description = "Kubernetes Worker + Backend"
      services    = ["k8s-worker", "backend", "api-gateway"]
    }
    "DB" = {
      name        = "${var.vm_base_name}_DB_VM"
      ip_address  = "192.168.1.103"
      role        = "worker"
      description = "Kubernetes Worker + Database"
      services    = ["k8s-worker", "database", "storage", "backup"]
    }
  }
  
  vm_common = {
    memory_mb = var.vm_specs.memory_gb * 1024
    num_cpus  = var.vm_specs.cpu_cores
    disk_size = var.vm_specs.disk_gb * 1024
  }
}

# =============================================================================
# VM CREATION SCRIPTS
# =============================================================================

resource "local_file" "cloud_init_user_data" {
  for_each = local.vms
  
  filename = "${path.module}/cloud-init-${each.key}.yml"
  content = templatefile("${path.module}/templates/cloud-init.yml.tpl", {
    hostname     = each.value.name
    username     = var.vm_credentials.username
    password     = var.vm_credentials.password
    ip_address   = each.value.ip_address
    gateway      = var.vm_network.gateway
    dns_servers  = var.vm_network.dns
    vm_role      = each.value.role
    services     = each.value.services
  })
}

resource "local_file" "network_config" {
  for_each = local.vms
  
  filename = "${path.module}/network-config-${each.key}.yml"
  content = templatefile("${path.module}/templates/network-config.yml.tpl", {
    ip_address = each.value.ip_address
    gateway    = var.vm_network.gateway
    dns        = var.vm_network.dns
  })
}

resource "local_file" "vm_creation_script" {
  for_each = local.vms
  
  filename = "${path.module}/create-vm-${each.key}.sh"
  content = templatefile("${path.module}/templates/create-vm.sh.tpl", {
    vm_name                  = each.value.name
    vm_description           = each.value.description
    memory_mb                = local.vm_common.memory_mb
    num_cpus                 = local.vm_common.num_cpus
    disk_size_mb             = local.vm_common.disk_size
    ip_address               = each.value.ip_address
    vm_role                  = each.value.role
    vm_credentials_username  = var.vm_credentials.username
    gateway                  = var.vm_network.gateway
    dns_servers              = var.vm_network.dns
    cloud_init_file          = "cloud-init-${each.key}.yml"
    network_config           = "network-config-${each.key}.yml"
  })
  
  provisioner "local-exec" {
    command = "chmod +x ${self.filename}"
  }
}

resource "local_file" "k8s_setup_script" {
  for_each = local.vms
  
  filename = "${path.module}/setup-k8s-${each.key}.sh"
  content = templatefile("${path.module}/templates/setup-k8s.sh.tpl", {
    vm_name    = each.value.name
    vm_role    = each.value.role
    ip_address = each.value.ip_address
    is_master  = each.value.role == "master"
  })
  
  provisioner "local-exec" {
    command = "chmod +x ${self.filename}"
  }
}

# =============================================================================
# VM DEPLOYMENT EXECUTION (FIXED)
# =============================================================================

resource "null_resource" "create_vms" {
  for_each = local.vms
  
  depends_on = [
    local_file.vm_creation_script,
    local_file.cloud_init_user_data,
    local_file.network_config
  ]
  
  provisioner "local-exec" {
    command     = "./create-vm-${each.key}.sh"
    working_dir = path.module
  }
  
  # FIXED: Use self reference for destroy
  provisioner "local-exec" {
    when        = destroy
    command     = "vmrun stop '${self.triggers.vm_path}' 2>/dev/null || true; vmrun deleteVM '${self.triggers.vm_path}' 2>/dev/null || true"
    working_dir = path.module
    on_failure  = continue
  }
  
  # Store VM path for destroy
  triggers = {
    vm_path = "${each.value.name}/${each.value.name}.vmx"
  }
}

resource "null_resource" "wait_for_vms" {
  for_each = local.vms
  
  depends_on = [null_resource.create_vms]
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for VM ${each.value.name} to be ready..."
      for i in {1..60}; do
        if ping -c 1 ${each.value.ip_address} >/dev/null 2>&1; then
          echo "VM ${each.value.name} is responding to ping"
          break
        fi
        echo "Attempt $i/60: VM not ready yet, waiting..."
        sleep 10
      done
      
      for i in {1..30}; do
        if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no ${var.vm_credentials.username}@${each.value.ip_address} 'echo "SSH ready"' >/dev/null 2>&1; then
          echo "SSH ready on ${each.value.name}"
          break
        fi
        echo "SSH attempt $i/30 failed, retrying..."
        sleep 10
      done
    EOT
  }
}

resource "null_resource" "setup_kubernetes" {
  for_each = local.vms
  
  depends_on = [null_resource.wait_for_vms]
  
  provisioner "local-exec" {
    command     = "./setup-k8s-${each.key}.sh"
    working_dir = path.module
  }
}

resource "null_resource" "k8s_master_init" {
  depends_on = [null_resource.setup_kubernetes]
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "Initializing Kubernetes master..."
      ssh -o StrictHostKeyChecking=no ${var.vm_credentials.username}@192.168.1.101 '
        sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=192.168.1.101
        mkdir -p $HOME/.kube
        sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
        sudo chown $(id -u):$(id -g) $HOME/.kube/config
        
        kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
        kubeadm token create --print-join-command > /tmp/k8s-join-command
      '
      
      scp -o StrictHostKeyChecking=no ${var.vm_credentials.username}@192.168.1.101:/tmp/k8s-join-command ./k8s-join-command
    EOT
  }
}

resource "null_resource" "k8s_workers_join" {
  for_each = { for k, v in local.vms : k => v if v.role == "worker" }
  
  depends_on = [null_resource.k8s_master_init]
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "Joining worker ${each.value.name} to cluster..."
      JOIN_COMMAND=$(cat ./k8s-join-command)
      ssh -o StrictHostKeyChecking=no ${var.vm_credentials.username}@${each.value.ip_address} "
        sudo $JOIN_COMMAND
      "
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
      services    = v.services
    }
  }
}

output "cluster_info" {
  description = "Kubernetes cluster information"
  value = {
    master_ip      = "192.168.1.101"
    worker_ips     = ["192.168.1.102", "192.168.1.103"]
    cluster_cidr   = "10.244.0.0/16"
    service_cidr   = "10.96.0.0/12"
  }
}

output "access_info" {
  description = "Access information for the infrastructure"
  value = {
    ssh_command = "ssh ${var.vm_credentials.username}@<VM_IP>"
    kubectl_config = "scp ${var.vm_credentials.username}@192.168.1.101:~/.kube/config ~/.kube/config-crm-cluster"
    dashboard_url = "https://192.168.1.101:6443"
  }
  sensitive = true
}

output "next_steps" {
  description = "Next steps for deployment"
  value = [
    "1. Verify cluster: kubectl get nodes",
    "2. Test infrastructure: ./test_infrastructure.sh",
    "3. Deploy application: ./deploy_application.sh"
  ]
}
