#!/bin/bash

# ========= CONFIG =========
DB_FILE="/tmp/port_tunnels.db"
SERVER="${TUNNEL_SERVER:-137.175.89.75}"
USER="${TUNNEL_USER:-tunnel}"
PASSWORD="${TUNNEL_PASSWORD:-G7k@pL9z}"  # Default password - CHANGE THIS for security!
SSH_KEY="${HOME}/.ssh/tunnel_key"  # Use key if exists (overrides password)
USE_PASSWORD=true  # Default to password; set to false if key preferred
[ -f ~/.tunnelrc ] && source ~/.tunnelrc

# Auto-detect: Prefer key if it exists
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

# Auto-setup if first run (only if no config/DB)
if [[ "$1" == "" ]] || [[ "$1" == "help" ]] && [ ! -f "$DB_FILE" ] && [ ! -f ~/.tunnelrc ]; then
  banner
  echo -e "${YEL}🚀 First-time setup! Configuring...${RST}"
  echo -ne "Server IP (default: $SERVER): "; read -r INPUT_SERVER
  [ -n "$INPUT_SERVER" ] && SERVER="$INPUT_SERVER"
  
  echo -ne "Username (default: $USER): "; read -r INPUT_USER
  [ -n "$INPUT_USER" ] && USER="$INPUT_USER"
  
  echo -e "${YEL}SSH Auth: Password (p) or Key (k)? [p/k]: ${RST}"; read -r CHOICE
  if [[ "$CHOICE" =~ ^[kK]$ ]]; then
    if [ ! -f "$SSH_KEY" ]; then
      echo -e "${YEL}Generating SSH key...${RST}"
      mkdir -p "$(dirname "$SSH_KEY")"
      ssh-keygen -t ed25519 -f "$SSH_KEY" -N "" -q
    fi
    echo -e "${GRN}Public key (add to server ~/.ssh/authorized_keys):${RST}"
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
  echo -e "${GRN}✅ Setup complete! Now try commands.${RST}"
  exit 0
fi

add_tunnel() {
  local LOCAL_PORT=$1
  local TMPFILE=$(mktemp)
  
  if ! [[ "$LOCAL_PORT" =~ ^[0-9]+$ ]] || [ "$LOCAL_PORT" -lt 1 ] || [ "$LOCAL_PORT" -gt 65535 ]; then
    echo -e "❌ ${RED}Invalid port: $LOCAL_PORT${RST}"
    return 1
  fi

  echo -e "${YEL}Checking local port $LOCAL_PORT...${RST}"
  if ! timeout 1 bash -c "echo > /dev/tcp/localhost/$LOCAL_PORT" 2>/dev/null; then
    echo -e "⚠️ ${YEL}No service detected, but continuing...${RST}"
  fi

  echo -e "${YEL}Creating tunnel...${RST}"
  
  if [ "$USE_PASSWORD" = true ] && [ -n "$PASSWORD" ]; then
    command -v sshpass >/dev/null || { echo "❌ sshpass not found. Install: sudo apt install sshpass"; return 1; }
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -N -R 0:localhost:$LOCAL_PORT $USER@$SERVER >"$TMPFILE" 2>&1 &
  else
    [ -f "$SSH_KEY" ] || { echo "❌ SSH key not found: $SSH_KEY"; return 1; }
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -N -R 0:localhost:$LOCAL_PORT $USER@$SERVER >"$TMPFILE" 2>&1 &
  fi
  local SSH_PID=$!

  # Wait for port allocation
  for i in {1..10}; do
    if grep -q "Allocated port" "$TMPFILE"; then
      break
    fi
    sleep 0.5
  done

  if grep -q "Allocated port" "$TMPFILE"; then
    local REMOTE_PORT=$(grep "Allocated port" "$TMPFILE" | grep -oP '\d{4,5}' | head -n1)
    echo "$LOCAL_PORT:$REMOTE_PORT:$SSH_PID" >> "$DB_FILE"
    echo -e "✅ ${GRN}Tunnel created successfully!${RST}"
    echo -e "   Local: localhost:${LOCAL_PORT}"
    echo -e "   Remote: ${SERVER}:${REMOTE_PORT}"
    echo -e "   PID: ${SSH_PID}"
    echo ""
    echo -e "🔗 Share: ssh user@${SERVER} -p ${REMOTE_PORT}${RST}"
    echo ""
    echo -e "Stop: port stop ${LOCAL_PORT}${RST}"
  else
    echo -e "❌ ${RED}Tunnel creation failed!${RST}"
    echo -e "${YEL}Debug info:${RST}"
    cat "$TMPFILE"
    kill "$SSH_PID" 2>/dev/null
    echo -e "💡 Check SSH key/server config/network.${RST}"
  fi
  rm -f "$TMPFILE"
}

stop_tunnel() {
  local PORT=$1
  local TMP=$(mktemp)
  local FOUND=0
  
  if [ ! -s "$DB_FILE" ]; then
    echo -e "ℹ️ ${YEL}No active tunnels.${RST}"
    return
  fi

  while IFS=: read -r LPORT RPORT PID; do
    if [[ "$LPORT" == "$PORT" ]]; then
      if kill "$PID" 2>/dev/null; then
        echo -e "🛑 ${RED}Stopped: localhost:$LPORT → ${SERVER}:$RPORT${RST}"
      else
        echo -e "⚠️ ${YEL}Already dead.${RST}"
      fi
      FOUND=1
    else
      echo "$LPORT:$RPORT:$PID" >> "$TMP"
    fi
  done < "$DB_FILE"
  
  mv "$TMP" "$DB_FILE" 2>/dev/null || true
  
  [ $FOUND -eq 0 ] && echo -e "⚠️ ${YEL}No tunnel found for $PORT. Try 'port list tunnels'.${RST}"
}

stop_all() {
  if [ ! -s "$DB_FILE" ]; then
    echo -e "ℹ️ ${YEL}No active tunnels.${RST}"
    return
  fi

  echo -e "${YEL}Stopping all tunnels...${RST}"
  while IFS=: read -r LPORT RPORT PID; do
    if kill "$PID" 2>/dev/null; then
      echo -e "🛑 ${RED}Stopped: localhost:$LPORT → ${SERVER}:$RPORT${RST}"
    else
      echo -e "⚠️ ${YEL}Already dead.${RST}"
    fi
  done < "$DB_FILE"

  > "$DB_FILE"
  echo -e "✅ ${GRN}All tunnels stopped.${RST}"
}

list_tunnels() {
  if [ ! -s "$DB_FILE" ]; then
    echo -e "ℹ️ ${YEL}No active tunnels. Try 'port add <port>'.${RST}"
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
  echo -e "📊 ${BLU}Total active: $TOTAL${RST}"
}

reset() {
  echo -ne "⚠️ ${RED}This will kill all tunnels and clear database. Continue? (y/N): ${RST}"
  read -r CONFIRM
  if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
    pkill -f "ssh.*$SERVER" 2>/dev/null
    > "$DB_FILE"
    echo -e "🧼 ${GRN}Reset complete.${RST}"
  else
    echo -e "🚫 ${YEL}Cancelled.${RST}"
  fi
}

status() {
  echo -e "${GRN}🔧 System Status:${RST}"
  echo -e "   ${YEL}DB File: ${RST}$( [ -f "$DB_FILE" ] && echo "✅ Found" || echo "❌ Missing" )"
  echo -e "   ${YEL}Server: ${RST}$SERVER"
  echo -e "   ${YEL}User: ${RST}$USER"
  echo -e "   ${YEL}Auth: ${RST}$( [ "$USE_PASSWORD" = true ] && echo "Password" || echo "SSH Key" )"
  
  echo -e "${YEL}Testing connection to server...${RST}"
  if [ "$USE_PASSWORD" = true ] && [ -n "$PASSWORD" ]; then
    command -v sshpass >/dev/null || { echo "❌ sshpass not found."; return; }
    sshpass -p "$PASSWORD" ssh -o ConnectTimeout=5 -o BatchMode=yes $USER@$SERVER "echo OK" >/dev/null 2>&1
  else
    [ -f "$SSH_KEY" ] || { echo "❌ SSH key not found."; return; }
    ssh -i "$SSH_KEY" -o ConnectTimeout=5 -o BatchMode=yes $USER@$SERVER "echo OK" >/dev/null 2>&1
  fi
  [ $? -eq 0 ] && echo -e "✅ ${GRN}Connection: SUCCESS${RST}" || echo -e "❌ ${RED}Connection: FAILED${RST}"
}

print_help() {
  banner
  echo -e "${GRN}Usage: port <command> [options]${RST}"
  echo ""
  echo -e "${CYN}Commands:${RST}"
  echo -e "  ${YEL}add <port>${RST}        - Create tunnel from local port to remote server"
  echo -e "  ${YEL}stop <port>${RST}      - Stop specific tunnel by local port"
  echo -e "  ${YEL}stop all${RST}         - Stop all active tunnels"
  echo -e "  ${YEL}list tunnels${RST}     - Show all active tunnels"
  echo -e "  ${YEL}status${RST}           - Check system status and connection"
  echo -e "  ${YEL}reset${RST}            - Kill all tunnels and reset database"
  echo -e "  ${YEL}help${RST}             - Show this help message"
  echo ""
  echo -e "${GRN}Examples:${RST}"
  echo -e "  ${CYN}port add 8080${RST}    # Tunnel web server"
  echo -e "  ${CYN}port list tunnels${RST}"
  echo ""
  echo -e "${YEL}Tip: Share the remote address with friends to access your service!${RST}"
  echo -e "${RED}Security Note: Default password is set - change it in ~/.tunnelrc!${RST}"
}

# Main
case "$1" in
  add)
    [ -z "$2" ] && { echo -e "❌ ${RED}Usage: port add <local_port>${RST}"; exit 1; }
    add_tunnel "$2"
    ;;
  stop)
    if [ "$2" = "all" ]; then
      stop_all
    elif [ -n "$2" ]; then
      stop_tunnel "$2"
    else
      echo -e "❌ ${RED}Usage: port stop <local_port|all>${RST}"
    fi
    ;;
  list)
    [ "$2" = "tunnels" ] && list_tunnels || echo -e "❌ ${RED}Usage: port list tunnels${RST}"
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
    echo -e "❌ ${RED}Unknown command: $1${RST}"
    echo -e "💡 ${YEL}Use 'port help' for usage.${RST}"
    exit 1
    ;;
esac
