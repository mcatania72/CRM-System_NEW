#cloud-config
autoinstall:
  version: 1
  
  # Locale and keyboard
  locale: en_US.UTF-8
  keyboard:
    layout: us
    variant: ''
  
  # Network configuration
  network:
    ethernets:
      ens33:
        dhcp4: false
        addresses:
          - ${ip_address}/24
        gateway4: ${gateway}
        nameservers:
          addresses: ${jsonencode(dns_servers)}
    version: 2
  
  # Storage configuration
  storage:
    layout:
      name: direct
    swap:
      size: 0
  
  # User configuration
  identity:
    hostname: ${hostname}
    username: ${username}
    password: '$6$rounds=4096$saltsalt$h1oqbgdlj9UZMPe2kG4AxhTLo8TyS5MdVkXRZG31.T5CZlVm/Kf8F3nOSv8x8h9v8h9v8h9v8h9v8h9v8h'  # devops123
    realname: 'DevOps User'
  
  # SSH configuration  
  ssh:
    install-server: true
    allow-pw: true
    authorized-keys: []
  
  # Package installation
  packages:
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
  
  # Post-installation commands
  late-commands:
    - echo '${username} ALL=(ALL) NOPASSWD:ALL' > /target/etc/sudoers.d/${username}
    - chmod 440 /target/etc/sudoers.d/${username}
    - curtin in-target --target=/target -- systemctl enable ssh
    - curtin in-target --target=/target -- systemctl start ssh
    
    # Docker installation
    - curtin in-target --target=/target -- curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    - curtin in-target --target=/target -- echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    - curtin in-target --target=/target -- apt-get update
    - curtin in-target --target=/target -- apt-get install -y docker-ce docker-ce-cli containerd.io
    - curtin in-target --target=/target -- usermod -aG docker ${username}
    - curtin in-target --target=/target -- systemctl enable docker
    
    # Kubernetes tools installation  
    - curtin in-target --target=/target -- curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/kubernetes-archive-keyring.gpg
    - curtin in-target --target=/target -- echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list
    - curtin in-target --target=/target -- apt-get update
    - curtin in-target --target=/target -- apt-get install -y kubelet kubeadm kubectl
    - curtin in-target --target=/target -- apt-mark hold kubelet kubeadm kubectl
    
    # System configuration
    - curtin in-target --target=/target -- swapoff -a
    - curtin in-target --target=/target -- sed -i '/swap/d' /etc/fstab
    - curtin in-target --target=/target -- modprobe br_netfilter
    - curtin in-target --target=/target -- echo 'br_netfilter' >> /etc/modules-load.d/k8s.conf
    - curtin in-target --target=/target -- echo 'net.bridge.bridge-nf-call-ip6tables = 1' >> /etc/sysctl.d/k8s.conf
    - curtin in-target --target=/target -- echo 'net.bridge.bridge-nf-call-iptables = 1' >> /etc/sysctl.d/k8s.conf
    - curtin in-target --target=/target -- echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.d/k8s.conf
    
  # Automatic reboot after installation
  shutdown: reboot

# =============================================================================
# VM ROLE SPECIFIC CONFIGURATION
# =============================================================================
%{ if vm_role == "master" }
# Kubernetes Master Node Configuration
write_files:
  - path: /etc/systemd/system/k8s-init.service
    content: |
      [Unit]
      Description=Initialize Kubernetes Master
      After=docker.service
      Requires=docker.service
      
      [Service]
      Type=oneshot
      ExecStart=/usr/local/bin/init-k8s-master.sh
      RemainAfterExit=true
      
      [Install]
      WantedBy=multi-user.target
    permissions: '0644'
    
  - path: /usr/local/bin/init-k8s-master.sh
    content: |
      #!/bin/bash
      # Wait for system to be ready
      sleep 60
      
      # Initialize Kubernetes cluster
      kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=${ip_address}
      
      # Setup kubectl for ${username}
      mkdir -p /home/${username}/.kube
      cp -i /etc/kubernetes/admin.conf /home/${username}/.kube/config
      chown ${username}:${username} /home/${username}/.kube/config
      
      # Install Flannel CNI
      sudo -u ${username} kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
      
      # Generate join command for workers
      kubeadm token create --print-join-command > /home/${username}/k8s-join-command
      chown ${username}:${username} /home/${username}/k8s-join-command
    permissions: '0755'

runcmd:
  - systemctl enable k8s-init.service
  - systemctl start k8s-init.service
%{ endif }

%{ if vm_role == "worker" }
# Kubernetes Worker Node Configuration  
write_files:
  - path: /etc/systemd/system/k8s-worker.service
    content: |
      [Unit]
      Description=Join Kubernetes Cluster as Worker
      After=docker.service
      Requires=docker.service
      
      [Service]
      Type=oneshot
      ExecStart=/usr/local/bin/join-k8s-cluster.sh
      RemainAfterExit=true
      
      [Install]
      WantedBy=multi-user.target
    permissions: '0644'
    
  - path: /usr/local/bin/join-k8s-cluster.sh  
    content: |
      #!/bin/bash
      # Wait for master to be ready
      sleep 120
      
      # Wait for join command from master
      while [ ! -f /tmp/k8s-join-command ]; do
        echo "Waiting for join command from master..."
        sleep 10
      done
      
      # Join cluster
      bash /tmp/k8s-join-command
    permissions: '0755'

runcmd:
  - systemctl enable k8s-worker.service
%{ endif }

# =============================================================================
# FINAL SYSTEM MESSAGES
# =============================================================================
final_message: |
  ====================================
  🎉 ${hostname} READY!
  ====================================
  
  VM Role: ${vm_role}
  IP Address: ${ip_address}
  Username: ${username}
  
  SSH Access: ssh ${username}@${ip_address}
  
  Services configured: ${join(", ", services)}
  
  Ready for Kubernetes cluster setup!
  ====================================
