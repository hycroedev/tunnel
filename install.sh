#!/bin/bash
set -e

echo "🔧 Installing dependencies..."
apt update -y
apt install -y ssh sshpass

echo "📂 Installing port tool..."
cp port.sh /usr/local/bin/port
chmod +x /usr/local/bin/port

echo "✅ Install complete!"
echo "You can now run: port help"
