#cloud-config
autoinstall:
  version: 1
  
  # Locale and keyboard
  locale: en_US.UTF-8
  keyboard:
    layout: us
    variant: ''
  
  # Network configuration with static IP
  network:
    version: 2
    ethernets:
      ens33:
        dhcp4: false
        addresses:
          - ${ip_address}/24
        gateway4: ${gateway}
        nameservers:
          addresses: ${jsonencode(dns_servers)}
  
  # Storage configuration
  storage:
    layout:
      name: lvm
    swap:
      size: 0
  
  # User configuration
  identity:
    hostname: ${hostname}
    username: ${username}
    password: '$6$rounds=4096$saltsalt$h1oqbgdlj9UZMPe2kG4AxhTLo8TyS5MdVkXRZG31.T5CZlVm/Kf8F3nOSv8x8h9v8h9v8h9v8h9v8h9v8h'  # ${password}
    realname: 'DevOps User'
  
  # SSH configuration  
  ssh:
    install-server: true
    allow-pw: true
    authorized-keys: []
  
  # Package installation
  packages:
    - openssh-server
    - curl
    - wget
    - git
    - vim
    - htop
    - net-tools
    - software-properties-common
    - apt-transport-https
    - ca-certificates
    - gnupg
    - lsb-release
    - docker.io
  
  # Post-installation commands
  late-commands:
    # User configuration
    - echo '${username} ALL=(ALL) NOPASSWD:ALL' > /target/etc/sudoers.d/${username}
    - chmod 440 /target/etc/sudoers.d/${username}
    - curtin in-target --target=/target -- systemctl enable ssh
    - curtin in-target --target=/target -- systemctl start ssh
    
    # Docker setup
    - curtin in-target --target=/target -- systemctl enable docker
    - curtin in-target --target=/target -- systemctl start docker
    - curtin in-target --target=/target -- usermod -aG docker ${username}
    
    # System optimization for Kubernetes
    - curtin in-target --target=/target -- swapoff -a
    - curtin in-target --target=/target -- sed -i '/swap/d' /etc/fstab
    - curtin in-target --target=/target -- modprobe br_netfilter
    - curtin in-target --target=/target -- echo 'br_netfilter' >> /etc/modules-load.d/k8s.conf
    - curtin in-target --target=/target -- echo 'net.bridge.bridge-nf-call-ip6tables = 1' >> /etc/sysctl.d/k8s.conf
    - curtin in-target --target=/target -- echo 'net.bridge.bridge-nf-call-iptables = 1' >> /etc/sysctl.d/k8s.conf
    - curtin in-target --target=/target -- echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.d/k8s.conf
    - curtin in-target --target=/target -- sysctl --system
    
    # Create completion marker
    - curtin in-target --target=/target -- touch /home/${username}/autoinstall-complete

# Automatic reboot after installation
shutdown: reboot

# =============================================================================
# VM ROLE SPECIFIC CONFIGURATION
# =============================================================================
%{ if vm_role == "master" }
# Additional packages for Kubernetes master
packages:
  - kubeadm
  - kubelet  
  - kubectl

late-commands:
  # Kubernetes master preparation
  - curtin in-target --target=/target -- systemctl enable kubelet
%{ endif }

%{ if vm_role == "worker" }
# Additional setup for worker nodes
late-commands:
  # Worker node preparation
  - curtin in-target --target=/target -- echo "Worker node ${hostname} ready for cluster join" > /home/${username}/worker-ready
%{ endif }

# =============================================================================
# FINAL SYSTEM MESSAGES
# =============================================================================
final_message: |
  ====================================
  🎉 ${hostname} INSTALLATION COMPLETE!
  ====================================
  
  VM Role: ${vm_role}
  IP Address: ${ip_address}
  Username: ${username}
  
  SSH Access: ssh ${username}@${ip_address}
  
  Services: ${join(", ", services)}
  
  Ubuntu Server with Docker installed!
  Ready for Kubernetes cluster setup!
  ====================================
