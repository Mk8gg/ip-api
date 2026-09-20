#!/usr/bin/env bash
set -euo pipefail

RAW="https://raw.githubusercontent.com/Mk8gg/ip-api/master"
CONFIG="/etc/sing-box/config.json"
ECH="/etc/sing-box/ech"
CERT="/var/lib/sing-box/certmagic"
PANEL="/opt/hy2-panel"
PORT="${PANEL_PORT:-18080}"

[ "$(id -u)" = 0 ] || { echo "请使用 root"; exit 1; }
read -r -p "域名: " DOMAIN
[ -n "$DOMAIN" ] || exit 1
read -r -p "Hy2 密码（留空自动生成）: " PASS
PASS="${PASS:-$(cat /proc/sys/kernel/random/uuid)}"
read -r -p "面板端口 [18080]: " P
PORT="${P:-18080}"

curl -fsSL https://sing-box.app/install.sh | sh
mkdir -p "$ECH" "$CERT" "$PANEL"
chown -R sing-box:sing-box "$ECH" "$CERT"
chmod 700 "$ECH" "$CERT"

sing-box generate ech-keypair "$DOMAIN" > "$ECH/ech.txt"
sed -n '/-----BEGIN ECH KEYS-----/,/-----END ECH KEYS-----/p' "$ECH/ech.txt" > "$ECH/ech-key.pem"
chmod 600 "$ECH/ech.txt" "$ECH/ech-key.pem"
chown sing-box:sing-box "$ECH/ech.txt" "$ECH/ech-key.pem"

cat > "$CONFIG" <<EOF
{
  "log":{"level":"info","timestamp":true},
  "certificate_providers":[{"type":"acme","tag":"hy2-cert","domain":["$DOMAIN"],"data_directory":"$CERT"}],
  "inbounds":[{
    "type":"hysteria2","tag":"hy2-in","listen":"::","listen_port":443,
    "users":[{"name":"default","password":"$PASS"}],
    "tls":{"enabled":true,"server_name":"$DOMAIN","certificate_provider":"hy2-cert","ech":{"enabled":true,"key_path":"$ECH/ech-key.pem"}}
  ]}
}
EOF

sing-box check -c "$CONFIG"
sudo -u sing-box sing-box check -c "$CONFIG"

curl -fsSL "$RAW/panel/hy2_panel.py" -o "$PANEL/hy2_panel.py"
chmod 755 "$PANEL/hy2_panel.py"
TOKEN="$(cat /proc/sys/kernel/random/uuid | tr -d '-')"
printf 'PANEL_PORT=%s
PANEL_TOKEN=%s
' "$PORT" "$TOKEN" > "$PANEL/env"
chmod 600 "$PANEL/env"

cat > /etc/systemd/system/hy2-panel.service <<EOF
[Unit]
Description=Hy2 Manager Panel
After=network-online.target sing-box.service
[Service]
EnvironmentFile=$PANEL/env
ExecStart=/usr/bin/python3 $PANEL/hy2_panel.py
Restart=always
RestartSec=2
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now sing-box
systemctl enable --now hy2-panel

echo
echo "安装完成"
echo "面板: http://SERVER_IP:$PORT/?token=$TOKEN"
echo "节点: hysteria2://$PASS@$DOMAIN:443/?sni=$DOMAIN#$DOMAIN"
