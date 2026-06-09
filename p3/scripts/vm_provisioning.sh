#!/bin/bash
# Author: Zmoumen (Zakaria Moumen)
# Email: zmoumen@student.1337.ma
# Desc: Provisioning script around VBOX to spin up a virtual machine
set -e
# Check if VBox exists
if ! command -v vboxmanage &> /dev/null; then
        echo "Error: VirtualBox (vboxmanage) is not installed. Please install it to proceed."
        exit 1
fi

DEBIAN_ISO_LINK="https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-13.5.0-amd64-netinst.iso"

# Default VM configuration values
DEFAULT_VM_NAME="debian-vm"
DEFAULT_VM_CPUS=2
DEFAULT_VM_RAM=2048


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
            # Wait for the VM to fully power off
            while vboxmanage showvminfo "$VM_NAME" | grep -q "State:.*running"; do
                sleep 1
            done
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


vboxmanage modifyvm "$VM_NAME" --vram 64

echo "VM '$VM_NAME' initialized with $VM_CPUS CPU(s) and $VM_RAM MB RAM."

DISK_NAME="${VM_NAME}_disk.vdi"
DISK_PATH="$DOWNLOAD_PATH/$DISK_NAME"

# Check if disk already exists
if [[ -f "$DISK_PATH" ]]; then
    echo "Disk $DISK_PATH already exists. Skipping disk creation."
else
    # Create a 10G dynamic disk
    vboxmanage createmedium disk --filename "$DISK_PATH" --size 10240 --format VDI
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

vboxmanage unattended install "$VM_NAME" \
  --iso="$ISO_PATH" \
  --user="$USERNAME" \
  --password="$PASSWORD" \
  --full-user-name="$FULLNAME" \
  --install-additions \
  --start-vm=gui \
  --post-install-command="chroot /target apt-get -y install openssh-server && chroot /target systemctl enable ssh"


echo "Unattended installation started for VM '$VM_NAME'."
echo "go to advanced options and select autoinstall. cfg path is file:///cdrom/preseed.cfg"

sleep 10

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

# Ask user to press enter to continue
read -p "Press Enter to continue with the provisioning..."

# Attempt to SSH into the VM
USERNAME="debian"

while true; do
    ssh -o ConnectTimeout=5 "$USERNAME@localhost" -p 2222 "exit"
    if [ $? -eq 0 ]; then
        echo "Successfully connected to the VM."
        break
    else
        echo "SSH connection failed. The VM may not be ready yet."
        read -p "Press Enter to try again..."
    fi
done
