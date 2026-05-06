#!/bin/bash

# Title: Oracle Linux Cloud-Init Auto-Reset Setup
# Description: Automates cloud-init reset for Oracle Linux (RHEL-based) systems

echo "----------------------------------------------------"
echo "   Oracle Linux Cloud-Init Auto-Reset Setup Starting   "
echo "----------------------------------------------------"

# --- STEP 1: Create the Reset Script ---
echo "[>] Creating reset script in /usr/local/bin/..."
cat << 'EOF' | sudo tee /usr/local/bin/reset-cloud-init.sh > /dev/null
#!/bin/bash
# Remove Cloud-Init cached data
rm -rf /var/lib/cloud/instance
rm -rf /var/lib/cloud/instances/*

# Clear SSH keys for the Oracle Linux default user (opc)
# Oracle Linux-এ সাধারণত ইউজার 'opc' থাকে, প্রয়োজনে এটি পরিবর্তন করুন
if [ -d /home/opc/.ssh ]; then
    truncate -s 0 /home/opc/.ssh/authorized_keys
fi

# Deep clean cloud-init
cloud-init clean --logs

# Additional Cleanups for Oracle Linux Golden Image
cat /dev/null > /etc/machine-id
rm -f /etc/udev/rules.d/70-persistent-net.rules
EOF

# Apply Permissions
sudo chmod +x /usr/local/bin/reset-cloud-init.sh
echo "[✔] Reset script created and permissions set."

# --- STEP 2: Create the Systemd Unit ---
echo "[>] Configuring systemd service..."
cat << 'EOF' | sudo tee /etc/systemd/system/cloud-init-reset.service > /dev/null
[Unit]
Description=Reset Cloud-Init on Oracle Linux Boot
Before=cloud-init-local.service
DefaultDependencies=no

[Service]
Type=oneshot
ExecStart=/usr/local/bin/reset-cloud-init.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# --- STEP 3: Enable Automation ---
sudo systemctl daemon-reload
sudo systemctl enable cloud-init-reset.service
echo "[✔] Systemd service enabled."

# --- STEP 4: SELinux Adjustment ---
if command -v restorecon > /dev/null; then
    sudo restorecon -v /usr/local/bin/reset-cloud-init.sh
    echo "[✔] SELinux context updated."
fi

echo "----------------------------------------------------"
echo "Setup Complete! Oracle Linux Golden Image is ready."
echo "----------------------------------------------------"
