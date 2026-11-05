#!/usr/bin/env bash
# Validasi dan perbaikan service Xray/HAProxy setelah update.
set -Eeuo pipefail

readonly XRAY_BIN=/usr/local/bin/xray
readonly XRAY_CONFIG=/etc/xray/config.json
readonly XRAY_ASSET_DIR=/usr/local/share/xray
readonly XRAY_UNIT=/etc/systemd/system/xray.service

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

[ "${EUID:-$(id -u)}" -eq 0 ] || fail 'skrip harus dijalankan sebagai root.'
[ -x "$XRAY_BIN" ] || fail "binary Xray tidak ditemukan: $XRAY_BIN"
[ -s "$XRAY_CONFIG" ] || fail "konfigurasi tidak ditemukan: $XRAY_CONFIG"

install -d -m 0755 "$XRAY_ASSET_DIR"
for asset in geoip.dat geosite.dat; do
  [ -s "/usr/local/bin/$asset" ] || fail "asset Xray tidak ditemukan: /usr/local/bin/$asset"
  if [ "/usr/local/bin/$asset" != "$XRAY_ASSET_DIR/$asset" ]; then
    install -m 0644 "/usr/local/bin/$asset" "$XRAY_ASSET_DIR/$asset"
  fi
done

export XRAY_LOCATION_ASSET="$XRAY_ASSET_DIR"
"$XRAY_BIN" run -test -config "$XRAY_CONFIG" || fail 'konfigurasi Xray tidak valid.'

install -d -m 0755 "$(dirname "$XRAY_UNIT")"
if [ -f "$XRAY_UNIT" ]; then
  cp -a "$XRAY_UNIT" "$XRAY_UNIT.bak.$(date +%Y%m%d-%H%M%S)"
fi
cat > "$XRAY_UNIT" <<'UNIT'
[Unit]
Description=Xray Service
Documentation=https://github.com/XTLS/Xray-core
After=network.target nss-lookup.target

[Service]
Type=simple
User=www-data
Environment=XRAY_LOCATION_ASSET=/usr/local/share/xray
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/xray run -config /etc/xray/config.json
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable xray >/dev/null
systemctl restart xray
systemctl is-active --quiet xray || fail 'service Xray gagal aktif; lihat journalctl -u xray.'

if command -v haproxy >/dev/null 2>&1 && [ -f /etc/haproxy/haproxy.cfg ]; then
  if [ ! -s /etc/haproxy/hap.pem ] || ! openssl x509 -in /etc/haproxy/hap.pem -noout >/dev/null 2>&1; then
    printf '%s\n' 'PERINGATAN: hap.pem tidak valid; HAProxy tidak direstart.' >&2
  elif haproxy -c -f /etc/haproxy/haproxy.cfg >/dev/null; then
    systemctl restart haproxy
    systemctl is-active --quiet haproxy || printf '%s\n' 'PERINGATAN: HAProxy gagal aktif.' >&2
  else
    printf '%s\n' 'PERINGATAN: konfigurasi HAProxy tidak valid; tidak direstart.' >&2
  fi
fi

printf '%s\n' 'Xray berhasil divalidasi dan dijalankan; pemeriksaan HAProxy selesai.'
