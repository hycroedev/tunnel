#!/bin/bash

# ========= CONFIG =========
DB_FILE="/tmp/port_tunnels.db"
SERVER="${TUNNEL_SERVER:-137.175.89.75}"
USER="${TUNNEL_USER:-tunnel}"
PASSWORD="${TUNNEL_PASSWORD}"  # Set via export TUNNEL_PASSWORD=yourpass
SSH_KEY="${HOME}/.ssh/tunnel_key"  # Or use key
USE_PASSWORD=true  # Change to false if using key
# Load from ~/.tunnelrc if exists
[ -f ~/.tunnelrc ] && source ~/.tunnelrc
# ==========================

mkdir -p /tmp
touch "$DB_FILE"

# 🎨 Colors (same as original)
RED="\e[31m"
GRN="\e[32m"
YEL="\e[33m"
CYN="\e[36m"
BLU="\e[34m"
RST="\e[0m"

banner() {
  echo -e "${CYN}"
  echo "╔══════════════════════════════╗"
  echo "║         Tunnel Manager       ║"
  echo "║         by HycroeDev         ║"
  echo "╚══════════════════════════════╝"
  echo -e "${RST}"
}

# Auto-setup if first run (new addition)
if [[ "$1" == "" ]] && [ ! -f "$DB_FILE" ]; then
  banner
  echo -e "${YEL}🚀 First setup! Config cheyyunnu...${RST}"
  echo -ne "Server IP (default: $SERVER): "; read INPUT_SERVER
  [ -n "$INPUT_SERVER" ] && SERVER="$INPUT_SERVER"
  
  echo -ne "Username (default: $USER): "; read INPUT_USER
  [ -n "$INPUT_USER" ] && USER="$INPUT_USER"
  
  echo -e "${YEL}SSH: Password or Key? (p/k): ${RST}"; read CHOICE
  if [[ "$CHOICE" =~ ^[kK]$ ]]; then
    echo -e "${YEL}SSH key generate cheyyunnu...${RST}"
    ssh-keygen -t ed25519 -f "$SSH_KEY" -N "" -q
    echo -e "${GRN}Public key (server la ~/.ssh/authorized_keys ku add cheyyu):${RST}"
    cat "${SSH_KEY}.pub"
    USE_PASSWORD=false
  else
    read -s -p "Password: " PASSWORD
    echo
    USE_PASSWORD=true
  fi
  
  # Save config
  cat > ~/.tunnelrc << EOF
export TUNNEL_SERVER="$SERVER"
export TUNNEL_USER="$USER"
export TUNNEL_PASSWORD="$PASSWORD"
EOF
  source ~/.tunnelrc
  echo -e "${GRN}✅ Setup done! Ippo 'port help' try cheyyu.${RST}"
  exit 0
fi

add_tunnel() {
  LOCAL_PORT=$1
  TMPFILE=$(mktemp)
  
  # Validate port (same)
  if ! [[ "$LOCAL_PORT" =~ ^[0-9]+$ ]] || [ "$LOCAL_PORT" -lt 1 ] || [ "$LOCAL_PORT" -gt 65535 ]; then
    echo -e "❌ ${RED}Invalid port: $LOCAL_PORT${RST}"
    return 1
  fi

  # Check local service (same)
  echo -e "${YEL}Local port $LOCAL_PORT check...${RST}"
  if ! timeout 1 bash -c "echo > /dev/tcp/localhost/$LOCAL_PORT" 2>/dev/null; then
    echo -e "⚠️ ${YEL}Service illa, but continue...${RST}"
  fi

  echo -e "${YEL}Tunnel create...${RST}"
  
  # SSH command with key or password
  if [ "$USE_PASSWORD" = true ] && [ -n "$PASSWORD" ]; then
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -N -R 0:localhost:$LOCAL_PORT $USER@$SERVER >"$TMPFILE" 2>&1 &
  else
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -N -R 0:localhost:$LOCAL_PORT $USER@$SERVER >"$TMPFILE" 2>&1 &
  fi
  SSH_PID=$!

  # Wait for port (same)
  for i in {1..10}; do
    if grep -q "Allocated port" "$TMPFILE"; then
      break
    fi
    sleep 0.5
  done

  if grep -q "Allocated port" "$TMPFILE"; then
    REMOTE_PORT=$(grep "Allocated port" "$TMPFILE" | grep -oP '\d{4,5}' | head -n1)
    echo "$LOCAL_PORT:$REMOTE_PORT:$SSH_PID" >> "$DB_FILE"
    echo -e "✅ ${GRN}Tunnel OK!${RST}"
    echo -e "   Local: localhost:${LOCAL_PORT}"
    echo -e "   Remote: ${SERVER}:${REMOTE_PORT}"
    echo -e "   PID: ${SSH_PID}"
    echo ""
    echo -e "🔗 Share: ssh username@${SERVER} -p ${REMOTE_PORT}${RST}"
    echo ""
    echo -e "Stop: port stop ${LOCAL_PORT}${RST}"
  else
    echo -e "❌ ${RED}Failed!${RST}"
    echo -e "${YEL}Debug:${RST}"
    grep -v "^Warning:" "$TMPFILE"
    kill "$SSH_PID" 2>/dev/null
    echo ""
    echo -e "💡 Check SSH key/server config/network.${RST}"
  fi
  rm -f "$TMPFILE"
}

# Other functions same as original: stop_tunnel, stop_all, list_tunnels, reset, status, print_help
# (Paste ninte original functions here exactly - add_tunnel mattum update cheythu)

stop_tunnel() {
  # Original code...
  # (Copy from your script)
}

# ... (rest same)

# Main case same
case "$1" in
  # ... (original)
esac
