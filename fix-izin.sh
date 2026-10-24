#!/bin/bash
# ============================================================
#  SISTEM LISENSI ARIVPNSTORES v4 — MODE IP (tanpa secret)
#
#  Cukup mencocokkan alamat IP publik VPS dengan daftar pada file `ip`.
#  Tidak ada signature, tidak butuh secret.
#
#  Format baris lisensi (satu per baris):
#      IP    USER    YYYY-MM-DD
#  atau, berlaku untuk semua IP:
#      ALL   USER    YYYY-MM-DD
#
#  Baris berawalan # diabaikan.
#
#  Catatan keamanan: siapa pun yang dapat menulis ke file `ip` dapat
#  menambahkan IP sendiri. Pasang file `ip` di repo privat bila memungkinkan.
# ============================================================

set -o pipefail

# ------------------------------------------------------------
# KONFIGURASI
# ------------------------------------------------------------
IZIN_URL="${IZIN_URL:-https://raw.githubusercontent.com/harisprayoga1236-ctrl/izin/main/ip}"

CACHE_DIR="/tmp/izin_cache"
CACHE_FILE="$CACHE_DIR/iplist.txt"
IPSAVE_FILE="/usr/bin/ipsave"
USER_FILE="/usr/bin/user"
EXP_FILE="/usr/bin/e"
XRAY_DIR="/etc/xray"
# ------------------------------------------------------------

C_RED=$'\e[91m'; C_GRN=$'\e[92m'; C_YEL=$'\e[93m'; C_RST=$'\e[0m'

ok()   { printf '%s✅ %s%s\n' "$C_GRN" "$*" "$C_RST"; }
warn() { printf '%s⚠️  %s%s\n' "$C_YEL" "$*" "$C_RST"; }
die()  { printf '%s❌ %s%s\n' "$C_RED" "$*" "$C_RST" >&2; revoke; exit 1; }

# Hapus lisensi tersimpan saat verifikasi gagal
revoke() { rm -f "$USER_FILE" "$EXP_FILE"; }

valid_date() {  # YYYY-MM-DD dan tanggalnya benar-benar ada
    printf '%s' "$1" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' || return 1
    date -d "$1" '+%Y-%m-%d' 2>/dev/null | grep -qx "$1"
}

# ------------------------------------------------------------
# Deteksi IP publik
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
# Unduh daftar lisensi
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

    if [ -s "$CACHE_FILE" ] && [ -n "$(find "$CACHE_FILE" -mmin -1440 2>/dev/null)" ]; then
        warn "Tidak bisa menghubungi server lisensi, memakai cache."
        return 0
    fi
    die "GAGAL MENGAMBIL FILE LISENSI (tidak ada koneksi & tidak ada cache)"
}

# Cari baris: IP spesifik diutamakan, lalu ALL
lookup() {
    local ip="$1"
    awk -v ip="$ip" '
        /^[[:space:]]*(#|$)/ { next }
        $1 == ip { print; found=1; exit }
        $1 == "ALL" && allline == "" { allline=$0 }
        END { if (!found && allline != "") print allline }
    ' "$CACHE_FILE"
}

# ------------------------------------------------------------
# MODE: verify (tanpa mengubah sistem)
# ------------------------------------------------------------
cmd_verify() {
    local myip line lic_ip user exp
    myip=$(fetch_ip)
    [ -n "$myip" ] || die "Gagal mengambil IP publik"
    fetch_list
    line=$(lookup "$myip")
    [ -n "$line" ] || die "IP VPS BELUM TERDAFTAR: $myip"

    read -r lic_ip user exp _ <<<"$line"
    valid_date "$exp" || die "FORMAT TANGGAL TIDAK VALID: '$exp'"
    [[ "$exp" < "$(date '+%Y-%m-%d')" ]] && die "LICENSE SUDAH EXPIRED ($exp)"
    ok "Lisensi valid untuk $user sampai $exp (IP: $myip)"
}

# ------------------------------------------------------------
# MODE: install (dipanggil installer)
# ------------------------------------------------------------
cmd_install() {
    local myip line lic_ip user exp city isp today days

    myip=$(fetch_ip)
    [ -n "$myip" ] || die "Gagal mengambil IP publik VPS"
    mkdir -p "$(dirname "$IPSAVE_FILE")"
    printf '%s\n' "$myip" > "$IPSAVE_FILE"

    fetch_list

    line=$(lookup "$myip")
    if [ -z "$line" ]; then
        die "IP VPS BELUM TERDAFTAR
    IP: $myip
    Hubungi admin untuk menambahkan lisensi IP ini."
    fi

    read -r lic_ip user exp _ <<<"$line"

    [ -n "$user" ] && [ -n "$exp" ] ||
        die "FORMAT LICENSE TIDAK VALID (butuh 3 kolom: IP USER TANGGAL)
    Baris: $line"
    valid_date "$exp" || die "FORMAT LICENSE TIDAK VALID (tanggal: '$exp')"

    today=$(date '+%Y-%m-%d')
    if [[ "$exp" < "$today" ]]; then
        die "LICENSE SUDAH EXPIRED
    Expired: $exp"
    fi

    printf '%s\n' "$user" > "$USER_FILE"
    printf '%s\n' "$exp"  > "$EXP_FILE"
    export IP="$myip" MYIP="$myip"

    mkdir -p "$XRAY_DIR"
    city=$(curl -fsS --max-time 5 https://ipinfo.io/city 2>/dev/null | tr -d '\r')
    [ -n "$city" ] && printf '%s\n' "$city" > "$XRAY_DIR/city"
    isp=$(curl -fsS --max-time 5 https://ipinfo.io/org 2>/dev/null | tr -d '\r' | cut -d' ' -f2-)
    [ -n "$isp" ] && printf '%s\n' "$isp" > "$XRAY_DIR/isp"

    printf '%s\n' "━━━━━━━━━━━━━━━━━━━━━━"
    printf ' IZIN SCRIPT AKTIF ✅\n'
    printf ' USER   : %s\n' "$user"
    printf ' EXP    : %s\n' "$exp"
    printf ' IP     : %s\n' "$myip"
    printf ' CITY   : %s\n' "$city"
    printf ' ISP    : %s\n' "$isp"
    printf ' MODE   : %s\n' "$([ "$lic_ip" = "ALL" ] && echo 'ALL' || echo 'IP Khusus')"
    printf '%s\n' "━━━━━━━━━━━━━━━━━━━━━━"

    days=$(( ( $(date -d "$exp" +%s) - $(date -d "$today" +%s) ) / 86400 ))
    [ "$days" -le 7 ] && warn "Lisensi habis dalam $days hari ($exp). Segera perpanjang."
    return 0
}

# ------------------------------------------------------------
# Main
# ------------------------------------------------------------
case "${1:-install}" in
    verify)  cmd_verify ;;
    install) cmd_install ;;
    *)
        echo "Pemakaian: $0 [install|verify]"
        exit 2
        ;;
esac
