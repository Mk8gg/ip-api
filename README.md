# sing-box 一键安装脚本

基于官方 sing-box 内核的一键服务器部署脚本。

## 特性

- 简体中文交互菜单
- 自动安装官方 sing-box
- 支持 sing-box 服务器入站协议：
  - Hysteria2
  - Hysteria
  - VLESS
  - VMess
  - Trojan
  - Shadowsocks
  - TUIC
  - AnyTLS
  - ShadowTLS
  - Naive
- TLS / Reality / ECH 按协议提供配置选项
- ACME / Let's Encrypt 证书
- IPv4 / IPv6 双栈
- 自动生成随机 UUID、密码、Reality 密钥等
- 自动执行 sing-box 配置检查
- 自动创建 systemd 服务
- 显示生成后的节点分享链接
- 不包含任何固定域名、IP、密码或私钥

## 安装

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Mk8gg/ip-api/master/install.sh)
```

项目仅负责部署和配置 sing-box，不提供 Web 面板。
