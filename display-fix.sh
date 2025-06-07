#!/bin/bash

# This script automates the process of fixing external display issue with NVIDIA drivers on RHEL.

# Step 1: Install necessary NVIDIA dependencies
echo "Installing NVIDIA dependencies..."
sudo dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda xorg-x11-drv-nvidia-power

# Step 2: Check the NVIDIA status (optional, for debugging purposes)
echo "Checking NVIDIA status..."
nvidia-smi

# Step 3: Rebuild kernel modules to ensure compatibility with the current kernel
echo "Rebuilding NVIDIA kernel modules..."
sudo akmods --force

# Step 4: Configure NVIDIA PRIME for hybrid graphics mode
echo "Configuring NVIDIA PRIME..."
sudo nvidia-xconfig --prime

# Step 5: Check if the session is running Xorg
echo "Checking session type..."
echo $XDG_SESSION_TYPE

# Step 6: Set up the external monitor configuration using xrandr
echo "Configuring external display with xrandr..."
# Using NVIDIA-G0 as the correct provider ID
xrandr --setprovideroutputsource NVIDIA-G0 modesetting
xrandr --auto

# Optional: Add xrandr commands to ~/.xprofile for automatic execution on login
echo "Making xrandr settings persistent on login..."
echo 'xrandr --setprovideroutputsource NVIDIA-G0 modesetting' >> ~/.xprofile
echo 'xrandr --auto' >> ~/.xprofile
chmod +x ~/.xprofile

# Step 7: Final check and reboot recommendation
echo "External display should now be fixed. Please reboot your system to apply the changes."
echo "Rebooting system..."
# Uncomment the next line if you want to reboot automatically:
# sudo reboot

echo "Done. External display should be working now."
