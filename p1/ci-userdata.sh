#!/bin/sh

local VAGRANT_KEY=

# user-data.yaml
cat <<EOF >"${CI_USERDATA:?}"
#cloud-config
users:
  - name: ${USER:?}
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: true
    ssh_authorized_keys:
      - $(cat "${KEY:?}.pub")
  - name: ${USER:?}dev
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    plain_text_passwd: "root"
ssh:
  emit_keys_to_console: false
apt:
  conf: |
    APT::Install-Recommends "false";
    APT::Install-Suggests "false";
package_update: true
package_upgrade: false
packages:
  - wget
  - gpg
  - libvirt-dev
  - ruby-libvirt
  - libxml2-dev
  - libxslt-dev
  - zlib1g-dev
  - gcc
  - make
  - bridge-utils
  - qemu-system-x86
  - qemu-utils
  - libvirt-daemon-system
  - libvirt-clients
  - libvirt-dev
  - nfs-kernel-server
  - build-essential
  - pkgconf
allow_public_ssh_keys: true
disable_root: true
disable_root_opts: no-port-forwarding,no-agent-forwarding,no-X11-forwarding
ssh_deletekeys: true
ssh_quiet_keygen: true
mounts:
  - ["shared9p", "/mnt/${PROJECT_NAME:?}", "9p", "trans=virtio,version=9p2000.L,nofail,x-mount.mkdir", "0", "0"]
bootcmd:
  - printf "%s\n%s" "[Unit]" "After=cloud-init.target" | sudo systemctl edit sshd.service --stdin
  - systemctl daemon-reload
runcmd:
  - wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
  - echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
  - apt-get update
  - apt-get install -y vagrant
  - vagrant plugin install vagrant-libvirt
  - echo "export VAGRANT_DEFAULT_PROVIDER=libvirt" >> /home/ubuntu/.bashrc

  - [ groupmod, -g, "$(id --group)", ${USER:?} ]
  - [ usermod, -u, "$(id --user)", ${USER:?} ]
  - chown ${USER:?}:${USER:?} /mnt/${PROJECT_NAME:?}
  - usermod -aG libvirt,kvm ${USER:?}
  - vagrant plugin install vagrant-libvirt
  - virsh net-destroy default
  - virsh net-undefine default
  - sed --in-place 's/192\.168/10\.0/g' /usr/share/libvirt/networks/default.xml
  - virsh net-define /usr/share/libvirt/networks/default.xml
  - virsh net-start default
  - needrestart -r a
final_message: Wubba Lubba dub-dub!
EOF
