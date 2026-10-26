#!/bin/bash
# ============================================================
#  Samakan Vpn/xray.zip dengan install
#
#  Vpn/xray.zip hanyalah salinan `install` (nama warisan dari
#  arivpnstores/v4). Jalankan skrip ini setiap kali `install`
#  diperbarui, supaya kedua URL memberi versi yang sama:
#
#      .../izin/main/install
#      .../izin/main/Vpn/xray.zip
#
#  Pemakaian:
#      ./sync-vpn.sh          # salin lalu tampilkan hash
#      ./sync-vpn.sh --check  # hanya periksa, keluar 1 bila beda
# ============================================================

set -o pipefail
cd "$(dirname "$0")" || exit 1

SRC="install"
DST="Vpn/xray.zip"

[ -f "$SRC" ] || { echo "❌ $SRC tidak ada"; exit 1; }
mkdir -p Vpn

if [ "${1:-}" = "--check" ]; then
    if cmp -s "$SRC" "$DST"; then
        echo "✔ Sama"
        exit 0
    fi
    echo "⚠️  Beda — jalankan ./sync-vpn.sh"
    exit 1
fi

cp "$SRC" "$DST" || { echo "❌ Gagal menyalin"; exit 1; }

if cmp -s "$SRC" "$DST"; then
    echo "✔ $DST diperbarui"
    md5sum "$SRC" "$DST"
else
    echo "❌ Hasil salinan tidak identik"
    exit 1
fi
