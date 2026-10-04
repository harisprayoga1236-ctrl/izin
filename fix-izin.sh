#!/bin/bash
# Mimo V2.6 Flash - License Authorization System
# Owner: harisprayoga1236-ctrl
# Repository: https://github.com/harisprayoga1236-ctrl/izin

IZIN_URL="https://raw.githubusercontent.com/harisprayoga1236-ctrl/izin/main/ip"
CACHE_DIR="/tmp/izin_cache"
CACHE_FILE="$CACHE_DIR/iplist.txt"
IPSAVE_FILE="/usr/bin/ipsave"
USER_FILE="/usr/bin/user"
EXP_FILE="/usr/bin/e"

mkdir -p "$CACHE_DIR" /etc/xray

# Get VPS IP address
MYIP=$(
  curl -s --max-time 5 ipv4.icanhazip.com ||
  curl -s --max-time 5 ifconfig.me ||
  wget -qO- ipinfo.io/ip
)

[ -z "$MYIP" ] && { echo "❌ Gagal mengambil IP"; exit 1; }
echo "$MYIP" > "$IPSAVE_FILE"

# Fetch/refresh license file if missing or older than 10 minutes
if [ ! -f "$CACHE_FILE" ] || find "$CACHE_FILE" -mmin +10 | grep -q .; then
  curl -s --max-time 8 "$IZIN_URL" -o "$CACHE_FILE"
fi

# Check if IP is registered in license
DATA=$(grep -w "$MYIP" "$CACHE_FILE")
if [ -z "$DATA" ]; then
  echo "❌ IP TIDAK TERDAFTAR"
  rm -f "$USER_FILE" "$EXP_FILE"
  exit 1
fi

# Extract username and expired date
USERNAME=$(awk '{print $2}' <<< "$DATA")
EXPIRED=$(awk '{print $3}' <<< "$DATA")

# Save to local files
echo "$USERNAME" > "$USER_FILE"
echo "$EXPIRED" > "$EXP_FILE"

# Export for other uses
export IP="$MYIP"
export MYIP="$MYIP"

# Get optional info
city="$(curl -fsS --max-time 5 ipinfo.io/city 2>/dev/null | tr -d '\r')"
[ -n "$city" ] && echo "$city" > /etc/xray/city
isp="$(curl -fsS --max-time 5 ipinfo.io/org 2>/dev/null | tr -d '\r' | cut -d' ' -f2-)"
[ -n "$isp" ] && echo "$isp" > /etc/xray/isp

# Display license status
clear
printf '%s\n' \
"━━━━━━━━━━━━━━━━━━━━━━" \
" IZIN SCRIPT AKTIF ✅" \
" USER   : $USERNAME" \
" EXP    : $EXPIRED" \
" IP     : $MYIP" \
" CITY   : $city" \
" ISP    : $isp" \
"━━━━━━━━━━━━━━━━━━━━━━"
sleep 2
clear