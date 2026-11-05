#!/usr/bin/env bash
# Update aman untuk repository izin.
# Tidak menjalankan installer penuh dan tidak mengunduh update.sh dari upstream.
set -Eeuo pipefail

REPO_URL="${REPO_URL:-https://raw.githubusercontent.com/harisprayoga1236-ctrl/izin/main}"
TMP_DIR="$(mktemp -d /tmp/izin-update.XXXXXX)"
BACKUP_DIR="/var/backups/izin-update-$(date +%Y%m%d-%H%M%S)"
trap 'rm -rf "$TMP_DIR"' EXIT

cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  printf '%s\n' 'ERROR: jalankan sebagai root.' >&2
  exit 1
fi

fetch() {
  local name="$1" dest="$2"
  curl -fsSL --max-time 30 -H 'Cache-Control: no-cache' "$REPO_URL/$name" -o "$dest"
  [ -s "$dest" ] || { printf 'ERROR: unduhan kosong: %s\n' "$name" >&2; exit 1; }
}

printf '%s\n' 'Memeriksa lisensi...'
fetch fix-izin.sh "$TMP_DIR/fix-izin.sh"
chmod 700 "$TMP_DIR/fix-izin.sh"
bash -n "$TMP_DIR/fix-izin.sh"
bash "$TMP_DIR/fix-izin.sh" verify

printf '%s\n' 'Mengunduh file update dari repository ini...'
fetch install "$TMP_DIR/install"
fetch Vpn/xray.zip "$TMP_DIR/xray.zip"
fetch repair-services.sh "$TMP_DIR/repair-services.sh"
chmod 700 "$TMP_DIR/install" "$TMP_DIR/xray.zip" "$TMP_DIR/repair-services.sh"
bash -n "$TMP_DIR/install"
bash -n "$TMP_DIR/xray.zip"
bash -n "$TMP_DIR/repair-services.sh"

if ! cmp -s "$TMP_DIR/install" "$TMP_DIR/xray.zip"; then
  printf '%s\n' 'ERROR: install dan Vpn/xray.zip berbeda; update dibatalkan.' >&2
  exit 1
fi

install -d -m 700 "$BACKUP_DIR"
for f in /usr/local/bin/izin-install /usr/local/bin/izin-xray.zip /usr/local/bin/izin-repair-services; do
  [ -e "$f" ] && cp -a "$f" "$BACKUP_DIR/"
done

install -m 755 "$TMP_DIR/install" /usr/local/bin/izin-install
install -m 755 "$TMP_DIR/xray.zip" /usr/local/bin/izin-xray.zip
install -m 755 "$TMP_DIR/repair-services.sh" /usr/local/bin/izin-repair-services
install -m 755 "$TMP_DIR/fix-izin.sh" /usr/local/bin/izin-fix-license

printf '%s\n' 'File updater berhasil diperbarui.'
printf 'Backup: %s\n' "$BACKUP_DIR"
printf '%s\n' 'Catatan: installer penuh tidak dijalankan otomatis.'

if systemctl list-unit-files xray.service >/dev/null 2>&1 && [ -f /etc/xray/config.json ]; then
  printf '%s\n' 'Memeriksa service Xray yang sudah terpasang...'
  if /usr/local/bin/izin-repair-services; then
    printf '%s\n' 'Service Xray/HAProxy selesai diperiksa.'
  else
    printf '%s\n' 'Peringatan: service tidak diubah karena binary atau konfigurasi belum siap.' >&2
  fi
else
  printf '%s\n' 'Service Xray belum terpasang; tahap perbaikan dilewati.'
fi

printf '%s\n' 'Update selesai.'
