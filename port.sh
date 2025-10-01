#!/bin/bash

# ========= CONFIG =========
DB_FILE="/tmp/port_tunnels.db"
SERVER="137.175.89.137"
USER="tunnel"
SSH_KEY="$HOME/.ssh/tunnel_key"
# ==========================

mkdir -p /tmp
touch "$DB_FILE"

# 🎨 Colors
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

add_tunnel() {
  LOCAL_PORT=$1
  TMPFILE=$(mktemp)
  
  # Validate port number
  if ! [[ "$LOCAL_PORT" =~ ^[0-9]+$ ]] || [ "$LOCAL_PORT" -lt 1 ] || [ "$LOCAL_PORT" -gt 65535 ]; then
    echo -e "❌ ${RED}Invalid port number: $LOCAL_PORT${RST}"
    return 1
  fi

  # Check if SSH key exists
  if [ ! -f "$SSH_KEY" ]; then
    echo -e "❌ ${RED}SSH key not found: $SSH_KEY${RST}"
    echo -e "💡 ${YEL}Generate one with: ssh-keygen -t ed25519 -f ~/.ssh/tunnel_key -N ''${RST}"
    return 1
  fi

  # Verify local service is reachable
  echo -e "${YEL}Checking local service on port $LOCAL_PORT...${RST}"
  if ! timeout 1 bash -c "echo > /dev/tcp/localhost/$LOCAL_PORT" 2>/dev/null; then
    echo -e "⚠️ ${YEL}No service detected on localhost:$LOCAL_PORT${RST}"
    echo -e "💡 ${YEL}Make sure your service is running, but continuing anyway...${RST}"
  fi

  echo -e "${YEL}Creating tunnel...${RST}"
  
  # Use SSH key authentication
  ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      -i "$SSH_KEY" -N -R 0:localhost:$LOCAL_PORT $USER@$SERVER >"$TMPFILE" 2>&1 &
  SSH_PID=$!

  # Wait for port allocation
  for i in {1..10}; do
    if grep -q "Allocated port" "$TMPFILE"; then
      break
    fi
    sleep 0.5
  done

  if grep -q "Allocated port" "$TMPFILE"; then
    REMOTE_PORT=$(grep "Allocated port" "$TMPFILE" | grep -oP '\d{4,5}' | head -n1)
    echo "$LOCAL_PORT:$REMOTE_PORT:$SSH_PID" >> "$DB_FILE"
    echo -e "✅ ${GRN}Tunnel Created Successfully!${RST}"
    echo -e "   ${YEL}Local Address:${RST}  localhost:${LOCAL_PORT}"
    echo -e "   ${CYN}Remote Address:${RST} ${SERVER}:${REMOTE_PORT}"
    echo -e "   ${BLU}Process ID:${RST}     ${SSH_PID}"
    echo ""
    echo -e "🔗 ${GRN}Share this with your friends:${RST}"
    echo -e "   ${CYN}ssh username@${SERVER} -p ${REMOTE_PORT}${RST}"
    echo ""
    echo -e "💡 ${YEL}To stop: port stop ${LOCAL_PORT}${RST}"
  else
    echo -e "❌ ${RED}Tunnel Creation Failed!${RST}"
    echo -e "${YEL}Debug information:${RST}"
    cat "$TMPFILE"
    kill "$SSH_PID" 2>/dev/null
    echo ""
    echo -e "💡 ${YEL}Troubleshooting:${RST}"
    echo -e "   • Check if SSH key is properly setup on tunnel server"
    echo -e "   • Verify tunnel server configuration"
    echo -e "   • Check network connectivity"
  fi
  rm -f "$TMPFILE"
}

stop_tunnel() {
  PORT=$1
  TMP=$(mktemp)
  FOUND=0
  
  if [ ! -f "$DB_FILE" ] || [ ! -s "$DB_FILE" ]; then
    echo -e "ℹ️ ${YEL}No active tunnels found.${RST}"
    return
  fi

  while IFS=: read -r LPORT RPORT PID; do
    if [[ "$LPORT" == "$PORT" ]]; then
      if kill "$PID" 2>/dev/null; then
        echo -e "🛑 ${RED}Stopped tunnel:${RST} localhost:$LPORT → ${SERVER}:$RPORT"
      else
        echo -e "⚠️ ${YEL}Stopped dead tunnel:${RST} localhost:$LPORT → ${SERVER}:$RPORT"
      fi
      FOUND=1
    else
      echo "$LPORT:$RPORT:$PID" >> "$TMP"
    fi
  done < "$DB_FILE"
  
  if [ -f "$TMP" ]; then
    mv "$TMP" "$DB_FILE"
  fi
  
  if [ $FOUND -eq 0 ]; then
    echo -e "⚠️ ${YEL}No tunnel found for port $PORT${RST}"
    echo -e "💡 ${YEL}Use 'port list tunnels' to see active tunnels${RST}"
  fi
}

stop_all() {
  if [ ! -f "$DB_FILE" ] || [ ! -s "$DB_FILE" ]; then
    echo -e "ℹ️ ${YEL}No active tunnels to stop.${RST}"
    return
  fi

  echo -e "${YEL}Stopping all tunnels...${RST}"
  while IFS=: read -r LPORT RPORT PID; do
    if kill "$PID" 2>/dev/null; then
      echo -e "🛑 ${RED}Stopped:${RST} localhost:$LPORT → ${SERVER}:$RPORT"
    else
      echo -e "⚠️ ${YEL}Already dead:${RST} localhost:$LPORT → ${SERVER}:$RPORT"
    fi
  done < "$DB_FILE"

  > "$DB_FILE"
  echo -e "✅ ${GRN}All tunnels stopped.${RST}"
}

list_tunnels() {
  if [ ! -f "$DB_FILE" ] || [ ! -s "$DB_FILE" ]; then
    echo -e "ℹ️ ${YEL}No active tunnels.${RST}"
    echo -e "💡 ${YEL}Create one with: port add <port>${RST}"
    return
  fi
  
  echo -e "🔁 ${GRN}Active Tunnels:${RST}"
  echo -e "${CYN}╔══════════════════════════════════════════════════════╗${RST}"
  TOTAL=0
  while IFS=: read -r LPORT RPORT PID; do
    if ps -p "$PID" > /dev/null 2>&1; then
      STATUS="${GRN}● Alive${RST}"
      ((TOTAL++))
    else
      STATUS="${RED}● Dead${RST}"
    fi
    echo -e " ${CYN}║${RST} ${YEL}localhost:${LPORT}${RST} → ${CYN}${SERVER}:${RPORT}${RST} ${STATUS} ${CYN}║${RST}"
  done < "$DB_FILE"
  echo -e "${CYN}╚══════════════════════════════════════════════════════╝${RST}"
  echo -e "📊 ${BLU}Total active tunnels: $TOTAL${RST}"
}

reset() {
  echo -ne "⚠️ ${RED}This will kill ALL tunnel processes & clear database. Continue? (y/N): ${RST}"
  read -r CONFIRM
  if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
    # Kill all SSH tunnel processes
    pkill -f "ssh.*$SERVER" 2>/dev/null
    > "$DB_FILE"
    echo -e "🧼 ${GRN}Complete reset done. All tunnels cleared.${RST}"
  else
    echo -e "🚫 ${YEL}Reset cancelled.${RST}"
  fi
}

status() {
  if [ ! -f "$SSH_KEY" ]; then
    echo -e "❌ ${RED}SSH key not found: $SSH_KEY${RST}"
    echo -e "💡 ${YEL}Generate one with: ssh-keygen -t ed25519 -f ~/.ssh/tunnel_key -N ''${RST}"
    return 1
  fi

  echo -e "${GRN}🔧 System Status:${RST}"
  echo -e "   ${YEL}SSH Key:${RST} $( [ -f "$SSH_KEY" ] && echo "✅ Found" || echo "❌ Missing" )"
  echo -e "   ${YEL}DB File:${RST} $( [ -f "$DB_FILE" ] && echo "✅ Found" || echo "❌ Missing" )"
  echo -e "   ${YEL}Tunnel Server:${RST} $SERVER"
  echo -e "   ${YEL}Tunnel User:${RST} $USER"
  
  # Test connection
  echo -e "${YEL}Testing connection to tunnel server...${RST}"
  if ssh -o ConnectTimeout=5 -o BatchMode=yes -i "$SSH_KEY" $USER@$SERVER "echo Connected" 2>/dev/null; then
    echo -e "✅ ${GRN}Connection test: SUCCESS${RST}"
  else
    echo -e "❌ ${RED}Connection test: FAILED${RST}"
    echo -e "💡 ${YEL}Check:${RST}"
    echo -e "   • SSH key setup on tunnel server"
    echo -e "   • Network connectivity"
    echo -e "   • Tunnel server configuration"
  fi
}

print_help() {
  banner
  echo -e "${GRN}Usage: port <command> [options]${RST}"
  echo ""
  echo -e "${CYN}Commands:${RST}"
  echo -e "  ${YEL}add <port>${RST}        - Create tunnel from local port to remote server"
  echo -e "  ${YEL}stop <port>${RST}       - Stop specific tunnel by local port"
  echo -e "  ${YEL}stop all${RST}          - Stop all active tunnels"
  echo -e "  ${YEL}list tunnels${RST}      - Show all active tunnels"
  echo -e "  ${YEL}status${RST}            - Check system status and connection"
  echo -e "  ${YEL}reset${RST}             - Kill all tunnels and reset database"
  echo -e "  ${YEL}help${RST}              - Show this help message"
  echo ""
  echo -e "${GRN}Examples:${RST}"
  echo -e "  ${CYN}port add 22${RST}           # Tunnel SSH server"
  echo -e "  ${CYN}port add 8080${RST}         # Tunnel web server"
  echo -e "  ${CYN}port stop 22${RST}          # Stop SSH tunnel"
  echo -e "  ${CYN}port list tunnels${RST}     # Show active tunnels"
  echo ""
  echo -e "${YEL}📖 Tip: Share the remote address with friends to access your service!${RST}"
}

# ========= Main =========
case "$1" in
  add)
    if [ -z "$2" ]; then
      echo -e "❌ ${RED}Usage: port add <local_port>${RST}"
      exit 1
    fi
    add_tunnel "$2"
    ;;
  stop)
    if [ "$2" == "all" ]; then
      stop_all
    elif [ -n "$2" ]; then
      stop_tunnel "$2"
    else
      echo -e "❌ ${RED}Usage: port stop <local_port|all>${RST}"
    fi
    ;;
  list)
    if [ "$2" == "tunnels" ]; then
      list_tunnels
    else
      echo -e "❌ ${RED}Usage: port list tunnels${RST}"
    fi
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
    echo -e "💡 ${YEL}Use 'port help' for usage information${RST}"
    exit 1
    ;;
esac
