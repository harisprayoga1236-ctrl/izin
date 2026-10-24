#!/bin/bash
# ============================================================
#  SISTEM LISENSI ARIVPNSTORES v4  (HMAC-SHA256)
#  Pengganti: https://raw.githubusercontent.com/arivpnstores/v4/main/fix-izin.sh
#
#  Format baris lisensi (satu lisensi per baris):
#      IP  USER  YYYY-MM-DD  SIGNATURE
#  atau fallback untuk semua IP:
#      ALL USER  YYYY-MM-DD  SIGNATURE
#
#  SIGNATURE = HEX HMAC-SHA256 dari string:  "IP|USER|EXPIRED"
#
#  Membuat baris lisensi (jalankan di komputer Anda):
#      ./fix-izin.sh sign <IP|ALL> <USER> <YYYY-MM-DD>
#
#  Verifikasi tanpa mengubah sistem:
#      ./fix-izin.sh verify
# ============================================================

set -o pipefail

# ------------------------------------------------------------
# KONFIGURASI  (ubah di sini saja)
# ------------------------------------------------------------
IZIN_URL="https://raw.githubusercontent.com/harisprayoga1236-ctrl/izin/main/ip"
# SECRET dibaca dari, berurutan:
#   1) variabel environment IZIN_SECRET
#   2) file /etc/izin-secret  (mode 600, dibuat saat instalasi)
# JANGAN menulis secret langsung di file ini kalau file diunggah ke repo public.
SECRET="${IZIN_SECRET:-}"
if [ -z "$SECRET" ] && [ -r /etc/izin-secret ]; then
    SECRET=$(tr -d '[:space:]' < /etc/izin-secret)
fi

CACHE_DIR="/tmp/izin_cache"
CACHE_FILE="$CACHE_DIR/iplist.txt"
CACHE_TTL_MIN=10

IPSAVE_FILE="/usr/bin/ipsave"
USER_FILE="/usr/bin/user"
EXP_FILE="/usr/bin/e"
XRAY_DIR="/etc/xray"
# ------------------------------------------------------------

C_RED=$'\e[91m'; C_GRN=$'\e[92m'; C_YEL=$'\e[93m'; C_DIM=$'\e[2m'; C_RST=$'\e[0m'

ok()   { printf '%s✅ %s%s\n' "$C_GRN" "$*" "$C_RST"; }
warn() { printf '%s⚠️  %s%s\n' "$C_YEL" "$*" "$C_RST"; }
die()  { printf '%s❌ %s%s\n' "$C_RED" "$*" "$C_RST" >&2; revoke; exit 1; }

# Hapus lisensi tersimpan saat verifikasi gagal (sama seperti script lama)
revoke() {
    rm -f "$USER_FILE" "$EXP_FILE"
}

need_openssl() {
    command -v openssl >/dev/null 2>&1 || die "openssl tidak ditemukan, jalankan: apt install -y openssl"
}

# ------------------------------------------------------------
# Fungsi kriptografi
# ------------------------------------------------------------
sign_line() {  # sign_line IP USER EXPIRED
    printf '%s' "$1|$2|$3" | openssl dgst -sha256 -hmac "$SECRET" -r 2>/dev/null | cut -d' ' -f1
}

verify_line() {  # verify_line IP USER EXPIRED SIG  -> 0 jika valid
    local expected actual
    expected=$(sign_line "$1" "$2" "$3")
    actual=$(printf '%s' "$4" | tr 'A-Z' 'a-z')
    [ -n "$expected" ] && [ "$expected" = "$actual" ]
}

valid_date() {  # valid_date YYYY-MM-DD  (dan tanggalnya benar-benar ada)
    printf '%s' "$1" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' || return 1
    date -d "$1" '+%Y-%m-%d' 2>/dev/null | grep -qx "$1"
}

# ------------------------------------------------------------
# Deteksi IP publik (3 sumber, semua dengan timeout)
# ------------------------------------------------------------
fetch_ip() {
    local ip
    ip=$(curl -fsS --max-time 5 https://ipv4.icanhazip.com 2>/dev/null) ||
    ip=$(curl -fsS --max-time 5 https://ifconfig.me/ip 2>/dev/null) ||
    ip=$(curl -fsS --max-time 5 https://api.ipify.org 2>/dev/null) ||
    ip=$(wget -qO- --timeout=5 https://ipinfo.io/ip 2>/dev/null)
    printf '%s' "$ip" | tr -d '[:space:]'
}

# ------------------------------------------------------------
# Unduh daftar lisensi (selalu segar, cache hanya utk cadangan)
# ------------------------------------------------------------
fetch_list() {
    mkdir -p "$CACHE_DIR"
    local tmp="$CACHE_FILE.tmp.$$"

    if curl -fsS --max-time 10 -H 'Cache-Control: no-cache' \
            -H "User-Agent: izin-check" "$IZIN_URL" -o "$tmp" && [ -s "$tmp" ]; then
        mv -f "$tmp" "$CACHE_FILE"
        return 0
    fi
    rm -f "$tmp"

    # Gagal jaringan: pakai cache lama kalau masih ada (maks 24 jam)
    if [ -s "$CACHE_FILE" ] && [ -n "$(find "$CACHE_FILE" -mmin -1440 2>/dev/null)" ]; then
        warn "Tidak bisa menghubungi server lisensi, memakai cache ($(du -h "$CACHE_FILE" | cut -f1))."
        return 0
    fi
    die "GAGAL MENGAMBIL FILE LISENSI (tidak ada koneksi & tidak ada cache)"
}

# Cari baris yang cocok: IP spesifik dulu, lalu ALL
lookup() {  # lookup MYIP
    local ip="$1" line
    line=$(awk -v ip="$ip" '
        /^[[:space:]]*(#|$)/ { next }
        $1 == ip { print; found=1; exit }
        $1 == "ALL" && allline == "" { allline=$0 }
        END { if (!found && allline != "") print allline }
    ' "$CACHE_FILE")
    printf '%s' "$line"
}

# ------------------------------------------------------------
# MODE: sign
# ------------------------------------------------------------
cmd_sign() {
    local ip="$1" user="$2" exp="$3"
    [ -n "$SECRET" ] || die "IZIN_SECRET belum diset. Set secret dulu (lihat panduan di bawah)."
    valid_date "$exp" || die "Tanggal tidak valid: '$exp' (format YYYY-MM-DD)"
    [ -n "$user" ] || die "Username kosong"
    printf '%-16s %-12s %-12s %s\n' "$ip" "$user" "$exp" "$(sign_line "$ip" "$user" "$exp")"
}

# ------------------------------------------------------------
# MODE: verify saja (tidak menulis file lisensi)
# ------------------------------------------------------------
cmd_verify() {
    local myip line user exp sig verify_ip
    need_openssl
    myip=$(fetch_ip)
    [ -n "$myip" ] || die "Gagal mengambil IP publik"
    fetch_list
    line=$(lookup "$myip")
    [ -n "$line" ] || die "IP VPS BELUM TERDAFTAR: $myip"

    read -r verify_ip user exp sig _ <<<"$line"
    verify_line "$verify_ip" "$user" "$exp" "$sig" || die "SIGNATURE TIDAK VALID untuk baris lisensi ini"
    ok "Lisensi valid untuk $user sampai $exp"
}

# ------------------------------------------------------------
# MODE: install (dipanggil installer)
# ------------------------------------------------------------
cmd_install() {
    local myip line lic_ip user exp sig city isp today

    need_openssl

    # 1) IP publik
    myip=$(fetch_ip)
    [ -n "$myip" ] || die "Gagal mengambil IP publik VPS"
    mkdir -p "$(dirname "$IPSAVE_FILE")"
    printf '%s\n' "$myip" > "$IPSAVE_FILE"

    # 2) Daftar lisensi
    fetch_list

    # 3) Cari lisensi untuk IP ini
    line=$(lookup "$myip")
    if [ -z "$line" ]; then
        die "IP VPS BELUM TERDAFTAR
    IP: $myip
    Hubungi admin untuk menambahkan lisensi IP ini."
    fi

    read -r lic_ip user exp sig _ <<<"$line"

    # 4) Validasi format
    [ -n "$user" ] && [ -n "$exp" ] && [ -n "$sig" ] ||
        die "FORMAT LICENSE TIDAK VALID (butuh 4 kolom: IP USER TANGGAL SIGNATURE)
    Baris: $line"
    valid_date "$exp" || die "FORMAT LICENSE TIDAK VALID (tanggal: '$exp')"

    # 5) Signature — inti Sistem HMAC
    [ -n "$SECRET" ] || die "SECRET LISENSI TIDAK DIKONFIGURASI DI SERVER INI"
    verify_line "$lic_ip" "$user" "$exp" "$sig" ||
        die "SIGNATURE LISENSI TIDAK VALID (file lisensi mungkin dipalsukan)"

    # 6) Masa berlaku
    today=$(date '+%Y-%m-%d')
    if [[ "$exp" < "$today" ]]; then
        die "LICENSE SUDAH EXPIRED
    Expired: $exp"
    fi

    # 7) Simpan lisensi (format sama dengan script lama: /usr/bin/user, /usr/bin/e)
    printf '%s\n' "$user" > "$USER_FILE"
    printf '%s\n' "$exp"  > "$EXP_FILE"
    export IP="$myip" MYIP="$myip"

    # 8) Info tambahan yang dipakai installer (city & isp)
    mkdir -p "$XRAY_DIR"
    city=$(curl -fsS --max-time 5 https://ipinfo.io/city 2>/dev/null | tr -d '\r')
    [ -n "$city" ] && printf '%s\n' "$city" > "$XRAY_DIR/city"
    isp=$(curl -fsS --max-time 5 https://ipinfo.io/org 2>/dev/null | tr -d '\r' | cut -d' ' -f2-)
    [ -n "$isp" ] && printf '%s\n' "$isp" > "$XRAY_DIR/isp"

    # 9) Tampilkan (jangan bersihkan layar agar terlihat di log screen)
    printf '%s\n' "━━━━━━━━━━━━━━━━━━━━━━"
    printf ' IZIN SCRIPT AKTIF ✅\n'
    printf ' USER   : %s\n' "$user"
    printf ' EXP    : %s\n' "$exp"
    printf ' IP     : %s\n' "$myip"
    printf ' CITY   : %s\n' "$city"
    printf ' ISP    : %s\n' "$isp"
    printf ' MODE   : %s\n' "$([ "$lic_ip" = "ALL" ] && echo 'ALL' || echo 'IP Khusus')"
    printf '%s\n' "━━━━━━━━━━━━━━━━━━━━━━"

    local days
    days=$(( ( $(date -d "$exp" +%s) - $(date -d "$today" +%s) ) / 86400 ))
    if [ "$days" -le 7 ]; then
        warn "Lisensi habis dalam $days hari ($exp). Segera perpanjang."
    fi
}

# ------------------------------------------------------------
# Main
# ------------------------------------------------------------
case "${1:-install}" in
    sign)
        [ $# -eq 4 ] || { echo "Pemakaian: $0 sign <IP|ALL> <USER> <YYYY-MM-DD>"; exit 2; }
        cmd_sign "$2" "$3" "$4"
        ;;
    verify)  cmd_verify ;;
    install) cmd_install ;;
    *)
        echo "Pemakaian: $0 [install|verify|sign <IP|ALL> <USER> <YYYY-MM-DD>]"
        exit 2
        ;;
esac
