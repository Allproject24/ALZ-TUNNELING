#!/bin/bash
# ================================================
#   KyoStore VPN - Services & System
# ================================================

DIR="/etc/vps"
source $DIR/config.conf 2>/dev/null

W='\e[1;37m'  N='\e[0m'
RED='\e[1;31m' GRN='\e[1;32m' YEL='\e[1;33m' CYN='\e[1;36m' C='\e[0;36m'

svc_badge() {
    systemctl is-active --quiet "$1" 2>/dev/null \
        && echo -e "${GRN}[AKTIF]${N}" \
        || echo -e "${RED}[MATI] ${N}"
}

header_svc() {
    clear
    echo -e "\n  ${CYN}╭─────────────────────────────────────────╮${N}"
    echo -e "  ${CYN}│${N}  ${W}Services & System${N}$(printf '%23s')${CYN}│${N}"
    echo -e "  ${CYN}╰─────────────────────────────────────────╯${N}\n"
}

show_services() {
    header_svc
    echo -e "  ${W}Status Semua Layanan${N}\n"
    echo -e "  ${CYN}┌──────────────────────┬───────────┬─────────────────┐${N}"
    printf  "  ${CYN}│${N} %-22s ${CYN}│${N} %-9s ${CYN}│${N} %-15s ${CYN}│${N}\n" "LAYANAN" "STATUS" "PORT"
    echo -e "  ${CYN}├──────────────────────┼───────────┼─────────────────┤${N}"

    declare -A PORTS=(
        ["ssh"]="22, 80, 443"
        ["dropbear"]="109, 143"
        ["squid"]="3128, 8080"
        ["nginx"]="80, 443"
        ["xray"]="10001-10013"
    )

    for svc in ssh dropbear squid nginx xray; do
        local badge=$(svc_badge "$svc")
        printf  "  ${CYN}│${N} %-22s ${CYN}│${N} %b      ${CYN}│${N} %-15s ${CYN}│${N}\n" \
                "${svc^^}" "$badge" "${PORTS[$svc]}"
    done
    echo -e "  ${CYN}└──────────────────────┴───────────┴─────────────────┘${N}\n"
}

restart_service() {
    header_svc
    echo -e "  ${W}Restart Layanan${N}\n"
    echo -e "  ${CYN}┌──────────────────────────────┐${N}"
    echo -e "  ${CYN}│${N}  ${GRN}[1]${N} SSH                    ${CYN}│${N}"
    echo -e "  ${CYN}│${N}  ${GRN}[2]${N} Dropbear               ${CYN}│${N}"
    echo -e "  ${CYN}│${N}  ${GRN}[3]${N} Squid                  ${CYN}│${N}"
    echo -e "  ${CYN}│${N}  ${GRN}[4]${N} Nginx                  ${CYN}│${N}"
    echo -e "  ${CYN}│${N}  ${GRN}[5]${N} Xray                   ${CYN}│${N}"
    echo -e "  ${CYN}│${N}  ${YEL}[6]${N} Restart Semua          ${CYN}│${N}"
    echo -e "  ${CYN}└──────────────────────────────┘${N}"
    echo ""
    echo -ne "  ${W}Pilih${N} : "; read -r opt
    local svc_list=(ssh dropbear squid nginx xray)
    if [[ "$opt" -ge 1 && "$opt" -le 5 ]]; then
        local svc="${svc_list[$((opt-1))]}"
        echo -ne "\n  Merestart ${svc}..."
        systemctl restart "$svc" 2>/dev/null && echo -e " ${GRN}OK${N}" || echo -e " ${RED}GAGAL${N}"
    elif [[ "$opt" == "6" ]]; then
        for s in "${svc_list[@]}"; do
            echo -ne "  Merestart ${s}..."
            systemctl restart "$s" 2>/dev/null && echo -e " ${GRN}OK${N}" || echo -e " ${RED}GAGAL${N}"
        done
    fi
    sleep 2; services_menu
}

system_info() {
    header_svc
    local ip="${VPS_IP:-$(curl -s ifconfig.me 2>/dev/null)}"
    local os=$(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)
    local kernel=$(uname -r)
    local cpu_cores=$(nproc)
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d. -f1)
    local ram_used=$(free -m | awk '/^Mem:/{print $3}')
    local ram_total=$(free -m | awk '/^Mem:/{print $2}')
    local disk=$(df -h / | awk 'NR==2{print $3"/"$2" ("$5")"}')
    local uptime=$(uptime -p | sed 's/up //')
    local load=$(uptime | awk -F'load average:' '{print $2}' | xargs)

    echo -e "  ${W}Informasi Sistem${N}\n"
    echo -e "  ${CYN}╭─────────────────────────────────────────╮${N}"
    printf  "  ${CYN}│${N}  %-12s : ${W}%-25s${CYN}│${N}\n" "OS" "$os"
    printf  "  ${CYN}│${N}  %-12s : %-25s${CYN}│${N}\n" "Kernel" "$kernel"
    printf  "  ${CYN}│${N}  %-12s : %-25s${CYN}│${N}\n" "CPU Cores" "$cpu_cores core(s)"
    printf  "  ${CYN}│${N}  %-12s : ${YEL}%-25s${CYN}│${N}\n" "CPU Usage" "${cpu_usage:-?}%"
    printf  "  ${CYN}│${N}  %-12s : ${YEL}%-25s${CYN}│${N}\n" "RAM" "${ram_used}M / ${ram_total}M"
    printf  "  ${CYN}│${N}  %-12s : %-25s${CYN}│${N}\n" "Disk" "$disk"
    printf  "  ${CYN}│${N}  %-12s : ${GRN}%-25s${CYN}│${N}\n" "IP Publik" "$ip"
    printf  "  ${CYN}│${N}  %-12s : ${GRN}%-25s${CYN}│${N}\n" "Domain" "${DOMAIN:-Belum diset}"
    printf  "  ${CYN}│${N}  %-12s : %-25s${CYN}│${N}\n" "Uptime" "$uptime"
    printf  "  ${CYN}│${N}  %-12s : %-25s${CYN}│${N}\n" "Load Avg" "$load"
    echo -e "  ${CYN}╰─────────────────────────────────────────╯${N}\n"
    echo -ne "  Tekan Enter untuk kembali..."; read -r
    services_menu
}

check_bandwidth() {
    header_svc
    echo -e "  ${W}Monitor Bandwidth${N}\n"

    local iface=$(ip route | grep default | awk '{print $5}' | head -1)
    local rx=$(cat /sys/class/net/${iface}/statistics/rx_bytes 2>/dev/null || echo 0)
    local tx=$(cat /sys/class/net/${iface}/statistics/tx_bytes 2>/dev/null || echo 0)
    local rx_gb=$(echo "scale=2; $rx/1073741824" | bc 2>/dev/null || echo "?")
    local tx_gb=$(echo "scale=2; $tx/1073741824" | bc 2>/dev/null || echo "?")

    echo -e "  ${CYN}╭─────────────────────────────────────────╮${N}"
    printf  "  ${CYN}│${N}  %-14s : ${GRN}%-23s${CYN}│${N}\n" "Interface" "$iface"
    printf  "  ${CYN}│${N}  %-14s : ${C}%-23s${CYN}│${N}\n" "Download (RX)" "${rx_gb} GB"
    printf  "  ${CYN}│${N}  %-14s : ${YEL}%-23s${CYN}│${N}\n" "Upload (TX)" "${tx_gb} GB"
    echo -e "  ${CYN}╰─────────────────────────────────────────╯${N}\n"
    echo -ne "  Tekan Enter untuk kembali..."; read -r
    services_menu
}

enable_bbr() {
    header_svc
    echo -e "  ${W}Aktifkan TCP BBR${N}\n"
    local current=$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}')
    echo -e "  Algoritma saat ini : ${YEL}${current}${N}"

    grep -q "bbr" /etc/sysctl.conf 2>/dev/null || {
        echo "net.core.default_qdisc = fq" >> /etc/sysctl.conf
        echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.conf
    }
    sysctl -p > /dev/null 2>&1

    local new=$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}')
    echo -e "  Algoritma baru     : ${GRN}${new}${N}\n"
    [[ "$new" == "bbr" ]] && echo -e "  ${GRN}✓ TCP BBR berhasil diaktifkan!${N}" || echo -e "  ${YEL}Kernel mungkin tidak mendukung BBR${N}"
    echo ""
    sleep 2; services_menu
}

reboot_vps() {
    header_svc
    echo -ne "  ${RED}Yakin ingin reboot VPS? [y/N]${N} : "; read -r c
    [[ "$c" =~ ^[Yy]$ ]] && { echo -e "  ${YEL}Rebooting...${N}"; sleep 2; reboot; } || services_menu
}

services_menu() {
    show_services
    echo -e "  ${CYN}┌──────────────────────────────┐${N}"
    echo -e "  ${CYN}│${N}  ${GRN}[1]${N} Informasi Sistem       ${CYN}│${N}"
    echo -e "  ${CYN}│${N}  ${GRN}[2]${N} Restart Layanan        ${CYN}│${N}"
    echo -e "  ${CYN}│${N}  ${GRN}[3]${N} Monitor Bandwidth      ${CYN}│${N}"
    echo -e "  ${CYN}│${N}  ${YEL}[4]${N} Aktifkan TCP BBR       ${CYN}│${N}"
    echo -e "  ${CYN}│${N}  ${RED}[5]${N} Reboot VPS             ${CYN}│${N}"
    echo -e "  ${CYN}│${N}  ${C}[0]${N} Kembali ke Menu Utama  ${CYN}│${N}"
    echo -e "  ${CYN}└──────────────────────────────┘${N}"
    echo ""
    echo -ne "  ${W}Pilih${N} : "
    read -r opt
    case $opt in
        1) system_info ;;
        2) restart_service ;;
        3) check_bandwidth ;;
        4) enable_bbr ;;
        5) reboot_vps ;;
        0|q) bash $DIR/menu.sh ;;
        *) services_menu ;;
    esac
}

services_menu
