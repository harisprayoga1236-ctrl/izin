#!/usr/bin/env bash
# Post-install validation and repair for Xray/HAProxy.
set -u

find_xray() {
  local p
  for p in /usr/local/bin/xray /usr/bin/xray /usr/local/sbin/xray; do
    if [ -f "$p" ] && [ -x "$p" ]; then printf '%s\n' "$p"; return 0; fi
  done
  find /usr/local/bin /usr/bin /opt -maxdepth 3 -type f -name xray -perm /111 -print -quit 2>/dev/null
}

xray_bin=$(find_xray || true)
if [ -n "$xray_bin" ]; then
  install -m 0755 "$xray_bin" /usr/local/bin/xray
else
  printf '%s\n' 'ERROR: binary Xray tidak ditemukan; service tidak diaktifkan.' >&2
  exit 1
fi

config=/etc/xray/config.json
if [ ! -s "$config" ]; then
  printf '%s\n' "ERROR: konfigurasi Xray tidak ditemukan: $config" >&2
  exit 1
fi

if ! /usr/local/bin/xray run -test -config "$config"; then
  printf '%s\n' 'ERROR: konfigurasi Xray tidak valid; service tidak diaktifkan.' >&2
  exit 1
fi

cat > /etc/systemd/system/xray.service <<'UNIT'
[Unit]
Description=Xray Service
Documentation=https://github.com/XTLS/Xray-core
After=network.target nss-lookup.target

[Service]
Type=simple
User=www-data
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
systemctl enable xray >/dev/null 2>&1
systemctl restart xray

if command -v haproxy >/dev/null 2>&1 && [ -f /etc/haproxy/haproxy.cfg ]; then
  if [ ! -s /etc/haproxy/hap.pem ] || ! openssl x509 -in /etc/haproxy/hap.pem -noout >/dev/null 2>&1; then
    printf '%s\n' 'WARNING: /etc/haproxy/hap.pem tidak valid; HAProxy tidak diaktifkan.' >&2
    exit 0
  fi
  haproxy -c -f /etc/haproxy/haproxy.cfg
  systemctl restart haproxy
fi

printf '%s\n' 'Xray dan pemeriksaan HAProxy selesai.'
