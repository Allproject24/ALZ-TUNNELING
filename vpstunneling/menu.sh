#!/bin/bash
# ================================================
#   AL STORE TUNNELING - Main Menu
# ================================================

DIR="/etc/vps"
source $DIR/config.conf 2>/dev/null

R='\e[0;31m'  G='\e[0;32m'  Y='\e[0;33m'  C='\e[0;36m'
W='\e[1;37m'  N='\e[0m'
RED='\e[1;31m' GRN='\e[1;32m' YEL='\e[1;33m' CYN='\e[1;36m'

BRAND="${BRAND_NAME:-AL STORE TUNNELING}"
VER="v2.0"

svc_dot() {
    systemctl is-active --quiet "$1" 2>/dev/null && echo -e "${GRN}●${N}" || echo -e "${RED}●${N}"
}

header() {
    clear
    local ip="${VPS_IP:-$(curl -s ifconfig.me 2>/dev/null)}"
    local isp=$(curl -s ipinfo.io/org 2>/dev/null | cut -d'"' -f2 | cut -d' ' -f2-)
    local ram_used=$(free -m | awk '/^Mem:/{print $3}')
    local ram_total=$(free -m | awk '/^Mem:/{print $2}')
    local uptime=$(uptime -p | sed 's/up //')
    local load=$(uptime | awk -F'load average:' '{print $2}' | xargs)

    local ssh_n=$(grep -c "^#ssh#" $DIR/accounts.db 2>/dev/null); ssh_n=${ssh_n:-0}
    local vmess_n=$(grep -c "^#vmess#" $DIR/accounts.db 2>/dev/null); vmess_n=${vmess_n:-0}
    local vless_n=$(grep -c "^#vless#" $DIR/accounts.db 2>/dev/null); vless_n=${vless_n:-0}
    local trojan_n=$(grep -c "^#trojan#" $DIR/accounts.db 2>/dev/null); trojan_n=${trojan_n:-0}

    local xs=$(svc_dot xray)
    local ss=$(svc_dot ssh)
    local ds=$(svc_dot dropbear)
    local sq=$(svc_dot squid)
    local ng=$(svc_dot nginx)

    echo -e "${CYN}"
    echo -e "  ╭─────────────────────────────────────────╮"
    printf  "  │  %-40s│\n" ""
    printf  "  │  ${YEL}%-34s${CYN}  ${W}%-4s${CYN} │\n" "$BRAND" "$VER"
    printf  "  │  %-40s│\n" ""
    echo -e "  ├─────────────────────────────────────────┤"
    printf  "  │  ${W}%-8s${N}${CYN}  %-30s│\n" "IP" "$ip"
    printf  "  │  ${W}%-8s${N}${CYN}  %-30s│\n" "Domain" "${DOMAIN:-$ip}"
    printf  "  │  ${W}%-8s${N}${CYN}  %-30s│\n" "ISP" "${isp:0:30}"
    printf  "  │  ${W}%-8s${N}${CYN}  %-30s│\n" "RAM" "${ram_used}M / ${ram_total}M"
    printf  "  │  ${W}%-8s${N}${CYN}  %-30s│\n" "Uptime" "${uptime:0:30}"
    printf  "  │  ${W}%-8s${N}${CYN}  %-30s│\n" "Load" "$load"
    echo -e "  ├─────────────────────────────────────────┤"
    printf  "  │  Xray:%-2s SSH:%-2s Drop:%-2s Squid:%-2s Nginx:%-2s  │\n" \
            "$xs" "$ss" "$ds" "$sq" "$ng"
    echo -e "  ├─────────────────────────────────────────┤"
    printf  "  │  ${W}%-8s${N}${CYN}  SSH:${GRN}%-5s${CYN}VMESS:${GRN}%-5s${CYN}VLESS:${GRN}%-5s${CYN}TRJ:${GRN}%-4s${CYN}│\n" \
            "Akun" "$ssh_n" "$vmess_n" "$vless_n" "$trojan_n"
    echo -e "  ╰─────────────────────────────────────────╯${N}"
    echo ""
}

main_menu() {
    header
    echo -e "  ${CYN}┌──────────────┬──────────────┐${N}"
    echo -e "  ${CYN}│${N}  ${GRN}[1]${N} SSH       ${CYN}│${N}  ${GRN}[2]${N} VMESS     ${CYN}│${N}"
    echo -e "  ${CYN}│${N}  ${GRN}[3]${N} VLESS     ${CYN}│${N}  ${GRN}[4]${N} TROJAN    ${CYN}│${N}"
    echo -e "  ${CYN}├──────────────┼──────────────┤${N}"
    echo -e "  ${CYN}│${N}  ${YEL}[5]${N} Services  ${CYN}│${N}  ${YEL}[6]${N} Settings  ${CYN}│${N}"
    echo -e "  ${CYN}│${N}  ${YEL}[7]${N} Cleanup   ${CYN}│${N}  ${YEL}[8]${N} Bot TG    ${CYN}│${N}"
    echo -e "  ${CYN}├──────────────┴──────────────┤${N}"
    echo -e "  ${CYN}│${N}  ${RED}[0]${N} Keluar                    ${CYN}│${N}"
    echo -e "  ${CYN}└─────────────────────────────┘${N}"
    echo ""
    echo -ne "  ${W}Pilih menu${N} : "
    read -r opt
    case $opt in
        1) bash $DIR/ssh.sh ;;
        2) bash $DIR/vmess.sh ;;
        3) bash $DIR/vless.sh ;;
        4) bash $DIR/trojan.sh ;;
        5) bash $DIR/services.sh ;;
        6) bash $DIR/settings.sh ;;
        7) bash $DIR/reduce.sh ;;
        8) bash $DIR/bot.sh ;;
        0|q|Q) echo -e "\n  ${YEL}Sampai jumpa!${N}\n" ; exit 0 ;;
        *) main_menu ;;
    esac
}

mkdir -p $DIR
[[ ! -f $DIR/accounts.db ]] && touch $DIR/accounts.db
[[ ! -f $DIR/config.conf ]] && cat > $DIR/config.conf << 'EOF'
BRAND_NAME="AL STORE TUNNELING"
DOMAIN="sg-idc.alstore-vpn.my.id"
VPS_IP="103.13.206.234"
XRAY_CONFIG="/usr/local/etc/xray/config.json"
EOF

main_menu
