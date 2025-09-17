#!/bin/bash

# ========= CONFIG =========
DB_FILE="/tmp/port_tunnels.db"
SERVER="137.175.89.45"
USER="tunnel"
PASS="Lw-T72q)L735Rwz+Iv"
# ==========================

mkdir -p /tmp
touch "$DB_FILE"

# 🎨 Colors
RED="\e[31m"
GRN="\e[32m"
YEL="\e[33m"
CYN="\e[36m"
RST="\e[0m"

banner() {
  echo -e "${CYN}=============================="
  echo -e "     HycroeDev"
  echo -e "==============================${RST}"
}

add_tunnel() {
  LOCAL_PORT=$1
  TMPFILE=$(mktemp)

  sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      -N -R 0:localhost:$LOCAL_PORT $USER@$SERVER >"$TMPFILE" 2>&1 &
  SSH_PID=$!

  # wait up to 5s for port allocation
  for i in {1..10}; do
    if grep -q "Allocated port" "$TMPFILE"; then break; fi
    sleep 0.5
  done

  if grep -q "Allocated port" "$TMPFILE"; then
    REMOTE_PORT=$(grep "Allocated port" "$TMPFILE" | grep -oP '\d{4,5}' | head -n1)
    echo "$LOCAL_PORT:$REMOTE_PORT:$SSH_PID" >> "$DB_FILE"
    echo -e "✅ ${GRN}Tunnel created:${RST} localhost:${YEL}$LOCAL_PORT${RST} ➜ ${CYN}$SERVER:$REMOTE_PORT${RST} (pid $SSH_PID)"
  else
    echo -e "❌ ${RED}Tunnel failed!${RST} reason:"
    grep -v "^Warning:" "$TMPFILE"
    kill "$SSH_PID" 2>/dev/null
  fi
  rm -f "$TMPFILE"
}

stop_tunnel() {
  PORT=$1
  TMP=$(mktemp)
  FOUND=0
  while IFS=: read -r LPORT RPORT PID; do
    if [[ "$LPORT" == "$PORT" ]]; then
      kill "$PID" 2>/dev/null
      echo -e "🛑 ${RED}Stopped tunnel:${RST} localhost:$LPORT (remote $SERVER:$RPORT)"
      FOUND=1
    else
      echo "$LPORT:$RPORT:$PID" >> "$TMP"
    fi
  done < "$DB_FILE"
  mv "$TMP" "$DB_FILE"
  [[ $FOUND -eq 0 ]] && echo -e "⚠️ ${YEL}No tunnel found for port $PORT${RST}"
}

stop_all() {
  while IFS=: read -r LPORT RPORT PID; do
    kill "$PID" 2>/dev/null
    echo -e "🛑 ${RED}Killed tunnel:${RST} localhost:$LPORT (remote $SERVER:$RPORT)"
  done < "$DB_FILE"

  > "$DB_FILE"
}

list_tunnels() {
  if [[ ! -s "$DB_FILE" ]]; then
    echo -e "ℹ️ ${YEL}No active tunnels right now.${RST}"
    return
  fi
  echo -e "🔁 ${GRN}Active tunnels:${RST}"
  while IFS=: read -r LPORT RPORT PID; do
    if ps -p "$PID" > /dev/null 2>&1; then
      echo -e " • ${CYN}$SERVER:$RPORT${RST} ➜ localhost:${YEL}$LPORT${RST} (pid $PID)"
    else
      echo -e " • ${CYN}$SERVER:$RPORT${RST} ➜ localhost:${YEL}$LPORT${RST} ${RED}(dead)${RST}"
    fi
  done < "$DB_FILE"
}

reset() {
  echo -ne "⚠️ ${YEL}This will kill ALL ssh processes & wipe DB. Continue? (y/n): ${RST}"
  read -r CONFIRM
  if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
    pkill -9 ssh 2>/dev/null
    > "$DB_FILE"
    echo -e "🧼 ${GRN}Reset complete${RST}"
  else
    echo -e "🚫 ${RED}Reset cancelled${RST}"
  fi
}

print_help() {
  banner
  echo "usage:"
  echo "  port add <local_port>     - create tunnel (remote port auto-alloc)"
  echo "  port stop <local_port>    - stop specific tunnel"
  echo "  port stop all             - kill all tunnels"
  echo "  port list tunnels         - show active tunnels"
  echo "  port reset                - kill ALL ssh procs + wipe DB"
  echo "  port help                 - show this help"
}

# ========= Main =========
case "$1" in
  add)   [[ -n "$2" ]] && add_tunnel "$2" || echo "usage: port add <local_port>" ;;
  stop)  [[ "$2" == "all" ]] && stop_all || [[ -n "$2" ]] && stop_tunnel "$2" || echo "usage: port stop <local_port|all>" ;;
  list)  [[ "$2" == "tunnels" ]] && list_tunnels || echo "usage: port list tunnels" ;;
  reset) reset ;;
  help|"") print_help ;;
  *) echo -e "❓ ${RED}Unknown command:${RST} $1"; print_help ;;
esac
