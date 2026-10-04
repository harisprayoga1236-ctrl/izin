#!/bin/bash
# License Authorization System
# Owner: harisprayoga1236-ctrl
# Repository: https://github.com/harisprayoga1236-ctrl/izin

IZIN_URL="https://raw.githubusercontent.com/harisprayoga1236-ctrl/izin/main/ip?nocache=$(date +%s)"
CACHE_FILE="/tmp/izin_cache/iplist.txt"
IPSAVE_FILE="/usr/bin/ipsave"
USER_FILE="/usr/bin/user"
EXP_FILE="/usr/bin/e"

# 1. Ambil IP publik VPS
MYIP=$(
  curl -fsS --max-time 5 https://ipv4.icanhazip.com 2>/dev/null ||
  curl -fsS --max-time 5 https://ifconfig.me/ip 2>/dev/null ||
  wget -qO- --timeout=5 https://ipinfo.io/ip 2>/dev/null
)
MYIP=$(printf '%s' "$MYIP" | tr -d '[:space:]')

if [ -z "$MYIP" ]; then
  echo "❌ Gagal mengambil IP"
  exit 1
fi
echo "$MYIP" > "$IPSAVE_FILE"

# 2. Selalu download file license terbaru (cache-busting, tanpa cache lama)
mkdir -p "$(dirname "$CACHE_FILE")"
if ! curl -fsS --max-time 10 "$IZIN_URL" -o "$CACHE_FILE" || [ ! -s "$CACHE_FILE" ]; then
  rm -f "$CACHE_FILE"
  echo "❌ GAGAL MENGAMBIL FILE LICENSE"
  exit 1
fi

# 3. Cocokkan kolom pertama dengan IP VPS (abaikan baris kosong & komentar #)
DATA=""
while IFS= read -r line || [ -n "$line" ]; do
  line=$(printf '%s' "$line" | tr -d '\r')
  case "$line" in
    ''|\#*) continue ;;
  esac
  set -- $line
  if [ "$1" = "$MYIP" ]; then
    DATA="$line"
    break
  fi
done < "$CACHE_FILE"

if [ -z "$DATA" ]; then
  echo "❌ IP VPS BELUM TERDAFTAR"
  echo "IP: $MYIP"
  rm -f "$USER_FILE" "$EXP_FILE"
  exit 1
fi

# 4. Ambil username (kolom 2) dan tanggal expired (kolom 3)
set -- $DATA
USERNAME="$2"
EXPIRED="$3"

if [ -z "$USERNAME" ] || [ -z "$EXPIRED" ]; then
  echo "❌ Format license tidak valid"
  echo "Baris: $DATA"
  rm -f "$USER_FILE" "$EXP_FILE"
  exit 1
fi

# 5. Validasi tanggal expired (format YYYY-MM-DD)
if ! printf '%s' "$EXPIRED" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
  echo "❌ Format tanggal expired tidak valid: $EXPIRED"
  rm -f "$USER_FILE" "$EXP_FILE"
  exit 1
fi

if [[ "$EXPIRED" < "$(date +%Y-%m-%d)" ]]; then
  echo "❌ LICENSE SUDAH EXPIRED"
  echo "Expired: $EXPIRED"
  rm -f "$USER_FILE" "$EXP_FILE"
  exit 1
fi

# 6. Simpan license
echo "$USERNAME" > "$USER_FILE"
echo "$EXPIRED" > "$EXP_FILE"
export IP="$MYIP"
export MYIP="$MYIP"

clear
printf '%s\n' \
"━━━━━━━━━━━━━━━━━━━━━━" \
" IZIN SCRIPT AKTIF ✅" \
" USER   : $USERNAME" \
" EXP    : $EXPIRED" \
" IP     : $MYIP" \
"━━━━━━━━━━━━━━━━━━━━━━"
sleep 2
clear
