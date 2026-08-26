#!/bin/bash

PROJECT_NAME="inception-of-things"
PROJECT_DIR="${HOME:?}/goinfre/${PROJECT_NAME:?}"

VM_NAME="${PROJECT_NAME:?}"
VM_IMG="$PROJECT_DIR/$VM_NAME.qcow2"

# APT_CACHE_IMG="$PROJECT_DIR/apt-cache.qcow2"
SSH_DIR="$PWD/.ssh"

export VIRSH_DEFAULT_CONNECT_URI="qemu:///session"
export LIBVIRT_DEFAULT_URI="qemu:///session"

vm__get_ami() {
	# Download Automated Machine Image (AMI) if missing.
	## local AMI_URL="https://cloud-images.ubuntu.com/resolute/current/resolute-server-cloudimg-amd64.img";
	local AMI_URL="https://cloud-images.ubuntu.com/minimal/releases/resolute/release/ubuntu-26.04-minimal-cloudimg-amd64v3.img";
	local AMI_VARIANT="$(basename $AMI_URL)";
	local AMI_PATH="${PROJECT_DIR:?}";
	local AMI_IMG="$AMI_PATH/$AMI_VARIANT";
	
	if ! test -f "$AMI_PATH/$AMI_VARIANT"; then
		wget \
			--continue \
			--directory-prefix="$AMI_PATH" \
			"$AMI_URL"
	fi
	printf "%s" "$AMI_IMG";
}

vm__keyname() {
	# Generate base64 string.
	local KEYNAME=$(printf "%s--%s" "${1:?}" "${2:?}" | basenc --base64);
	
	printf "%s" "$KEYNAME";
}

vm__keygen() {
	# Generate ssh key.
	local DOMAIN=${1:-"$VM_NAME"};
	local USER=${2:-"$USER"};
	local KEY="${SSH_DIR:?}/$(vm__keyname $DOMAIN $USER)";
	
	if ! test -d "$(dirname $KEY)"; then
		mkdir -p "$(dirname $KEY)"
	fi
	if ! test -f "$KEY"; then
		ssh-keygen -t ed25519 -N "" -q -C "" -f "$KEY"
	fi
}

vm__cloudinit() {
	# Generate user-data and meta-data.
	local DOMAIN=${1:-"$VM_NAME"};
	local USER=${2:-"$USER"};
	local KEY="${SSH_DIR:?}/$(vm__keyname $DOMAIN $USER)";
	local CI_USERDATA="${PROJECT_DIR}/user-data.yaml";
	local VM_DIR="$(dirname ${CI_USERDATA:?})";
	
	test -d "${VM_DIR}" || mkdir -v "${VM_DIR}";
	source "./ci-userdata.sh";
	if debug; then
		cloud-init schema --config-file "${CI_USERDATA:?}";
	fi
}

vm__hostfwd() {
	# NAT port forward.
	local DOMAIN=${1:-"$VM_NAME"};
	local NAT_PORT="${2:-"2222"}";
	local GUEST_PORT="${3:-"22"}";
	local CURRENT_USERNET=$(virsh qemu-monitor-command --hmp --domain $DOMAIN --cmd info usernet | grep HOST_FORWARD);
	local CURRENT_NAT_PORT=$(echo "$CURRENT_USERNET" | tr '[:blank:]' ' ' | tr -s ' ' | cut -d ' ' -f 5);
	local CURRENT_GUEST_PORT=$(echo "$CURRENT_USERNET" | tr '[:blank:]' ' ' | tr -s ' ' | cut -d ' ' -f 7);
	
	test ${CURRENT_NAT_PORT:-0} -eq $NAT_PORT && test ${CURRENT_GUEST_PORT:-0} -eq $GUEST_PORT && return;
	virsh qemu-monitor-command $DOMAIN \
		--hmp \
		--cmd "hostfwd_add ::${NAT_PORT}-:${GUEST_PORT}";
}

vm__clone_ami() {
	local AMI="${1:-"$(vm__get_ami)"}";
	local DEST="${2:?}"
	local SIZE="${3:?}";

	qemu-img create -f qcow2 -F qcow2 -b "$AMI" "$DEST" "$SIZE";
}

vm__domain_isdefined() {
	local DOMAIN=${1:-"$VM_NAME"};

	virsh dominfo $VM_NAME || false;
}

vm_create() {
	# Get AMI, provision, configure and start the VM via virt-install.
	local DOMAIN=${1:-"$VM_NAME"};
	local VM_VCPUS="4";
	local VM_RAM="4096";
	
	vm__domain_isdefined $VM_NAME 2>/dev/null && exit;
	vm__clone_ami "$(vm__get_ami)" "$VM_IMG" "32G";
	vm__keygen "$DOMAIN";
	vm__cloudinit;
	virt-install \
		--name "$VM_NAME" \
		--memory "$VM_RAM" \
		--memorybacking "access.mode=shared,source.type=memfd" \
		--vcpus "$VM_VCPUS,sockets=1,cores=$VM_VCPUS,threads=1" \
		--cpu "host-passthrough,cache.mode=passthrough" \
		--disk "path=$VM_IMG,bus=virtio,cache=none,io=native,discard=unmap" \
		--disk "none" \
		--filesystem "$(pwd),shared9p,mode=mapped" \
		--cloud-init "user-data=$PROJECT_DIR/user-data.yaml" \
		--osinfo "ubuntu-lts-latest" \
		--boot "uefi" \
		--tpm "none" \
		--import \
		--graphics "none" \
		--controller "type=pci,model=pcie-root" \
		--controller "type=usb,model=none" \
		--noautoconsole;
	vm__hostfwd "$VM_NAME" "2222" "22";
}

vm_delete() {
	local DOMAIN=${1:-"$VM_NAME"};

	vm__domain_isdefined $VM_NAME || exit;
	virsh destroy $DOMAIN;
	virsh undefine $DOMAIN --nvram;
	if test -f "$VM_IMG"; then
		rm -v "$VM_IMG"
	fi
}

vm_ssh() {
	local DOMAIN=${1:-"$VM_NAME"};
	local USER=${2:-"$USER"};
	local KEY="${SSH_DIR:?}/$(vm__keyname $DOMAIN $USER)";
	local NAT_IP="$(virsh net-dumpxml default | sed -nE "s/.*<ip address='([^']+)'.*/\1/p")";
	local NAT_PORT="2222";

	vm__domain_isdefined $VM_NAME || exit;
	vm__hostfwd "$VM_NAME" "2222" "22";
	ssh -i "$KEY" -p ${NAT_PORT:-"22"} \
		-o StrictHostKeyChecking=no \
		-o UserKnownHostsFile=/dev/null \
		${USER}@${NAT_IP:-"localhost"};
}

vm_console() {
	local DOMAIN=${1:-"$VM_NAME"};

	vm__domain_isdefined $VM_NAME || exit;
	virsh console $DOMAIN;
}

vm_usage() {
	printf "Usage: %s [OPTIONS]... [VM_NAME]\n" "$0" >&2
	printf "COMMANDS:\n" >&2
	printf "  %s: %s\n" "create" "..." >&2
	printf "  %s: %s\n" "ssh" "..." >&2
	printf "  %s: %s\n" "console" "..." >&2
	printf "  %s: %s\n" "delete" "..." >&2
}

debug() {
	if test -z "${DEBUG}"
	then
		false;
	else
		true;
	fi
}

#### main

if debug; then
	set -x;
fi

if test $# -eq 0; then
	vm_usage;
	exit 1;
fi

case "$1" in
	'create')
		shift
		vm_create;
		;;
	'delete')
		shift
		vm_delete;
		;;
	'ssh')
		shift
		vm_ssh;
		;;
	'console')
		shift
		vm_console;
		;;
	'ci')
		shift
		vm__cloudinit;
		;;
	'help'|'')
		vm_usage;
		;;
	*)
		virsh $@;
		;;
esac
