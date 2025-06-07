#!/bin/bash
set -e

echo "==> Setting CPU governor to performance for all CPUs now"
if ! command -v cpupower &> /dev/null; then
    echo "Installing cpupower..."
    sudo dnf install -y kernel-tools
fi
for cpu_path in /sys/devices/system/cpu/cpu[0-9]*; do
    echo performance | sudo tee "$cpu_path/cpufreq/scaling_governor"
done

echo "==> Creating systemd service to set CPU governor persistently at boot"
sudo tee /etc/systemd/system/cpugov-performance.service > /dev/null << 'EOF'
[Unit]
Description=Set CPU governor to performance
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'for cpu in /sys/devices/system/cpu/cpu[0-9]*; do echo performance > "$cpu/cpufreq/scaling_governor"; done'

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now cpugov-performance.service
echo "CPU governor persistence service enabled and started."

echo "==> Setting I/O scheduler to 'none' for NVMe device"
NVME_DEV=$(lsblk -ndo NAME,TYPE | grep nvme | head -n1)
if [ -z "$NVME_DEV" ]; then
    echo "No NVMe device found, skipping I/O scheduler tuning."
else
    echo none | sudo tee /sys/block/$NVME_DEV/queue/scheduler
    # Create udev rule for persistence
    UDEV_RULE_FILE="/etc/udev/rules.d/60-ioscheduler.rules"
    echo "ACTION==\"add|change\", KERNEL==\"$NVME_DEV\", ATTR{queue/scheduler}=\"none\"" | sudo tee $UDEV_RULE_FILE
    sudo udevadm control --reload-rules
    echo "I/O scheduler set to 'none' and udev rule created."
fi

echo "==> Enabling and starting fstrim.timer for TRIM support"
sudo systemctl enable --now fstrim.timer

echo "==> Updating /etc/fstab to add 'noatime' to XFS root mount"
FSTAB_LINE=$(grep ' / ' /etc/fstab | grep xfs)
if [[ "$FSTAB_LINE" == *"noatime"* ]]; then
    echo "noatime already present in /etc/fstab, skipping."
else
    sudo cp /etc/fstab /etc/fstab.bak.$(date +%F-%T)
    sudo sed -i 's/\(.*xfs.*defaults\)/\1,noatime/' /etc/fstab
    echo "Updated /etc/fstab with noatime for root."
fi

echo "==> Installing and setting tuned profile to throughput-performance"
if ! command -v tuned-adm &> /dev/null; then
    sudo dnf install -y tuned
fi
sudo systemctl enable --now tuned
sudo tuned-adm profile throughput-performance

echo "==> All done! Please reboot to apply all persistent settings."

