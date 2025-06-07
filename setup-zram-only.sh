#!/bin/bash
set -e

echo "Disabling all swap devices..."
swapoff -a

echo "Commenting out swap entries in /etc/fstab..."
sudo sed -i.bak '/swap/s/^\([^#].*\)$/#\1/' /etc/fstab

echo "Removing zram module (to clean up existing devices)..."
modprobe -r zram || true

echo "Loading zram kernel module..."
modprobe zram

echo "Setting zram0 disk size to 32G..."
echo $((32 * 1024 * 1024 * 1024)) > /sys/block/zram0/disksize

echo "Creating swap on /dev/zram0..."
mkswap /dev/zram0

echo "Enabling swap on /dev/zram0..."
swapon /dev/zram0

echo "Verifying swap setup:"
swapon --show
free -h

echo "Done! Only zram swap is active now."
