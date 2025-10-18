#!/bin/bash

# ========= INSTALL SCRIPT FOR TUNNEL MANAGER =========
# This installs the 'port' command to /usr/local/bin
# Run: bash <(curl -s https://raw.githubusercontent.com/hycroedev/port-forwarding-tool/main/install.sh)

set -e  # Exit on error

echo "🚀 Installing Tunnel Manager (port tool)..."

# Create temp dir
TEMP_DIR=$(mktemp -d)
SCRIPT_PATH="$TEMP_DIR/port.sh"

# Download main script from raw GitHub
curl -s https://raw.githubusercontent.com/hycroedev/port-forwarding-tool/main/port.sh -o "$SCRIPT_PATH" || {
  echo "❌ Failed to download main script. Check repo."
  exit 1
}

# Make executable
chmod +x "$SCRIPT_PATH"

# Install to /usr/local/bin (needs sudo if not root)
INSTALL_PATH="/usr/local/bin/port"
if [[ $EUID -ne 0 ]]; then
  echo "💡 Need sudo to install to $INSTALL_PATH. Enter password if prompted."
  sudo ln -sf "$SCRIPT_PATH" "$INSTALL_PATH" 2>/dev/null || {
    echo "❌ Install failed. Try manual: sudo cp $SCRIPT_PATH $INSTALL_PATH && sudo chmod +x $INSTALL_PATH"
    exit 1
  }
else
  ln -sf "$SCRIPT_PATH" "$INSTALL_PATH"
  chmod +x "$INSTALL_PATH"
fi

# Cleanup temp
rm -rf "$TEMP_DIR"

echo "✅ Installed! Run 'port help' to start."
echo "💡 First time? It will prompt for server config (IP, user, password/SSH key)."
echo ""
echo "Quick test:"
$INSTALL_PATH help
