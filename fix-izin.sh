#!/bin/bash
# License Authorization System
# Owner: harisprayoga1236-ctrl
# Repository: https://github.com/harisprayoga1236-ctrl/izin

IZIN_URL="https://raw.githubusercontent.com/harisprayoga1236-ctrl/izin/main/ip?nocache=$(date +%s)"
CACHE_FILE="/tmp/izin_cache/iplist.txt"
IPSAVE_FILE="/usr/bin/ipsave"
USER_FILE="/usr/bin/user"
EXP_FILE="/usr/bin/e"

# 1. Ambil IP publik VPS secara otomatis
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

# 3. Cari IP spesifik di kolom pertama (abaikan baris kosong & komentar #)
DATA=$(awk -v ip="$MYIP" '$1 == ip {print; exit}' "$CACHE_FILE")

# 4. Jika IP spesifik tidak ditemukan, cek baris ALL
if [ -z "$DATA" ]; then
  DATA=$(awk '$1 == "ALL" {print; exit}' "$CACHE_FILE")
fi

# 5. Jika keduanya tidak ada, tolak
if [ -z "$DATA" ]; then
  echo "❌ IP VPS BELUM TERDAFTAR"
  echo "IP: $MYIP"
  rm -f "$USER_FILE" "$EXP_FILE"
  exit 1
fi

# 6. Ekstrak username (kolom 2) dan expired (kolom 3)
USERNAME=$(echo "$DATA" | awk '{print $2}')
EXPIRED=$(echo "$DATA" | awk '{print $3}')

# 7. Validasi username & expired tidak kosong
if [ -z "$USERNAME" ] || [ -z "$EXPIRED" ]; then
  echo "❌ FORMAT LICENSE TIDAK VALID"
  echo "Baris: $DATA"
  rm -f "$USER_FILE" "$EXP_FILE"
  exit 1
fi

# 8. Validasi format tanggal YYYY-MM-DD
if ! printf '%s' "$EXPIRED" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
  echo "❌ FORMAT LICENSE TIDAK VALID"
  echo "Tanggal: $EXPIRED"
  rm -f "$USER_FILE" "$EXP_FILE"
  exit 1
fi

# 9. Cek expired
if [[ "$EXPIRED" < "$(date +%Y-%m-%d)" ]]; then
  echo "❌ LICENSE SUDAH EXPIRED"
  echo "Expired: $EXPIRED"
  rm -f "$USER_FILE" "$EXP_FILE"
  exit 1
fi

# 10. Simpan license
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
