#!/bin/bash

# Title: Oracle Linux Cloud-Init Auto-Reset (Password Enable)
# Description: Automates cloud-init reset and keeps Password Auth ON

echo "----------------------------------------------------"
echo "   Oracle Linux Cloud-Init Auto-Reset Setup Starting   "
echo "----------------------------------------------------"

# --- STEP 1: Create the Reset Script ---
echo "[>] Creating reset script in /usr/local/bin/..."
cat << 'EOF' | sudo tee /usr/local/bin/reset-cloud-init.sh > /dev/null
#!/bin/bash
# ১. ক্লাউড-ইনিট ক্যাশ এবং লগ ডিলিট করা
rm -rf /var/lib/cloud/instance
rm -rf /var/lib/cloud/instances/*
cloud-init clean --logs

# ২. SSH কনফিগারেশনে পাসওয়ার্ড লগইন এনাবল রাখা
# এটি নিশ্চিত করবে যে প্রতিবার রিসেট হওয়ার সময় পাসওয়ার্ড অপশন চালু হবে
sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# ৩. Cloud-Init যাতে পাসওয়ার্ড বন্ধ করতে না পারে তার ব্যবস্থা
if [ -f /etc/cloud/cloud.cfg ]; then
    # ssh_pwauth ভ্যালু true করা
    sed -i 's/ssh_pwauth:   false/ssh_pwauth:   true/' /etc/cloud/cloud.cfg
    sed -i 's/ssh_pwauth: no/ssh_pwauth: yes/' /etc/cloud/cloud.cfg
    # যদি ফাইলে না থাকে তবে নতুন করে যোগ করা
    grep -q "ssh_pwauth: true" /etc/cloud/cloud.cfg || echo "ssh_pwauth: true" >> /etc/cloud/cloud.cfg
fi

# ৪. পুরনো কী ক্লিনআপ (যাতে নতুন VM-এর নতুন কী কাজ করতে পারে)
# এটি হোম ডিরেক্টরির সব ইউজারের authorized_keys খালি করবে
for home in /home/*; do
    if [ -d "$home/.ssh" ]; then
        truncate -s 0 "$home/.ssh/authorized_keys"
    fi
done

# ৫. গোল্ডেন ইমেজ ক্লিনিং
cat /dev/null > /etc/machine-id
rm -f /etc/udev/rules.d/70-persistent-net.rules

# SSH সার্ভিস রিস্টার্ট করে পরিবর্তনগুলো কার্যকর করা
systemctl restart sshd
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
echo "Setup Complete! Password Authentication is now persistent."
echo "----------------------------------------------------"
