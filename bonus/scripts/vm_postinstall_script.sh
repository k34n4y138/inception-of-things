#!/bin/bash
chroot /target apt-get -y install openssh-server curl ca-certificates gnupg git kubectl
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
  SSH_PUBKEY="{{SSH_PUBKEY_PLACEHOLDER}}"
  if [[ -n "$SSH_PUBKEY" ]]; then
      mkdir -p /home/debian/.ssh
      echo $SSH_PUBKEY >> /home/debian/.ssh/authorized_keys
      chown -R debian:debian /home/debian/.ssh
      chmod 700 /home/debian/.ssh
      chmod 600 /home/debian/.ssh/authorized_keys
  fi
'