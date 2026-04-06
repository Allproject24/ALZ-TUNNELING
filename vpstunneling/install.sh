#!/bin/bash
# ================================================
#   VPS TUNNELING INSTALLER
#   Support: Debian 10/11/12 | Ubuntu 20/22/24
# ================================================

MERAH='\e[1;31m'
HIJAU='\e[1;32m'
KUNING='\e[1;33m'
BIRU='\e[1;34m'
CYAN='\e[1;36m'
PUTIH='\e[1;37m'
RESET='\e[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "$EUID" -ne 0 ]]; then
    echo -e "${MERAH}Script ini harus dijalankan sebagai root!${RESET}"
    exit 1
fi

check_os() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        OS_NAME="$ID"
        OS_VER="$VERSION_ID"
    else
        echo -e "${MERAH}OS tidak didukung!${RESET}"
        exit 1
    fi

    if [[ "$OS_NAME" != "debian" && "$OS_NAME" != "ubuntu" ]]; then
        echo -e "${MERAH}Hanya mendukung Debian/Ubuntu!${RESET}"
        exit 1
    fi
}

print_banner() {
    clear
    echo -e "${CYAN}"
    echo "  ╔═══════════════════════════════════════╗"
    echo "  ║       VPS TUNNELING INSTALLER         ║"
    echo "  ║    SSH | VMESS | VLESS | TROJAN       ║"
    echo "  ╚═══════════════════════════════════════╝"
    echo -e "${RESET}"
    echo -e " OS      : $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)"
    echo -e " IP      : $(curl -s ifconfig.me 2>/dev/null)"
    echo ""
}

step() {
    echo -e " ${KUNING}[*]${RESET} $1"
}

ok() {
    echo -e " ${HIJAU}[✓]${RESET} $1"
}

err() {
    echo -e " ${MERAH}[✗]${RESET} $1"
}

install_deps() {
    step "Update system & install dependencies..."
    apt-get update -qq 2>/dev/null
    apt-get install -y -qq \
        curl wget sudo unzip jq python3 python3-pip \
        cron bc netcat-openbsd net-tools \
        openssh-server dropbear squid \
        nginx certbot python3-certbot-nginx \
        uuid-runtime openssl 2>/dev/null
    ok "Dependencies terinstall"
}

install_xray() {
    step "Install Xray-core..."
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install 2>/dev/null
    ok "Xray berhasil diinstall"
}

setup_xray_config() {
    step "Konfigurasi Xray..."
    mkdir -p /usr/local/etc/xray

    cat > /usr/local/etc/xray/config.json << 'XRAYCONF'
{
  "log": {
    "loglevel": "warning",
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log"
  },
  "inbounds": [
    {
      "tag": "vmess-in",
      "port": 10000,
      "listen": "0.0.0.0",
      "protocol": "vmess",
      "settings": {
        "clients": []
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/vmess"
        }
      }
    },
    {
      "tag": "vless-in",
      "port": 10001,
      "listen": "0.0.0.0",
      "protocol": "vless",
      "settings": {
        "clients": [],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/vless"
        }
      }
    },
    {
      "tag": "trojan-in",
      "port": 10002,
      "listen": "0.0.0.0",
      "protocol": "trojan",
      "settings": {
        "clients": []
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/trojan"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "tag": "blocked"
    }
  ],
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {
        "type": "field",
        "ip": ["geoip:private"],
        "outboundTag": "blocked"
      }
    ]
  }
}
XRAYCONF

    systemctl enable xray 2>/dev/null
    systemctl restart xray 2>/dev/null
    ok "Xray dikonfigurasi"
}

setup_nginx() {
    step "Konfigurasi Nginx sebagai reverse proxy..."

    read -rp " Masukkan domain VPS (atau tekan Enter untuk skip): " DOMAIN_INPUT
    if [[ -n "$DOMAIN_INPUT" ]]; then
        DOMAIN="$DOMAIN_INPUT"
    else
        DOMAIN=$(curl -s ifconfig.me 2>/dev/null)
    fi

    cat > /etc/nginx/conf.d/vpstunnel.conf << NGINXCONF
server {
    listen 80;
    server_name _;

    location /vmess {
        proxy_pass http://127.0.0.1:10000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_read_timeout 3600s;
    }

    location /upvmess {
        proxy_pass http://127.0.0.1:10000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    location /vless {
        proxy_pass http://127.0.0.1:10001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_read_timeout 3600s;
    }

    location /upvless {
        proxy_pass http://127.0.0.1:10001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    location /trojan {
        proxy_pass http://127.0.0.1:10002;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_read_timeout 3600s;
    }

    location / {
        return 403;
    }
}
NGINXCONF

    nginx -t 2>/dev/null && systemctl restart nginx 2>/dev/null
    ok "Nginx dikonfigurasi"
}

setup_ssh() {
    step "Konfigurasi SSH..."
    sed -i "s/^#Port.*/Port 22/" /etc/ssh/sshd_config 2>/dev/null
    sed -i "s/^Port.*/Port 22/" /etc/ssh/sshd_config 2>/dev/null
    sed -i "s/^#PasswordAuthentication.*/PasswordAuthentication yes/" /etc/ssh/sshd_config 2>/dev/null
    sed -i "s/^PasswordAuthentication.*/PasswordAuthentication yes/" /etc/ssh/sshd_config 2>/dev/null
    systemctl restart ssh 2>/dev/null
    ok "SSH dikonfigurasi di port 22"
}

setup_dropbear() {
    step "Konfigurasi Dropbear..."
    if command -v dropbear &>/dev/null; then
        sed -i 's/NO_START=1/NO_START=0/' /etc/default/dropbear 2>/dev/null
        sed -i 's/DROPBEAR_PORT=22/DROPBEAR_PORT=109/' /etc/default/dropbear 2>/dev/null
        echo 'DROPBEAR_EXTRA_ARGS="-p 143"' >> /etc/default/dropbear 2>/dev/null
        systemctl restart dropbear 2>/dev/null
        ok "Dropbear dikonfigurasi di port 109, 143"
    else
        err "Dropbear tidak ditemukan, skip..."
    fi
}

setup_squid() {
    step "Konfigurasi Squid Proxy..."
    cat > /etc/squid/squid.conf << 'SQUIDCONF'
http_port 3128
http_port 8080
acl SSL_ports port 443
acl Safe_ports port 80
acl Safe_ports port 21
acl Safe_ports port 443
acl Safe_ports port 70
acl Safe_ports port 210
acl Safe_ports port 1025-65535
acl Safe_ports port 280
acl Safe_ports port 488
acl Safe_ports port 591
acl Safe_ports port 777
acl CONNECT method CONNECT
acl localhost src 127.0.0.1/32
acl localnet src 10.0.0.0/8
acl localnet src 172.16.0.0/12
acl localnet src 192.168.0.0/16
acl all src 0.0.0.0/0
http_access allow all
forwarded_for off
request_header_access Allow allow all
request_header_access Authorization allow all
request_header_access WWW-Authenticate allow all
request_header_access Proxy-Authorization allow all
request_header_access Proxy-Authenticate allow all
request_header_access Cache-Control allow all
request_header_access Content-Encoding allow all
request_header_access Content-Length allow all
request_header_access Content-Type allow all
request_header_access Date allow all
request_header_access Expires allow all
request_header_access Host allow all
request_header_access If-Modified-Since allow all
request_header_access Last-Modified allow all
request_header_access Location allow all
request_header_access Pragma allow all
request_header_access Accept allow all
request_header_access Accept-Charset allow all
request_header_access Accept-Encoding allow all
request_header_access Accept-Language allow all
request_header_access Content-Language allow all
request_header_access Mime-Version allow all
request_header_access Retry-After allow all
request_header_access Title allow all
request_header_access Connection allow all
request_header_access Proxy-Connection allow all
request_header_access User-Agent allow all
request_header_access Cookie allow all
request_header_access All deny all
SQUIDCONF

    systemctl restart squid 2>/dev/null
    ok "Squid dikonfigurasi di port 3128, 8080"
}

install_scripts() {
    step "Install management scripts..."
    mkdir -p /etc/vps
    mkdir -p /var/log/xray

    for script in menu.sh ssh.sh vmess.sh vless.sh trojan.sh features.sh reduce.sh bot.sh; do
        if [[ -f "${SCRIPT_DIR}/${script}" ]]; then
            cp "${SCRIPT_DIR}/${script}" "/etc/vps/${script}"
            chmod +x "/etc/vps/${script}"
        fi
    done

    [[ ! -f /etc/vps/accounts.db ]] && touch /etc/vps/accounts.db
    [[ ! -f /etc/vps/config.conf ]] && echo "BRAND_NAME=\"VPS TUNNELING\"
DOMAIN=\"$(curl -s ifconfig.me 2>/dev/null)\"" > /etc/vps/config.conf

    ln -sf /etc/vps/menu.sh /usr/local/bin/menu
    chmod +x /usr/local/bin/menu

    ok "Scripts terinstall, gunakan perintah 'menu' untuk akses"
}

apply_bbr() {
    step "Aktifkan TCP BBR..."
    echo "net.core.default_qdisc = fq" >> /etc/sysctl.conf 2>/dev/null
    echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.conf 2>/dev/null
    sysctl -p > /dev/null 2>&1
    ok "TCP BBR diaktifkan"
}

print_finish() {
    IP=$(curl -s ifconfig.me 2>/dev/null)
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "       ${HIJAU}INSTALASI SELESAI!${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    printf " %-12s : %s\n" "IP Server" "$IP"
    printf " %-12s : %s\n" "Domain" "${DOMAIN:-$IP}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e " Akses menu: ${KUNING}menu${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

main() {
    print_banner
    check_os

    echo -ne " Lanjutkan instalasi? [Y/n] : "
    read -r confirm
    [[ "$confirm" =~ ^[Nn]$ ]] && exit 0

    echo ""
    install_deps
    install_xray
    setup_xray_config
    setup_nginx
    setup_ssh
    setup_dropbear
    setup_squid
    apply_bbr
    install_scripts
    print_finish
}

main
