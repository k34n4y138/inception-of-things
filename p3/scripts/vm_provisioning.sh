#!/bin/bash
# Author: Zmoumen (Zakaria Moumen)
# Email: zmoumen@student.1337.ma
# Desc: Provisioning script around VBOX to spin up a virtual machine

set -eo pipefail

# Check if VBox exists
if ! command -v vboxmanage &> /dev/null; then
        echo "Error: VirtualBox (vboxmanage) is not installed. Please install it to proceed."
        exit 1
fi

DEBIAN_ISO_LINK="https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-13.5.0-amd64-netinst.iso"

# Default VM configuration values
DEFAULT_VM_NAME="debian-vm"
DEFAULT_VM_CPUS=4
DEFAULT_VM_RAM=4096 # 4GB in MB
DEFAULT_DISK_SIZE=52048 # 50GB in MB

# Set the download path
DOWNLOAD_PATH="/tmp"

# Set the file name and check if it already exists
FILE_NAME="${DEBIAN_ISO_LINK##*/}"
FILE_PATH="$DOWNLOAD_PATH/$FILE_NAME"

if [[ -f "$FILE_PATH" ]]; then
    echo "File $FILE_PATH already exists. Skipping download."
else
    # Start download
    echo "Downloading $FILE_NAME from $DEBIAN_ISO_LINK..."
    curl -L -o "$FILE_PATH" "$DEBIAN_ISO_LINK"
    echo "Download completed: $FILE_PATH"
fi

# Set VM configuration
VM_NAME="$DEFAULT_VM_NAME"
VM_CPUS="$DEFAULT_VM_CPUS"
VM_RAM="$DEFAULT_VM_RAM"

# Check if the VM name already exists
if vboxmanage showvminfo "$VM_NAME" &> /dev/null; then
    echo "Error: A VM with the name '$VM_NAME' already exists."
    read -p "Do you want to delete the existing VM? (y/n): " choice
    if [[ "$choice" == "y" ]]; then
        # Stop the VM if it is running
        if vboxmanage showvminfo "$VM_NAME" | grep -q "State:.*running"; then
            echo "Stopping the existing VM '$VM_NAME'..."
            vboxmanage controlvm "$VM_NAME" poweroff
            sleep 3
        fi
        vboxmanage unregistervm "$VM_NAME" --delete
        echo "Existing VM '$VM_NAME' has been deleted."
    else
        echo "exiting..."
        exit 1
    fi
fi
# Create the VM
vboxmanage createvm --name "$VM_NAME" --ostype "Debian_64"  --register

# Set CPU and RAM
vboxmanage modifyvm "$VM_NAME" --cpus "$VM_CPUS" --memory "$VM_RAM"

vboxmanage modifyvm "$VM_NAME" --nic1 nat
vboxmanage modifyvm "$VM_NAME" --natpf1 "guestssh,tcp,,2222,,22"
vboxmanage modifyvm "$VM_NAME" --natpf1 "argocd,tcp,,8067,,8067"

vboxmanage modifyvm "$VM_NAME" --vram 64

echo "VM '$VM_NAME' initialized with $VM_CPUS CPU(s) and $VM_RAM MB RAM."

DISK_NAME="${VM_NAME}_disk.vdi"
DISK_PATH="$DOWNLOAD_PATH/$DISK_NAME"

# Check if disk already exists
if [[ -f "$DISK_PATH" ]]; then
    echo "Disk $DISK_PATH already exists. Skipping disk creation."
else
    # Create a 10G dynamic disk
    vboxmanage createmedium disk --filename "$DISK_PATH" --size $DEFAULT_DISK_SIZE --format VDI
    echo "Disk created at $DISK_PATH."
fi

# Attach the disk to the VM
vboxmanage storagectl "$VM_NAME" --name "SATA Controller" --add sata --controller IntelAhci
vboxmanage storageattach "$VM_NAME" --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium "$DISK_PATH"

vboxmanage storageattach "$VM_NAME" --storagectl "SATA Controller" --port 1 --device 0 --type dvddrive --medium "$FILE_PATH"
vboxmanage modifyvm "$VM_NAME" --boot1 dvd --boot2 disk --boot3 none --boot4 none

# Start the VM
USERNAME="debian"
PASSWORD="debian"
FULLNAME="Debian User"
ISO_PATH="$FILE_PATH"
VM_NAME="$VM_NAME"
SSH_PUBKEY_FILE="$HOME/.ssh/inception-of-things.pub"
SSH_PRVKEY_FILE="$HOME/.ssh/inception-of-things"

SSH_KEY=""

if [[ -f "$SSH_PUBKEY_FILE" ]]; then
    echo "SSH public key found. It will be added to the VM's authorized_keys."
    SSH_KEY=$(cat "$SSH_PUBKEY_FILE")
else
    echo "No SSH public key found. The VM will be provisioned without an SSH key and you will need to provide password manually."
fi

POSTINSTALL_SCRIPT_CONTENT=$(< ./vm_postinstall_script.sh)


POSTINSTALL_SCRIPT_CONTENT=$(echo "$POSTINSTALL_SCRIPT_CONTENT" | sed "s|{{SSH_PUBKEY_PLACEHOLDER}}|$SSH_KEY|g")

POST_INSTALL_SCRIPT=$(printf '%s' "$POSTINSTALL_SCRIPT_CONTENT" | base64 -b 0)

vboxmanage unattended install "$VM_NAME" \
  --iso="$ISO_PATH" \
  --user="$USERNAME" \
  --password="$PASSWORD" \
  --full-user-name="$FULLNAME" \
  --install-additions \
  --start-vm=headless \
  --post-install-command="bash -c \"echo $POST_INSTALL_SCRIPT | base64 -d | bash\""
  

echo "Unattended installation started for VM '$VM_NAME'."

sleep 10

echo "Sending keystrokes to the VM to automate the installation process..."

VBoxManage controlvm "$VM_NAME" keyboardputstring "A" # advanced options
VBOXMANAGE controlvm "$VM_NAME" keyboardputscancode 1C
VBOXMANAGE controlvm "$VM_NAME" keyboardputscancode 9C

VBOXMANAGE controlvm "$VM_NAME" keyboardputstring "A" # autoinstall
VBOXMANAGE controlvm "$VM_NAME" keyboardputscancode 1C
VBOXMANAGE controlvm "$VM_NAME" keyboardputscancode 9C

sleep 60

VBOXMANAGE controlvm "$VM_NAME" keyboardputstring "file:///cdrom/preseed.cfg"
VBOXMANAGE controlvm "$VM_NAME" keyboardputscancode 1C
VBOXMANAGE controlvm "$VM_NAME" keyboardputscancode 9C

echo "waiting for the installation to complete. This may take a few minutes..."

# Attempt to SSH into the VM

SSH_OPTIONS="-p 2222 -o ConnectTimeout=50 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i $SSH_PRVKEY_FILE"


echo "Waiting for the VM to be ready for SSH connections..."
while true; do
    if ssh $SSH_OPTIONS "$USERNAME@localhost" "exit" 2>/dev/null; then
        echo "Machine has been provisioned successfully."
        break
    else
        sleep 1
    fi
done

SSH_HOSTS_FILE="$HOME/.ssh/hosts"
SSH_ROLE_NAME="debian-iot"
SSH_ROLE_HOSTNAME="localhost"
SSH_ROLE_PORT="2222"

if [[ -f "$SSH_HOSTS_FILE" ]] && grep -qE "^[[:space:]]*Host[[:space:]]+$SSH_ROLE_NAME([[:space:]]|$)" "$SSH_HOSTS_FILE"; then
    echo "SSH role '$SSH_ROLE_NAME' already exists in $SSH_HOSTS_FILE."
else
    echo "Creating SSH role '$SSH_ROLE_NAME' in $SSH_HOSTS_FILE..."
    mkdir -p "$(dirname "$SSH_HOSTS_FILE")"
    {
        echo "Host $SSH_ROLE_NAME"
        echo "    HostName $SSH_ROLE_HOSTNAME"
        echo "    User $USERNAME"
        echo "    Port $SSH_ROLE_PORT"
        if [[ -f "$SSH_PRVKEY_FILE" ]]; then
            echo "    IdentityFile $SSH_PRVKEY_FILE"
        fi
        if [[ -n "$SSH_KEY" ]]; then
            echo "    # SSH public key available for authorized_keys setup"
        fi
        echo
    } >> "$SSH_HOSTS_FILE"
fi
