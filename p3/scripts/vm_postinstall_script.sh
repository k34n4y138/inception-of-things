#!/bin/bash
chroot /target apt-get -y install openssh-server curl ca-certificates gnupg git
chroot /target systemctl enable ssh

chroot /target bash -c '
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian bookworm stable" > /etc/apt/sources.list.d/docker.list
  apt-get update
  apt-get -y install docker-ce docker-ce-cli containerd.io
  systemctl enable docker
  usermod -aG docker debian
  export PATH=$PATH:/usr/local/bin
  curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
'