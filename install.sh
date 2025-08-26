#!/bin/bash
# 🚀 Simple Public Port Forwarding Tool (Auto Install & Setup)
# VPS Gateway = 89.168.49.205
# Author: HycroeDev

# VPS Info
GATEWAY_IP="89.168.49.205"
GATEWAY_USER="tunnel"

# Password file
PASS_FILE="$HOME/.ssh/.tunnel_pass"
KEY_PATH="$HOME/.ssh/tunnel_key"
DB_FILE="$HOME/.forward_db"

# --- STEP 1: Install dependencies ---
echo "📦 Installing dependencies..."
apt-get update -y >/dev/null 2>&1
apt-get install -y sshpass openssh-client >/dev/null 2>&1

mkdir -p "$(dirname $DB_FILE)"
touch "$DB_FILE"

# --- STEP 2: Save password (if not saved) ---
if [ ! -f "$PASS_FILE" ]; then
    echo "🔑 Saving VPS password..."
    echo "Lw-T72q)L735Rwz+Iv" > "$PASS_FILE"
    chmod 600 "$PASS_FILE"
fi

# --- STEP 3: Generate SSH key if not exists ---
if [ ! -f "$KEY_PATH" ]; then
    echo "🔑 Generating SSH key..."
    ssh-keygen -t ed25519 -f "$KEY_PATH" -N "" -q
fi

# --- STEP 4: Copy key using sshpass ---
echo "📤 Copying SSH key to $GATEWAY_USER@$GATEWAY_IP ..."
GATEWAY_PASS=$(cat "$PASS_FILE")
sshpass -p "$GATEWAY_PASS" ssh-copy-id -i "$KEY_PATH.pub" \
    -o StrictHostKeyChecking=no "$GATEWAY_USER@$GATEWAY_IP"

# --- STEP 5: Install main script (port command) ---
cat > /usr/local/bin/port <<'EOF'
#!/bin/bash
# 🚀 Simple Public Port Forwarding Tool (Main CLI)
GATEWAY_IP="89.168.49.205"
GATEWAY_USER="tunnel"
KEY_PATH="$HOME/.ssh/tunnel_key"
DB_FILE="$HOME/.forward_db"

# 🚀 Add new tunnel
function add_tunnel() {
    LOCAL_PORT=$1
    if [ -z "$LOCAL_PORT" ]; then
        echo "❌ Usage: port add <local_port>"
        exit 1
    fi
    REMOTE_PORT=$((20000 + RANDOM % 40000))
    ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no -f -N \
        -R ${REMOTE_PORT}:localhost:${LOCAL_PORT} \
        ${GATEWAY_USER}@${GATEWAY_IP}
    if [ $? -eq 0 ]; then
        echo "${LOCAL_PORT}:${REMOTE_PORT}" >> $DB_FILE
        echo "✅ Port ${LOCAL_PORT} forwarded → ${GATEWAY_IP}:${REMOTE_PORT}"
    else
        echo "❌ Failed to create tunnel!"
    fi
}

# 📋 List active tunnels
function list_tunnels() {
    echo "📋 Active tunnels:"
    cat $DB_FILE
}

# 🛑 Stop tunnel
function stop_tunnel() {
    LOCAL_PORT=$1
    if [ "$LOCAL_PORT" == "all" ]; then
        pkill -f "ssh -i $KEY_PATH" || true
        > $DB_FILE
        echo "🛑 All tunnels stopped."
        exit 0
    fi
    REMOTE_PORT=$(grep "^${LOCAL_PORT}:" $DB_FILE | cut -d: -f2)
    if [ -z "$REMOTE_PORT" ]; then
        echo "❌ No tunnel found for local port $LOCAL_PORT"
        exit 1
    fi
    pkill -f "${REMOTE_PORT}:localhost:${LOCAL_PORT}" || true
    sed -i "/^${LOCAL_PORT}:/d" $DB_FILE
    echo "🛑 Tunnel for local $LOCAL_PORT stopped."
}

# ♻️ Reset all
function reset_tunnels() {
    pkill -f "ssh -i $KEY_PATH" || true
    > $DB_FILE
    echo "♻️ Reset all tunnels."
}

case $1 in
    add) add_tunnel $2 ;;
    list) list_tunnels ;;
    stop) stop_tunnel $2 ;;
    reset) reset_tunnels ;;
    *) echo "Usage: port {add <port>|list|stop <port>|stop all|reset}" ;;
esac
EOF

chmod +x /usr/local/bin/port

echo "✅ Installation complete!"
echo "👉 Use: port add <local_port>"
