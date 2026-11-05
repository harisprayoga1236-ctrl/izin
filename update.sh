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

install_xray_binary() {
  local meta="$TMP_DIR/xray-release.json" asset_url digest_url archive="$TMP_DIR/xray.zip"
  printf '%s\n' 'Mengunduh binary Xray resmi...'
  curl -fsSL --max-time 30 https://api.github.com/repos/XTLS/Xray-core/releases/latest -o "$meta"
  read -r asset_url digest_url < <(python3 -I - "$meta" <<'PY'
import json, sys
release=json.load(open(sys.argv[1]))
urls={a['name']: a['browser_download_url'] for a in release['assets']}
print(urls.get('Xray-linux-64.zip',''), urls.get('Xray-linux-64.zip.dgst',''))
PY
)
  [ -n "$asset_url" ] && [ -n "$digest_url" ] || { printf '%s\n' 'ERROR: aset Xray Linux x64 tidak ditemukan.' >&2; return 1; }
  curl -fsSL --max-time 120 "$asset_url" -o "$archive"
  curl -fsSL --max-time 30 "$digest_url" -o "$TMP_DIR/xray.dgst"
  local expected actual
  expected=$(awk -F'= ' '/^SHA2-256=/{print $2}' "$TMP_DIR/xray.dgst")
  actual=$(sha256sum "$archive" | awk '{print $1}')
  [ -n "$expected" ] && [ "$expected" = "$actual" ] || { printf '%s\n' 'ERROR: checksum binary Xray tidak cocok.' >&2; return 1; }
  mkdir -p "$TMP_DIR/xray-extracted"
  python3 -I - "$archive" "$TMP_DIR/xray-extracted" <<'PY'
import sys
from pathlib import Path
from zipfile import ZipFile
src=Path(sys.argv[1]); out=Path(sys.argv[2]); out.mkdir(parents=True, exist_ok=True)
with ZipFile(src) as z: z.extractall(out)
PY
  [ -x "$TMP_DIR/xray-extracted/xray" ] || chmod 755 "$TMP_DIR/xray-extracted/xray"
  install -m 0755 "$TMP_DIR/xray-extracted/xray" /usr/local/bin/xray
  install -m 0644 "$TMP_DIR/xray-extracted/geoip.dat" /usr/local/bin/geoip.dat
  install -m 0644 "$TMP_DIR/xray-extracted/geosite.dat" /usr/local/bin/geosite.dat
  printf '%s\n' 'Binary Xray terpasang dan checksum terverifikasi.'
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

if [ "${INSTALL_XRAY:-1}" = 1 ]; then
  install_xray_binary
fi

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
