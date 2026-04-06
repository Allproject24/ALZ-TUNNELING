#!/bin/bash
# ================================================
#   KyoStore VPN - Settings
# ================================================

DIR="/etc/vps"
source $DIR/config.conf 2>/dev/null

W='\e[1;37m'  N='\e[0m'
RED='\e[1;31m' GRN='\e[1;32m' YEL='\e[1;33m' CYN='\e[1;36m' C='\e[0;36m' Y='\e[0;33m'

save_cfg() {
    local k="$1" v="$2"
    grep -q "^${k}=" "$DIR/config.conf" 2>/dev/null \
        && sed -i "s|^${k}=.*|${k}=\"${v}\"|" "$DIR/config.conf" \
        || echo "${k}=\"${v}\"" >> "$DIR/config.conf"
}

header_cfg() {
    clear
    echo -e "\n  ${CYN}╭─────────────────────────────────────────╮${N}"
    echo -e "  ${CYN}│${N}  ${W}Pengaturan VPS${N}$(printf '%27s')${CYN}│${N}"
    echo -e "  ${CYN}╰─────────────────────────────────────────╯${N}\n"
}

show_current_cfg() {
    source $DIR/config.conf 2>/dev/null
    echo -e "  ${CYN}╭─────────────────────────────────────────╮${N}"
    echo -e "  ${CYN}│${N}  ${W}Konfigurasi Saat Ini${N}$(printf '%21s')${CYN}│${N}"
    echo -e "  ${CYN}├─────────────────────────────────────────┤${N}"
    printf  "  ${CYN}│${N}  %-14s : ${YEL}%-23s${CYN}│${N}\n" "Brand Name" "${BRAND_NAME:-belum diset}"
    printf  "  ${CYN}│${N}  %-14s : ${GRN}%-23s${CYN}│${N}\n" "Domain" "${DOMAIN:-belum diset}"
    printf  "  ${CYN}│${N}  %-14s : ${GRN}%-23s${CYN}│${N}\n" "IP VPS" "${VPS_IP:-$(curl -s ifconfig.me 2>/dev/null)}"
    printf  "  ${CYN}│${N}  %-14s : %-23s${CYN}│${N}\n" "Xray Config" "${XRAY_CONFIG:-/usr/local/etc/xray/config.json}"
    echo -e "  ${CYN}╰─────────────────────────────────────────╯${N}\n"
}

change_brand() {
    header_cfg
    show_current_cfg
    echo -ne "  Brand Name baru : "; read -r val
    [[ -n "$val" ]] && save_cfg "BRAND_NAME" "$val" && echo -e "\n  ${GRN}✓ Brand Name diubah ke: ${val}${N}"
    sleep 2; settings_menu
}

change_domain() {
    header_cfg
    show_current_cfg
    echo -ne "  Domain baru (contoh: vpn.domain.com) : "; read -r val
    if [[ -n "$val" ]]; then
        save_cfg "DOMAIN" "$val"
        echo -e "\n  ${GRN}✓ Domain diubah ke: ${val}${N}"
        echo -e "  ${YEL}Pastikan DNS domain mengarah ke IP VPS ini${N}"
    fi
    sleep 3; settings_menu
}

auto_delete_setup() {
    header_cfg
    echo -e "  ${W}Auto Hapus Akun Expired${N}\n"
    echo -e "  ${CYN}┌──────────────────────────────┐${N}"
    echo -e "  ${CYN}│${N}  ${GRN}[1]${N} Setiap hari jam 00:00  ${CYN}│${N}"
    echo -e "  ${CYN}│${N}  ${GRN}[2]${N} Setiap 12 jam          ${CYN}│${N}"
    echo -e "  ${CYN}│${N}  ${GRN}[3]${N} Setiap 6 jam           ${CYN}│${N}"
    echo -e "  ${CYN}│${N}  ${RED}[4]${N} Nonaktifkan            ${CYN}│${N}"
    echo -e "  ${CYN}└──────────────────────────────┘${N}"
    echo -ne "  ${W}Pilih${N} : "; read -r opt

    (crontab -l 2>/dev/null | grep -v "reduce.sh") | crontab -
    case $opt in
        1) (crontab -l 2>/dev/null; echo "0 0 * * * bash $DIR/reduce.sh auto") | crontab - ;;
        2) (crontab -l 2>/dev/null; echo "0 */12 * * * bash $DIR/reduce.sh auto") | crontab - ;;
        3) (crontab -l 2>/dev/null; echo "0 */6 * * * bash $DIR/reduce.sh auto") | crontab - ;;
        4) echo -e "\n  ${GRN}✓ Auto delete dinonaktifkan${N}" ;;
    esac
    [[ "$opt" != "4" ]] && echo -e "\n  ${GRN}✓ Auto delete berhasil dikonfigurasi${N}"
    sleep 2; settings_menu
}

change_ssh_banner() {
    header_cfg
    echo -e "  ${W}Ubah SSH Banner${N}\n"
    echo -ne "  Teks banner SSH : "; read -r banner_text
    if [[ -n "$banner_text" ]]; then
        echo "$banner_text" > /etc/ssh/banner
        grep -q "^Banner" /etc/ssh/sshd_config \
            && sed -i 's|^Banner.*|Banner /etc/ssh/banner|' /etc/ssh/sshd_config \
            || echo "Banner /etc/ssh/banner" >> /etc/ssh/sshd_config
        systemctl restart ssh 2>/dev/null
        echo -e "\n  ${GRN}✓ SSH Banner diubah${N}"
    fi
    sleep 2; settings_menu
}

update_ip() {
    header_cfg
    echo -e "  Mendeteksi IP publik..."
    local ip=$(curl -s ifconfig.me 2>/dev/null)
    save_cfg "VPS_IP" "$ip"
    echo -e "\n  ${GRN}✓ IP VPS diperbarui: ${ip}${N}\n"
    sleep 2; settings_menu
}

settings_menu() {
    header_cfg
    show_current_cfg
    echo -e "  ${CYN}┌──────────────────────────────┐${N}"
    echo -e "  ${CYN}│${N}  ${GRN}[1]${N} Ubah Brand Name        ${CYN}│${N}"
    echo -e "  ${CYN}│${N}  ${GRN}[2]${N} Ubah Domain            ${CYN}│${N}"
    echo -e "  ${CYN}│${N}  ${GRN}[3]${N} Auto Hapus Expired     ${CYN}│${N}"
    echo -e "  ${CYN}│${N}  ${GRN}[4]${N} Ubah SSH Banner        ${CYN}│${N}"
    echo -e "  ${CYN}│${N}  ${GRN}[5]${N} Perbarui IP VPS        ${CYN}│${N}"
    echo -e "  ${CYN}│${N}  ${C}[0]${N} Kembali ke Menu Utama  ${CYN}│${N}"
    echo -e "  ${CYN}└──────────────────────────────┘${N}"
    echo ""
    echo -ne "  ${W}Pilih${N} : "
    read -r opt
    case $opt in
        1) change_brand ;;
        2) change_domain ;;
        3) auto_delete_setup ;;
        4) change_ssh_banner ;;
        5) update_ip ;;
        0|q) bash $DIR/menu.sh ;;
        *) settings_menu ;;
    esac
}

settings_menu
# Auto deploy test: Mon Apr  6 06:40:21 AM UTC 2026
