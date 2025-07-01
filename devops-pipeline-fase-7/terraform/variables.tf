# =============================================================================
# TERRAFORM VARIABLES - FASE 7
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
  default     = "/home/devops/Downloads/ubuntu-22.04.3-desktop-amd64.iso"
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
