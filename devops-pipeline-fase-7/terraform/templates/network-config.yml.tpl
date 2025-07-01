version: 2
ethernets:
  ens33:
    dhcp4: false
    addresses:
      - ${ip_address}/24
    gateway4: ${gateway}
    nameservers:
      addresses: [${join(", ", formatlist("\"%s\"", dns))}]
