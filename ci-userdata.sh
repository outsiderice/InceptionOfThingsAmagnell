#!/bin/sh

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
  sources:
    hashicorp:
      keyid: 798A EC65 4E5C 1542 8C8E  42EE AA16 FCBC A621 E701
      source: 'deb [arch=$(dpkg --print-architecture) signed-by=\$KEY_FILE] https://apt.releases.hashicorp.com \$RELEASE main'
package_update: true
package_upgrade: false
packages:
- bridge-utils
- qemu-system-x86
- qemu-utils
- libvirt-daemon-system
- libvirt-clients
- libvirt-dev
- nfs-kernel-server
- build-essential
- pkgconf
- vagrant
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
