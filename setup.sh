#!/bin/bash
# ============================================================
#  PEMASANG INSTALLER ARIVPNSTORES v4 — repo harisprayoga1236-ctrl/izin
#
#  Jalankan di VPS tujuan sebagai root:
#
#      apt update -y && apt install --reinstall wget curl -y \
#        && apt install screen python3-pip -y \
#        && wget -q https://raw.githubusercontent.com/harisprayoga1236-ctrl/izin/main/setup.sh -O /tmp/setup.sh \
#        && chmod +x /tmp/setup.sh \
#        && screen -S setup-session bash -c "/tmp/setup.sh"
#
#  Script ini hanya mengunduh installer lalu menjalankannya di dalam
#  screen. Semua logika instalasi tetap ada di file `install`.
# ============================================================

set -o pipefail

REPO="${REPO:-https://raw.githubusercontent.com/harisprayoga1236-ctrl/izin/main}"
INSTALLER="/tmp/install"

# Pastikan alat yang dibutuhkan ada
for alat in curl wget screen; do
    if ! command -v "$alat" >/dev/null 2>&1; then
        echo "⚠️  $alat belum ada, memasang..."
        apt-get update -qq && apt-get install -y -qq "$alat" >/dev/null 2>&1
    fi
done

if [ "$(id -u)" -ne 0 ]; then
    echo "❌ Jalankan sebagai root."
    exit 1
fi

echo "→ Mengunduh installer dari $REPO/install"

if command -v curl >/dev/null 2>&1; then
    curl -fsSL --max-time 60 "$REPO/install" -o "$INSTALLER" ||
        { echo "❌ Gagal mengunduh installer"; exit 1; }
else
    wget -q "$REPO/install" -O "$INSTALLER" ||
        { echo "❌ Gagal mengunduh installer"; exit 1; }
fi

[ -s "$INSTALLER" ] || { echo "❌ File installer kosong"; exit 1; }
chmod +x "$INSTALLER"

if ! bash -n "$INSTALLER"; then
    echo "❌ Installer rusak (sintaks tidak valid). Dibatalkan."
    exit 1
fi

echo "✔ Installer siap ($(wc -c < "$INSTALLER") byte)"
echo "→ Menjalankan di dalam screen: setup-session"
echo "   (keluar dari screen: Ctrl+A lalu D)"
echo

if [ -n "${STY:-}" ]; then
    # Sudah di dalam screen
    exec bash "$INSTALLER"
else
    exec screen -S setup-session bash "$INSTALLER"
fi
