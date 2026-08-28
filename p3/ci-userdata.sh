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
ssh:
  emit_keys_to_console: false
package_update: true
package_upgrade: false
packages:
- tree
- docker.io
- curl
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
  - groupmod -g "$(id --group)" ${USER:?}
  - usermod -u "$(id --user)" ${USER:?}
  - chown ${USER:?}:${USER:?} /mnt/${PROJECT_NAME:?}
  - systemctl enable docker
  - systemctl start docker
  - curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
  - curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  - install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  - rm kubectl
  - usermod -aG docker ${USER}
final_message: Wubba Lubba dub-dub!
EOF
