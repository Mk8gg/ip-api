#!/usr/bin/env bash
set -euo pipefail

export LANG=C.UTF-8
export LC_ALL=C.UTF-8

CONFIG="/etc/sing-box/config.json"
DATA="/var/lib/sing-box"
ECH_DIR="/etc/sing-box/ech"
CERT_DIR="/var/lib/sing-box/certmagic"
SERVICE="/etc/systemd/system/sing-box.service"

red(){ printf '\033[31m%s\033[0m\n' "$*"; }
green(){ printf '\033[32m%s\033[0m\n' "$*"; }
yellow(){ printf '\033[33m%s\033[0m\n' "$*"; }
blue(){ printf '\033[36m%s\033[0m\n' "$*"; }

[ "$(id -u)" = 0 ] || { red "请使用 root 执行。"; exit 1; }

clear || true
echo "=============================================="
echo "        sing-box 一键服务器部署脚本"
echo "=============================================="
echo "官方内核 · 简体中文 · IPv4/IPv6"
echo

if command -v sing-box >/dev/null 2>&1; then
    green "检测到 sing-box: $(sing-box version | head -1)"
else
    yellow "未检测到 sing-box，将安装官方最新版。"
fi

echo
echo "请选择服务器协议："
echo "  1) Hysteria2"
echo "  2) Hysteria"
echo "  3) VLESS"
echo "  4) VMess"
echo "  5) Trojan"
echo "  6) Shadowsocks"
echo "  7) TUIC"
echo "  8) AnyTLS"
echo "  9) ShadowTLS"
echo " 10) Naive"
echo
read -r -p "选择 [1-10]: " CHOICE

case "$CHOICE" in
  1) PROTOCOL="hysteria2" ;;
  2) PROTOCOL="hysteria" ;;
  3) PROTOCOL="vless" ;;
  4) PROTOCOL="vmess" ;;
  5) PROTOCOL="trojan" ;;
  6) PROTOCOL="shadowsocks" ;;
  7) PROTOCOL="tuic" ;;
  8) PROTOCOL="anytls" ;;
  9) PROTOCOL="shadowtls" ;;
 10) PROTOCOL="naive" ;;
 *) red "无效选择。"; exit 1 ;;
esac

read -r -p "服务器域名: " DOMAIN
[ -n "$DOMAIN" ] || { red "域名不能为空。"; exit 1; }

read -r -p "监听端口 [443]: " PORT
PORT="${PORT:-443}"

install_singbox() {
    if command -v sing-box >/dev/null 2>&1; then
        return
    fi
    blue "正在通过官方安装脚本安装 sing-box..."
    curl -fsSL https://sing-box.app/install.sh | sh
}

install_singbox

mkdir -p "$ECH_DIR" "$CERT_DIR"
chown -R sing-box:sing-box "$ECH_DIR" "$CERT_DIR"
chmod 700 "$ECH_DIR" "$CERT_DIR"

UUID="$(cat /proc/sys/kernel/random/uuid)"
PASSWORD="$(cat /proc/sys/kernel/random/uuid)"
SS_PASSWORD=""
SHORT_ID="$(openssl rand -hex 8 2>/dev/null || printf '%s' "${UUID//-/}" | cut -c1-16)"

TLS_MODE="acme"

if [ "$PROTOCOL" = "vless" ] || [ "$PROTOCOL" = "vmess" ] || [ "$PROTOCOL" = "trojan" ] || [ "$PROTOCOL" = "anytls" ] || [ "$PROTOCOL" = "naive" ]; then
    echo
    echo "TLS 模式："
    echo "  1) ACME / Let's Encrypt"
    echo "  2) Reality（VLESS/VMess 可用）"
    echo "  3) ECH + ACME"
    read -r -p "选择 [1-3]: " TLS_CHOICE
    TLS_CHOICE="${TLS_CHOICE:-1}"

    case "$TLS_CHOICE" in
      1) TLS_MODE="acme" ;;
      2)
        if [ "$PROTOCOL" != "vless" ] && [ "$PROTOCOL" != "vmess" ]; then
            red "该协议不使用此脚本提供的 Reality 模式。"
            exit 1
        fi
        TLS_MODE="reality"
        ;;
      3) TLS_MODE="ech" ;;
      *) red "无效选择。"; exit 1 ;;
    esac
fi

if [ "$PROTOCOL" = "hysteria2" ]; then
    read -r -p "Hy2 密码（留空自动生成）: " P
    PASSWORD="${P:-$PASSWORD}"
fi

if [ "$PROTOCOL" = "hysteria" ]; then
    read -r -p "上行带宽 Mbps [100]: " UP
    read -r -p "下行带宽 Mbps [100]: " DOWN
    UP="${UP:-100}"
    DOWN="${DOWN:-100}"
fi

if [ "$PROTOCOL" = "shadowsocks" ]; then
    echo "Shadowsocks 加密方式："
    echo "  1) 2022-blake3-aes-128-gcm"
    echo "  2) 2022-blake3-aes-256-gcm"
    echo "  3) chacha20-ietf-poly1305"
    read -r -p "选择 [1-3]: " SS_CHOICE
    case "${SS_CHOICE:-1}" in
      1) SS_METHOD="2022-blake3-aes-128-gcm"; SS_PASSWORD="$(sing-box generate rand --base64 16)" ;;
      2) SS_METHOD="2022-blake3-aes-256-gcm"; SS_PASSWORD="$(sing-box generate rand --base64 32)" ;;
      3) SS_METHOD="chacha20-ietf-poly1305"; SS_PASSWORD="$PASSWORD" ;;
      *) red "无效选择。"; exit 1 ;;
    esac
fi

REALITY_SERVER="www.cloudflare.com"

if [ "$TLS_MODE" = "reality" ] || [ "$PROTOCOL" = "shadowtls" ]; then
    read -r -p "握手/伪装域名 [www.cloudflare.com]: " REALITY_SERVER
    REALITY_SERVER="${REALITY_SERVER:-www.cloudflare.com}"
    REALITY_KEY="$(sing-box generate reality-keypair)"
    REALITY_PRIVATE="$(printf '%s\n' "$REALITY_KEY" | awk '/PrivateKey/ {print $2}')"
    REALITY_PUBLIC="$(printf '%s\n' "$REALITY_KEY" | awk '/PublicKey/ {print $2}')"
fi

if [ "$TLS_MODE" = "ech" ]; then
    sing-box generate ech-keypair "$DOMAIN" > "$ECH_DIR/ech.txt"
    sed -n '/-----BEGIN ECH KEYS-----/,/-----END ECH KEYS-----/p' "$ECH_DIR/ech.txt" > "$ECH_DIR/ech-key.pem"
    chmod 600 "$ECH_DIR/ech.txt" "$ECH_DIR/ech-key.pem"
    chown sing-box:sing-box "$ECH_DIR/ech.txt" "$ECH_DIR/ech-key.pem"
fi

export SB_PROTOCOL="$PROTOCOL"
export SB_DOMAIN="$DOMAIN"
export SB_PORT="$PORT"
export SB_UUID="$UUID"
export SB_PASSWORD="$PASSWORD"
export SB_SS_PASSWORD="$SS_PASSWORD"
export SB_SS_METHOD="${SS_METHOD:-}"
export SB_TLS_MODE="$TLS_MODE"
export SB_ECH_KEY="$ECH_DIR/ech-key.pem"
export SB_CERT_DIR="$CERT_DIR"
export SB_REALITY_PRIVATE="${REALITY_PRIVATE:-}"
export SB_REALITY_PUBLIC="${REALITY_PUBLIC:-}"
export SB_REALITY_SERVER="${REALITY_SERVER:-}"
export SB_SHORT_ID="$SHORT_ID"
export SB_UP="${UP:-}"
export SB_DOWN="${DOWN:-}"

python3 <<'PY'
import json
import os

p = os.environ["SB_PROTOCOL"]
domain = os.environ["SB_DOMAIN"]
port = int(os.environ["SB_PORT"])
uuid = os.environ["SB_UUID"]
password = os.environ["SB_PASSWORD"]
ss_password = os.environ["SB_SS_PASSWORD"]
ss_method = os.environ["SB_SS_METHOD"]
tls_mode = os.environ["SB_TLS_MODE"]
ech_key = os.environ["SB_ECH_KEY"]
cert_dir = os.environ["SB_CERT_DIR"]
reality_private = os.environ["SB_REALITY_PRIVATE"]
reality_server = os.environ["SB_REALITY_SERVER"]
short_id = os.environ["SB_SHORT_ID"]
up = os.environ["SB_UP"]
down = os.environ["SB_DOWN"]

cfg = {
    "log": {"level": "info", "timestamp": True},
    "inbounds": []
}

def tls():
    if tls_mode == "reality":
        return {
            "enabled": True,
            "server_name": reality_server,
            "reality": {
                "enabled": True,
                "handshake": {"server": reality_server, "server_port": 443},
                "private_key": reality_private,
                "short_id": [short_id]
            }
        }
    if tls_mode == "ech":
        cfg["certificate_providers"] = [{
            "type": "acme",
            "tag": "acme-cert",
            "domain": [domain],
            "data_directory": cert_dir
        }]
        return {
            "enabled": True,
            "server_name": domain,
            "certificate_provider": "acme-cert",
            "ech": {"enabled": True, "key_path": ech_key}
        }
    if tls_mode == "acme":
        cfg["certificate_providers"] = [{
            "type": "acme",
            "tag": "acme-cert",
            "domain": [domain],
            "data_directory": cert_dir
        }]
        return {
            "enabled": True,
            "server_name": domain,
            "certificate_provider": "acme-cert"
        }
    return {}

base = {"tag": "server", "listen": "::", "listen_port": port}

if p == "hysteria2":
    base.update({
        "type": "hysteria2",
        "users": [{"name": "default", "password": password}],
        "tls": tls()
    })
elif p == "hysteria":
    base.update({
        "type": "hysteria",
        "up_mbps": int(up),
        "down_mbps": int(down),
        "users": [{"name": "default", "auth_str": password}],
        "tls": tls()
    })
elif p == "vless":
    base.update({
        "type": "vless",
        "users": [{"name": "default", "uuid": uuid}],
        "tls": tls()
    })
elif p == "vmess":
    base.update({
        "type": "vmess",
        "users": [{"name": "default", "uuid": uuid}],
        "tls": tls()
    })
elif p == "trojan":
    base.update({
        "type": "trojan",
        "users": [{"name": "default", "password": password}],
        "tls": tls()
    })
elif p == "shadowsocks":
    base.update({
        "type": "shadowsocks",
        "method": ss_method,
        "password": ss_password
    })
elif p == "tuic":
    base.update({
        "type": "tuic",
        "users": [{"uuid": uuid, "password": password}],
        "tls": tls()
    })
elif p == "anytls":
    base.update({
        "type": "anytls",
        "users": [{"name": "default", "password": password}],
        "tls": tls()
    })
elif p == "shadowtls":
    base.update({
        "type": "shadowtls",
        "version": 3,
        "users": [{"password": password}],
        "handshake": {"server": domain, "server_port": 443},
        "strict_mode": True
    })
elif p == "naive":
    base.update({
        "type": "naive",
        "users": [{"username": "admin", "password": password}],
        "tls": tls()
    })

cfg["inbounds"].append(base)

with open("/etc/sing-box/config.json", "w", encoding="utf-8") as f:
    json.dump(cfg, f, ensure_ascii=False, indent=2)
    f.write("\n")
PY

chown root:root "$CONFIG"
chmod 600 "$CONFIG"

if ! sing-box check -c "$CONFIG"; then
    red "sing-box 配置检查失败，已停止，不启动服务。"
    exit 1
fi

systemctl daemon-reload
systemctl enable sing-box >/dev/null
systemctl restart sing-box

sleep 2

if ! systemctl is-active --quiet sing-box; then
    red "sing-box 启动失败。"
    systemctl --no-pager -l status sing-box || true
    exit 1
fi

green "=============================================="
green "部署完成"
green "=============================================="
echo "协议: $PROTOCOL"
echo "域名: $DOMAIN"
echo "端口: $PORT"
echo "版本: $(sing-box version | head -1)"
echo
echo "配置文件: $CONFIG"
echo
echo "请使用以下命令查看节点信息："
echo "  sing-box check -c $CONFIG"
echo "  systemctl status sing-box --no-pager"
echo "  journalctl -u sing-box -n 50 --no-pager"
