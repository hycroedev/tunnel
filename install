#!/bin/bash

# --- Update & install dependencies ---
echo "📦 Updating system and installing sshpass..."
apt update -y >/dev/null 2>&1
apt install -y sshpass >/dev/null 2>&1

# --- Prepare SSH directory and password file ---
mkdir -p ~/.ssh
echo 'Lw-T72q)L735Rwz+Iv' > ~/.ssh/.tunnel_pass
chmod 600 ~/.ssh/.tunnel_pass
echo "🔑 SSH password file created at ~/.ssh/.tunnel_pass"

# --- Download and install your port-forwarding script ---
SCRIPT_URL="https://raw.githubusercontent.com/hycroedev/port-forwarding-tool/main/install.sh"
INSTALL_PATH="/usr/local/bin/port"

echo "📥 Downloading port-forwarding script..."
curl -fsSL "$SCRIPT_URL" -o "$INSTALL_PATH"
chmod +x "$INSTALL_PATH"
echo "✅ Script installed at $INSTALL_PATH"

# --- Run initial setup ---
echo "🔄 Running initial port setup..."
port setup

echo "🎉 Installation complete! Use 'port add <local_port>' to add tunnels."
