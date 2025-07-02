# =============================================================================
# TERRAFORM MAIN CONFIGURATION - UBUNTU AUTOINSTALL APPROACH
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
# STEP 1: CREATE AUTOINSTALL ISO FOR EACH VM
# =============================================================================

resource "local_file" "autoinstall_user_data" {
  for_each = local.vms
  
  filename = "${path.module}/autoinstall-${each.key}/user-data"
  content = templatefile("${path.module}/templates/autoinstall-user-data.yml.tpl", {
    hostname     = each.value.name
    username     = var.vm_credentials.username
    password     = var.vm_credentials.password
    ip_address   = each.value.ip_address
    gateway      = var.vm_network.gateway
    dns_servers  = var.vm_network.dns
    vm_role      = each.value.role
    services     = each.value.services
  })
  
  provisioner "local-exec" {
    command = "mkdir -p ${path.module}/autoinstall-${each.key}"
  }
}

resource "local_file" "autoinstall_meta_data" {
  for_each = local.vms
  
  filename = "${path.module}/autoinstall-${each.key}/meta-data"
  content = templatefile("${path.module}/templates/autoinstall-meta-data.yml.tpl", {
    hostname     = each.value.name
    instance_id  = "${each.value.name}-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  })
}

resource "null_resource" "create_autoinstall_iso" {
  for_each = local.vms
  
  depends_on = [
    local_file.autoinstall_user_data,
    local_file.autoinstall_meta_data
  ]
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "Creating autoinstall ISO for ${each.value.name}..."
      
      # Create temp directory for ISO creation
      TEMP_DIR="/tmp/autoinstall-${each.key}-$$"
      mkdir -p "$TEMP_DIR/source-files"
      
      # Extract original ISO
      echo "Extracting Ubuntu ISO..."
      7z -y x "${var.ubuntu_iso_path}" -o"$TEMP_DIR/source-files" >/dev/null
      
      # Create autoinstall directory
      mkdir -p "$TEMP_DIR/source-files/server"
      
      # Copy autoinstall files
      cp "${path.module}/autoinstall-${each.key}/user-data" "$TEMP_DIR/source-files/server/"
      cp "${path.module}/autoinstall-${each.key}/meta-data" "$TEMP_DIR/source-files/server/"
      
      # Modify grub for autoinstall
      sed -i 's/timeout=30/timeout=5/' "$TEMP_DIR/source-files/boot/grub/grub.cfg"
      sed -i '0,/menuentry "Try or Install Ubuntu Server"/s//menuentry "Autoinstall ${each.value.name}" {\n\tset gfxpayload=keep\n\tlinux\t\/casper\/vmlinuz autoinstall ds=nocloud;s=\/cdrom\/server\/ ---\n\tinitrd\t\/casper\/initrd\n}\n\nmenuentry "Try or Install Ubuntu Server"/' "$TEMP_DIR/source-files/boot/grub/grub.cfg"
      
      # Create autoinstall ISO
      OUTPUT_ISO="${path.module}/${each.value.name}-autoinstall.iso"
      echo "Creating ISO: $OUTPUT_ISO"
      
      genisoimage -r -V "${each.value.name} Autoinstall" \
        -cache-inodes -J -joliet-long -l \
        -b boot/grub/i386-pc/eltorito.img \
        -c boot.catalog -no-emul-boot \
        -boot-load-size 4 -boot-info-table \
        -o "$OUTPUT_ISO" \
        "$TEMP_DIR/source-files" >/dev/null 2>&1
      
      # Cleanup
      rm -rf "$TEMP_DIR"
      
      echo "✅ Autoinstall ISO created: $OUTPUT_ISO"
    EOT
  }
}

# =============================================================================
# STEP 2: CREATE VM SCRIPTS
# =============================================================================

resource "local_file" "vm_creation_script" {
  for_each = local.vms
  
  depends_on = [null_resource.create_autoinstall_iso]
  
  filename = "${path.module}/create-vm-${each.key}.sh"
  content = templatefile("${path.module}/templates/create-vm-autoinstall.sh.tpl", {
    vm_name          = each.value.name
    vm_description   = each.value.description
    memory_mb        = local.vm_common.memory_mb
    num_cpus         = local.vm_common.num_cpus
    disk_size_mb     = local.vm_common.disk_size
    autoinstall_iso  = "./${each.value.name}-autoinstall.iso"
    ip_address       = each.value.ip_address
    vm_role          = each.value.role
    username         = var.vm_credentials.username
  })
  
  provisioner "local-exec" {
    command = "chmod +x ${self.filename}"
  }
}

# =============================================================================
# STEP 3: CREATE VMs
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
             ${var.vm_credentials.username}@${each.value.ip_address} 'echo "SSH ready"' >/dev/null 2>&1; then
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
# STEP 5: KUBERNETES SETUP
# =============================================================================

resource "null_resource" "k8s_master_init" {
  depends_on = [null_resource.wait_for_vms]
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "Initializing Kubernetes master on FE_VM..."
      ssh -o StrictHostKeyChecking=no ${var.vm_credentials.username}@192.168.1.101 '
        # Install Kubernetes tools
        curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
        echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
        sudo apt-get update
        sudo apt-get install -y kubelet kubeadm kubectl
        sudo apt-mark hold kubelet kubeadm kubectl
        
        # System preparation
        sudo swapoff -a
        sudo sed -i "/swap/d" /etc/fstab
        sudo modprobe br_netfilter
        echo "br_netfilter" | sudo tee /etc/modules-load.d/k8s.conf
        echo "net.bridge.bridge-nf-call-ip6tables = 1" | sudo tee -a /etc/sysctl.d/k8s.conf
        echo "net.bridge.bridge-nf-call-iptables = 1" | sudo tee -a /etc/sysctl.d/k8s.conf
        echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.d/k8s.conf
        sudo sysctl --system
        
        # Initialize cluster
        sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=192.168.1.101
        
        # Setup kubectl for user
        mkdir -p $HOME/.kube
        sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
        sudo chown $(id -u):$(id -g) $HOME/.kube/config
        
        # Install Flannel CNI
        kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
        
        # Generate join command
        kubeadm token create --print-join-command > /tmp/k8s-join-command
      '
      
      # Copy join command locally
      scp -o StrictHostKeyChecking=no ${var.vm_credentials.username}@192.168.1.101:/tmp/k8s-join-command ./k8s-join-command
    EOT
  }
}

resource "null_resource" "k8s_workers_join" {
  for_each = { for k, v in local.vms : k => v if v.role == "worker" }
  
  depends_on = [null_resource.k8s_master_init]
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "Setting up worker ${each.value.name} and joining cluster..."
      ssh -o StrictHostKeyChecking=no ${var.vm_credentials.username}@${each.value.ip_address} '
        # Install Kubernetes tools
        curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
        echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
        sudo apt-get update
        sudo apt-get install -y kubelet kubeadm kubectl
        sudo apt-mark hold kubelet kubeadm kubectl
        
        # System preparation
        sudo swapoff -a
        sudo sed -i "/swap/d" /etc/fstab
        sudo modprobe br_netfilter
        echo "br_netfilter" | sudo tee /etc/modules-load.d/k8s.conf
        echo "net.bridge.bridge-nf-call-ip6tables = 1" | sudo tee -a /etc/sysctl.d/k8s.conf
        echo "net.bridge.bridge-nf-call-iptables = 1" | sudo tee -a /etc/sysctl.d/k8s.conf
        echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.d/k8s.conf
        sudo sysctl --system
      '
      
      # Join cluster
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
    ssh_command = "ssh devops@<VM_IP>"
    kubectl_config = "scp devops@192.168.1.101:~/.kube/config ~/.kube/config-crm-cluster"
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
