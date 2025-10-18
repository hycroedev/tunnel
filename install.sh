#!/bin/bash

# ========= SELF-CONTAINED INSTALL FOR TUNNEL MANAGER =========
# Embed port.sh inside, no external download needed.
# Run: bash <(curl -s https://raw.githubusercontent.com/hycroedev/port-forwarding-tool/main/install.sh)

set -e  # Exit on error

echo "🚀 Installing Tunnel Manager (port tool)..."

# Embedded port.sh content (full script here)
cat > /tmp/port.sh << 'EOF'
#!/bin/bash

# ========= CONFIG =========
DB_FILE="/tmp/port_tunnels.db"
SERVER="${TUNNEL_SERVER:-137.175.89.75}"
USER="${TUNNEL_USER:-tunnel}"
PASSWORD="${TUNNEL_PASSWORD}"  # Set via export TUNNEL_PASSWORD=yourpass
SSH_KEY="${HOME}/.ssh/tunnel_key"  # Use key if exists
USE_PASSWORD=true  # Auto-detect: if key exists, use false
[ -f ~/.tunnelrc ] && source ~/.tunnelrc

# Auto-detect SSH method
if [ -f "$SSH_KEY" ]; then
  USE_PASSWORD=false
fi

mkdir -p /tmp
touch "$DB_FILE"

# Colors
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

# Auto-setup if first run
if [[ "$1" == "" ]] || [[ "$1" == "help" ]] && [ ! -f "$DB_FILE" ]; then
  banner
  echo -e "${YEL}🚀 First setup! Config cheyyunnu...${RST}"
  echo -ne "Server IP (default: $SERVER): "; read -r INPUT_SERVER
  [ -n "$INPUT_SERVER" ] && SERVER="$INPUT_SERVER"
  
  echo -ne "Username (default: $USER): "; read -r INPUT_USER
  [ -n "$INPUT_USER" ] && USER="$INPUT_USER"
  
  echo -e "${YEL}SSH: Password (p) or Key (k)? [p/k]: ${RST}"; read -r CHOICE
  if [[ "$CHOICE" =~ ^[kK]$ ]]; then
    if [ ! -f "$SSH_KEY" ]; then
      echo -e "${YEL}SSH key generate...${RST}"
      ssh-keygen -t ed25519 -f "$SSH_KEY" -N "" -q
    fi
    echo -e "${GRN}Public key (server ~/.ssh/authorized_keys ku add cheyyu):${RST}"
    cat "${SSH_KEY}.pub"
    USE_PASSWORD=false
  else
    read -s -p "Password: " PASSWORD
    echo
    USE_PASSWORD=true
  fi
  
  # Save config
  cat > ~/.tunnelrc << EOC
export TUNNEL_SERVER="$SERVER"
export TUNNEL_USER="$USER"
[ "$USE_PASSWORD" = true ] && export TUNNEL_PASSWORD="$PASSWORD"
EOC
  source ~/.tunnelrc
  echo -e "${GRN}✅ Setup done! Ippo commands try cheyyu.${RST}"
  exit 0
fi

add_tunnel() {
  local LOCAL_PORT=$1
  local TMPFILE=$(mktemp)
  
  if ! [[ "$LOCAL_PORT" =~ ^[0-9]+$ ]] || [ "$LOCAL_PORT" -lt 1 ] || [ "$LOCAL_PORT" -gt 65535 ]; then
    echo -e "❌ ${RED}Invalid port: $LOCAL_PORT${RST}"
    return 1
  fi

  echo -e "${YEL}Local port $LOCAL_PORT check...${RST}"
  if ! timeout 1 bash -c "echo > /dev/tcp/localhost/$LOCAL_PORT" 2>/dev/null; then
    echo -e "⚠️ ${YEL}Service illa, continue...${RST}"
  fi

  echo -e "${YEL}Tunnel create...${RST}"
  
  if [ "$USE_PASSWORD" = true ] && [ -n "$PASSWORD" ]; then
    command -v sshpass >/dev/null || { echo "❌ sshpass illa. sudo apt install sshpass"; return 1; }
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -N -R 0:localhost:$LOCAL_PORT $USER@$SERVER >"$TMPFILE" 2>&1 &
  else
    [ -f "$SSH_KEY" ] || { echo "❌ SSH key illa: $SSH_KEY"; return 1; }
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -N -R 0:localhost:$LOCAL_PORT $USER@$SERVER >"$TMPFILE" 2>&1 &
  fi
  local SSH_PID=$!

  for i in {1..10}; do
    if grep -q "Allocated port" "$TMPFILE"; then
      break
    fi
    sleep 0.5
  done

  if grep -q "Allocated port" "$TMPFILE"; then
    local REMOTE_PORT=$(grep "Allocated port" "$TMPFILE" | grep -oP '\d{4,5}' | head -n1)
    echo "$LOCAL_PORT:$REMOTE_PORT:$SSH_PID" >> "$DB_FILE"
    echo -e "✅ ${GRN}Tunnel OK!${RST}"
    echo -e "   Local: localhost:${LOCAL_PORT}"
    echo -e "   Remote: ${SERVER}:${REMOTE_PORT}"
    echo -e "   PID: ${SSH_PID}"
    echo ""
    echo -e "🔗 Share: ssh user@${SERVER} -p ${REMOTE_PORT}${RST}"
    echo ""
    echo -e "Stop: port stop ${LOCAL_PORT}${RST}"
  else
    echo -e "❌ ${RED}Failed!${RST}"
    echo -e "${YEL}Debug:${RST}"
    cat "$TMPFILE"
    kill "$SSH_PID" 2>/dev/null
    echo -e "💡 SSH key/server check cheyyu.${RST}"
  fi
  rm -f "$TMPFILE"
}

stop_tunnel() {
  local PORT=$1
  local TMP=$(mktemp)
  local FOUND=0
  
  if [ ! -s "$DB_FILE" ]; then
    echo -e "ℹ️ ${YEL}No tunnels.${RST}"
    return
  fi

  while IFS=: read -r LPORT RPORT PID; do
    if [[ "$LPORT" == "$PORT" ]]; then
      if kill "$PID" 2>/dev/null; then
        echo -e "🛑 ${RED}Stopped: localhost:$LPORT → ${SERVER}:$RPORT${RST}"
      else
        echo -e "⚠️ ${YEL}Dead already.${RST}"
      fi
      FOUND=1
    else
      echo "$LPORT:$RPORT:$PID" >> "$TMP"
    fi
  done < "$DB_FILE"
  
  mv "$TMP" "$DB_FILE" 2>/dev/null || true
  
  [ $FOUND -eq 0 ] && echo -e "⚠️ ${YEL}Tunnel illa for $PORT. 'port list tunnels' try.${RST}"
}

stop_all() {
  if [ ! -s "$DB_FILE" ]; then
    echo -e "ℹ️ ${YEL}No tunnels.${RST}"
    return
  fi

  echo -e "${YEL}All stop...${RST}"
  while IFS=: read -r LPORT RPORT PID; do
    if kill "$PID" 2>/dev/null; then
      echo -e "🛑 ${RED}Stopped: localhost:$LPORT → ${SERVER}:$RPORT${RST}"
    else
      echo -e "⚠️ ${YEL}Dead.${RST}"
    fi
  done < "$DB_FILE"

  > "$DB_FILE"
  echo -e "✅ ${GRN}All done.${RST}"
}

list_tunnels() {
  if [ ! -s "$DB_FILE" ]; then
    echo -e "ℹ️ ${YEL}No tunnels. 'port add <port>' try.${RST}"
    return
  fi
  
  echo -e "🔁 ${GRN}Active Tunnels:${RST}"
  echo -e "${CYN}╔══════════════════════════════════════════════════════╗${RST}"
  local TOTAL=0
  while IFS=: read -r LPORT RPORT PID; do
    if ps -p "$PID" > /dev/null 2>&1; then
      local STATUS="${GRN}● Alive${RST}"
      ((TOTAL++))
    else
      local STATUS="${RED}● Dead${RST}"
    fi
    echo -e " ${CYN}║${RST} ${YEL}localhost:${LPORT}${RST} → ${CYN}${SERVER}:${RPORT}${RST} ${STATUS} ${CYN}║${RST}"
  done < "$DB_FILE"
  echo -e "${CYN}╚══════════════════════════════════════════════════════╝${RST}"
  echo -e "📊 ${BLU}Active: $TOTAL${RST}"
}

reset() {
  echo -ne "⚠️ ${RED}All kill & clear? (y/N): ${RST}"
  read -r CONFIRM
  if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
    pkill -f "ssh.*$SERVER" 2>/dev/null
    > "$DB_FILE"
    echo -e "🧼 ${GRN}Reset done.${RST}"
  else
    echo -e "🚫 ${YEL}Cancelled.${RST}"
  fi
}

status() {
  echo -e "${GRN}🔧 Status:${RST}"
  echo -e "   ${YEL}DB: ${RST}$( [ -f "$DB_FILE" ] && echo "✅" || echo "❌" )"
  echo -e "   ${YEL}Server: ${RST}$SERVER"
  echo -e "   ${YEL}User: ${RST}$USER"
  
  echo -e "${YEL}Connection test...${RST}"
  if [ "$USE_PASSWORD" = true ] && [ -n "$PASSWORD" ]; then
    command -v sshpass >/dev/null || { echo "❌ sshpass illa."; return; }
    sshpass -p "$PASSWORD" ssh -o ConnectTimeout=5 -o BatchMode=yes $USER@$SERVER "echo OK" >/dev/null 2>&1
  else
    [ -f "$SSH_KEY" ] || { echo "❌ Key illa."; return; }
    ssh -i "$SSH_KEY" -o ConnectTimeout=5 -o BatchMode=yes $USER@$SERVER "echo OK" >/dev/null 2>&1
  fi
  [ $? -eq 0 ] && echo -e "✅ ${GRN}OK${RST}" || echo -e "❌ ${RED}Failed${RST}"
}

print_help() {
  banner
  echo -e "${GRN}Usage: port <cmd> [opt]${RST}"
  echo ""
  echo -e "${CYN}Commands:${RST}"
  echo -e "  ${YEL}add <port>${RST}     - Tunnel create"
  echo -e "  ${YEL}stop <port>${RST}    - Stop one"
  echo -e "  ${YEL}stop all${RST}       - All stop"
  echo -e "  ${YEL}list tunnels${RST}   - List"
  echo -e "  ${YEL}status${RST}         - Check"
  echo -e "  ${YEL}reset${RST}          - Clear all"
  echo -e "  ${YEL}help${RST}           - Ee help"
  echo ""
  echo -e "${GRN}Ex:${RST}"
  echo -e "  ${CYN}port add 8080${RST}  # Web tunnel"
  echo -e "  ${CYN}port list tunnels${RST}"
  echo ""
  echo -e "${YEL}Tip: Remote share cheyyu friends ku!${RST}"
}

# Main
case "$1" in
  add)
    [ -z "$2" ] && { echo -e "❌ ${RED}port add <port>${RST}"; exit 1; }
    add_tunnel "$2"
    ;;
  stop)
    if [ "$2" = "all" ]; then
      stop_all
    elif [ -n "$2" ]; then
      stop_tunnel "$2"
    else
      echo -e "❌ ${RED}port stop <port|all>${RST}"
    fi
    ;;
  list)
    [ "$2" = "tunnels" ] && list_tunnels || echo -e "❌ ${RED}port list tunnels${RST}"
    ;;
  status)
    status
    ;;
  reset)
    reset
    ;;
  help|"")
    print_help
    ;;
  *)
    echo -e "❌ ${RED}Unknown: $1${RST}"
    echo -e "💡 ${YEL}port help${RST}"
    exit 1
    ;;
esac
EOF

# Make executable
chmod +x /tmp/port.sh

# Install (copy, not link - permanent)
INSTALL_PATH="/usr/local/bin/port"
if [[ $EUID -ne 0 ]]; then
  echo "💡 Sudo venam."
  sudo cp /tmp/port.sh "$INSTALL_PATH" && sudo chmod +x "$INSTALL_PATH"
else
  cp /tmp/port.sh "$INSTALL_PATH"
  chmod +x "$INSTALL_PATH"
fi

# Cleanup
rm -f /tmp/port.sh

echo "✅ Installed! 'port help' run cheyyu."
echo "💡 First time setup prompt varum (server, pass/key)."
echo ""
echo "Quick test:"
$INSTALL_PATH help
