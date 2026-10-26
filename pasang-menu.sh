#!/bin/bash
# ============================================================
#  Pasang menu Arivpnstores v4 ke VPS
#
#  Kenapa skrip ini ada:
#  Installer memanggil update.sh milik arivpnstores untuk memasang menu.
#  update.sh itu (a) butuh 7z, (b) menyembunyikan semua error, dan
#  (c) mengaktifkan notifikasi Telegram. Skrip ini melakukan bagian yang
#  perlu saja: unduh menu.zip, verifikasi, ekstrak, pasang ke /usr/bin.
#
#  Pemakaian:
#      ./pasang-menu.sh              # pasang / perbarui
#      ./pasang-menu.sh --cek        # hanya periksa prasyarat
#      ./pasang-menu.sh --hapus      # cabut menu
#
#  Aman dijalankan berulang.
# ============================================================

set -euo pipefail

readonly SUMBER="https://raw.githubusercontent.com/arivpnstores/v4/main/Cdy/menu.zip"
readonly ARSIP_PASS="HeyHeyMauDecryptYaAwokawokARISTORE"
readonly TUJUAN="/usr/bin"
readonly KERJA="/tmp/pasang-menu.$$"

MERAH=$'\e[91m'; HIJAU=$'\e[92m'; KUNING=$'\e[93m'; RESET=$'\e[0m'

info()  { printf '%s→%s %s\n' "$KUNING" "$RESET" "$*"; }
ok()    { printf '%s✔%s %s\n' "$HIJAU" "$RESET" "$*"; }
gagal() { printf '%s✘%s %s\n' "$MERAH" "$RESET" "$*" >&2; }

bersihkan() {
    rm -rf "$KERJA"
}
trap bersihkan EXIT

# ------------------------------------------------------------
# Prasyarat
# ------------------------------------------------------------
butuh_root() {
    if [ "$(id -u)" -ne 0 ]; then
        gagal "Jalankan sebagai root."
        exit 1
    fi
}

punya_7z() {
    command -v 7z >/dev/null 2>&1 || command -v 7za >/dev/null 2>&1 || command -v 7zr >/dev/null 2>&1
}

pasang_7z() {
    if punya_7z; then
        return 0
    fi
    info "Memasang p7zip-full..."
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update -qq
        DEBIAN_FRONTEND=noninteractive apt-get install -y -qq p7zip-full
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y p7zip
    elif command -v yum >/dev/null 2>&1; then
        yum install -y p7zip
    fi

    if ! punya_7z; then
        gagal "7z masih tidak ada setelah pemasangan. Pasang p7zip-full manual."
        exit 1
    fi
}

# Menu memakai jq untuk membaca JSON Xray. Tanpa jq, menu tampil tetapi
# beberapa baris galat muncul di awal.
pasang_jq() {
    if command -v jq >/dev/null 2>&1; then
        return 0
    fi
    info "Memasang jq..."
    if command -v apt-get >/dev/null 2>&1; then
        DEBIAN_FRONTEND=noninteractive apt-get install -y -qq jq
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y jq
    elif command -v yum >/dev/null 2>&1; then
        yum install -y jq
    fi

    if ! command -v jq >/dev/null 2>&1; then
        printf '%s⚠%s jq tidak terpasang — sebagian tampilan menu bisa galat.\n' "$KUNING" "$RESET"
    fi
}

untuk_7z() {
    if command -v 7z >/dev/null 2>&1; then
        echo 7z
    elif command -v 7za >/dev/null 2>&1; then
        echo 7za
    else
        echo 7zr
    fi
}

# ------------------------------------------------------------
# Periksa saja
# ------------------------------------------------------------
mode_cek() {
    local siap=0

    printf '%-28s' "root:"
    if [ "$(id -u)" -eq 0 ]; then ok "ya"; else gagal "tidak"; siap=1; fi

    printf '%-28s' "7z:"
    if punya_7z; then
        ok "$(command -v "$(untuk_7z)")"
    else
        gagal "belum ada"; siap=1
    fi

    printf '%-28s' "jq:"
    if command -v jq >/dev/null 2>&1; then
        ok "ada"
    else
        gagal "belum ada"; siap=1
    fi

    printf '%-28s' "wget/curl:"
    if command -v wget >/dev/null 2>&1 || command -v curl >/dev/null 2>&1; then
        ok "ada"
    else
        gagal "tidak ada"; siap=1
    fi

    printf '%-28s' "menu terpasang:"
    if [ -x "$TUJUAN/menu" ]; then ok "ya"; else printf 'belum\n'; fi

    printf '%-28s' "koneksi sumber:"
    local kode
    if command -v curl >/dev/null 2>&1; then
        kode=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 "$SUMBER" || echo 000)
    else
        kode=$(wget -q --server-response --spider --timeout=20 "$SUMBER" 2>&1 | awk '/HTTP\//{c=$2} END{print c+0}')
    fi
    if [ "${kode:-0}" = "200" ]; then ok "HTTP $kode"; else gagal "HTTP $kode"; siap=1; fi

    echo
    if [ "$siap" -eq 0 ]; then
        printf '%sSiap dipasang.%s Jalankan: %s./pasang-menu.sh%s\n' "$HIJAU" "$RESET" "$KUNING" "$RESET"
    else
        printf '%sAda prasyarat kurang.%s Installer akan memasangnya otomatis — jalankan %s./pasang-menu.sh%s\n' \
            "$KUNING" "$RESET" "$HIJAU" "$RESET"
    fi

    return "$siap"
}

# ------------------------------------------------------------
# Unduh
# ------------------------------------------------------------
unduh() {
    local tujuan="$1"

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --max-time 120 "$SUMBER" -o "$tujuan"
    elif command -v wget >/dev/null 2>&1; then
        wget -q --timeout=120 "$SUMBER" -O "$tujuan"
    else
        gagal "Tidak ada wget/curl."
        exit 1
    fi
}

# ------------------------------------------------------------
# Pasang
# ------------------------------------------------------------
mode_pasang() {
    butuh_root
    pasang_7z
    pasang_jq
    mkdir -p "$KERJA"

    info "Mengunduh menu.zip..."
    if ! unduh "$KERJA/menu.zip"; then
        gagal "Unduhan gagal. Periksa koneksi."
        exit 1
    fi

    local ukuran
    ukuran=$(stat -c %s "$KERJA/menu.zip" 2>/dev/null || echo 0)
    if [ "$ukuran" -lt 100000 ]; then
        gagal "Berkas terlalu kecil ($ukuran byte) — kemungkinan halaman error, bukan zip."
        exit 1
    fi
    ok "Terunduh $ukuran byte"

    # Pastikan benar-benar arsip zip sebelum diekstrak
    if command -v file >/dev/null 2>&1; then
        if ! file "$KERJA/menu.zip" | grep -qi 'zip archive'; then
            gagal "Berkas bukan arsip zip yang sah."
            exit 1
        fi
    fi

    info "Mengekstrak..."
    local alat
    alat=$(untuk_7z)
    if ! "$alat" x "-p$ARSIP_PASS" "$KERJA/menu.zip" "-o$KERJA/isi" >"$KERJA/7z.log" 2>&1; then
        gagal "Ekstraksi gagal. Log:"
        tail -5 "$KERJA/7z.log" >&2
        exit 1
    fi

    if [ ! -d "$KERJA/isi/menu" ]; then
        gagal "Folder menu/ tidak ditemukan setelah ekstraksi."
        exit 1
    fi

    local jumlah
    jumlah=$(find "$KERJA/isi/menu" -maxdepth 1 -type f | wc -l)
    if [ "$jumlah" -lt 10 ]; then
        gagal "Hanya $jumlah berkas terbaca — hasil ekstraksi tidak lengkap."
        exit 1
    fi
    ok "$jumlah berkas diekstrak"

    # Tolak berkas yang bukan skrip
    local bukan_skrip=0
    while IFS= read -r -d '' berkas; do
        if command -v file >/dev/null 2>&1 && ! file -b "$berkas" | grep -qi 'script\|text'; then
            printf '  %s dilewati (bukan skrip)\n' "$(basename "$berkas")"
            bukan_skrip=$((bukan_skrip + 1))
        fi
    done < <(find "$KERJA/isi/menu" -maxdepth 1 -type f -print0)

    info "Memasang ke $TUJUAN..."
    local dipasang=0
    while IFS= read -r -d '' berkas; do
        local nama
        nama=$(basename "$berkas")
        if [ -e "$TUJUAN/$nama" ] && [ ! -x "$TUJUAN/$nama" ]; then
            cp -a "$TUJUAN/$nama" "$TUJUAN/$nama.bak.$(date +%s)"
        fi
        if install -m 0755 "$berkas" "$TUJUAN/$nama"; then
            dipasang=$((dipasang + 1))
        else
            printf '  %s gagal dipasang\n' "$nama"
        fi
    done < <(find "$KERJA/isi/menu" -maxdepth 1 -type f -print0)

    ok "$dipasang berkas dipasang"

    if [ ! -x "$TUJUAN/menu" ]; then
        gagal "Perintah 'menu' tetap tidak ada. Periksa isi menu.zip."
        exit 1
    fi

    printf '%s' "$(date +%Y-%m-%d)" > "$TUJUAN/menu_version"
    ok "menu_version diisi tanggal"

    echo
    ok "Selesai. Jalankan: menu"
}

# ------------------------------------------------------------
# Hapus
# ------------------------------------------------------------
mode_hapus() {
    butuh_root
    info "Mencabut menu..."

    local jumlah=0
    if [ -d "$KERJA" ]; then
        rm -rf "$KERJA"
    fi
    mkdir -p "$KERJA"

    # Daftar nama diambil dari arsip, supaya tidak salah hapus berkas lain
    if unduh "$KERJA/menu.zip" 2>/dev/null && punya_7z; then
        if "$(untuk_7z)" l "$KERJA/menu.zip" >"$KERJA/list.txt" 2>&1; then
            while IFS= read -r nama; do
                [ -n "$nama" ] || continue
                case "$nama" in
                    */*) continue ;;
                    *.bak.*) continue ;;
                esac
                if [ -f "$TUJUAN/$nama" ]; then
                    rm -f "$TUJUAN/$nama" && jumlah=$((jumlah + 1))
                fi
            done < <(sed -n 's#^.*menu/##p' "$KERJA/list.txt" | sort -u)
        fi
    else
        printf '%s\n' "Tidak bisa mengunduh daftar menu; hapus /usr/bin/menu manual bila perlu." >&2
    fi

    rm -f "$TUJUAN/menu_version"
    ok "$jumlah berkas dicabut"
}

# ------------------------------------------------------------
# Main
# ------------------------------------------------------------
case "${1:-pasang}" in
    --cek|cek)      mode_cek; exit $? ;;
    --hapus|hapus)  mode_hapus ;;
    -h|--help)
        sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'
        ;;
    *)
        mode_pasang
        ;;
esac
