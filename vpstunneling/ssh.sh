#!/bin/bash
# ================================================
#   AL STORE TUNNELING - SSH Management
# ================================================

DIR="/etc/vps"
source $DIR/config.conf 2>/dev/null

W='\e[1;37m'  N='\e[0m'
RED='\e[1;31m' GRN='\e[1;32m' YEL='\e[1;33m' CYN='\e[1;36m' C='\e[0;36m' Y='\e[0;33m'

DB="$DIR/accounts.db"
DOMAIN="${DOMAIN:-$(curl -s ifconfig.me 2>/dev/null)}"

rnd_user() { echo "als-$(cat /dev/urandom | tr -dc 'a-z0-9' | head -c 5)"; }
rnd_pass() { cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 12; }

header_ssh() {
    clear
    echo -e "\n  ${CYN}╭─────────────────────────────────────────╮${N}"
    echo -e "  ${CYN}│${N}  ${W}AL STORE TUNNELING - SSH Manager${N}$(printf '%8s')${CYN}│${N}"
    echo -e "  ${CYN}╰─────────────────────────────────────────╯${N}\n"
}

set_ip_limit() {
    local user="$1" limit="$2"
    [[ "$limit" -le 0 ]] 2>/dev/null && return
    # Set maxlogins via PAM
    grep -q "^${user}" /etc/security/limits.conf 2>/dev/null && \
        sed -i "/^${user}/d" /etc/security/limits.conf
    echo "${user}  hard  maxlogins  ${limit}" >> /etc/security/limits.conf
    echo "${user}  soft  maxlogins  ${limit}" >> /etc/security/limits.conf
}

remove_ip_limit() {
    local user="$1"
    sed -i "/^${user}.*maxlogins/d" /etc/security/limits.conf 2>/dev/null
}

show_account() {
    local user="$1" pass="$2" exp="$3" limit_ip="$4"
    local SEP="${CYN}————————————————————————————————————${N}"
    local kw=16

    echo ""
    echo -e "   ${GRN}Account Created Successfully${N}"
    echo -e "$SEP"
    printf "${CYN}%-${kw}s${N}: ${W}%s${N}\n" "HOST" "$DOMAIN"
    printf "${CYN}%-${kw}s${N}: ${GRN}%s${N}\n" "Username" "$user"
    printf "${CYN}%-${kw}s${N}: ${GRN}%s${N}\n" "Password" "$pass"
    echo -e "$SEP"
    printf "${CYN}%-${kw}s${N}: ${YEL}%s${N}\n" "Expired" "$exp"
    printf "${CYN}%-${kw}s${N}: %s\n" "Limit IP" "${limit_ip} Device"
    echo -e "$SEP"
    printf "%-${kw}s: %s\n" "OpenSSH" "22"
    printf "%-${kw}s: %s\n" "Dropbear" "90,143,69"
    printf "%-${kw}s: %s\n" "Stunnel SSL" "777"
    printf "%-${kw}s: %s\n" "Websockify WS" "9080"
    echo -e "$SEP"
    printf "%-${kw}s: %s\n" "TLS" "443,8443"
    printf "%-${kw}s: %s\n" "None TLS" "80,8080"
    printf "%-${kw}s: %s\n" "Any" "2052,2053,8880"
    echo -e "$SEP"
    printf "%-${kw}s: %s\n" "Squid Proxy" "3128"
    printf "%-${kw}s: %s\n" "UDPGW" "7100-7600"
    echo -e "$SEP"
    echo -e "${C}http://${DOMAIN}:8081/myvpn-config.zip${N}"
    echo -e "$SEP"
    echo ""
}

create_ssh() {
    header_ssh
    echo -e "  ${W}Buat Akun SSH Baru${N}\n"

    echo -ne "  Username      ${Y}[kosong = random]${N} : "; read -r USER
    [[ -z "$USER" ]] && USER=$(rnd_user)

    echo -ne "  Password      ${Y}[kosong = random]${N} : "; read -r PASS
    [[ -z "$PASS" ]] && PASS=$(rnd_pass)

    echo -ne "  Limit IP      ${Y}[jumlah device]${N}   : "; read -r LIMIT_IP
    [[ -z "$LIMIT_IP" || ! "$LIMIT_IP" =~ ^[0-9]+$ ]] && LIMIT_IP=2

    echo -ne "  Expired (day) ${Y}[default = 30]${N}    : "; read -r DAYS
    [[ -z "$DAYS" || ! "$DAYS" =~ ^[0-9]+$ ]] && DAYS=30

    echo ""
    echo -e "  ${CYN}┌─────────────────────────────────────┐${N}"
    printf  "  ${CYN}│${N}  %-10s : ${W}%-22s${CYN}│${N}\n" "Username" "$USER"
    printf  "  ${CYN}│${N}  %-10s : ${W}%-22s${CYN}│${N}\n" "Password" "$PASS"
    printf  "  ${CYN}│${N}  %-10s : %-22s${CYN}│${N}\n" "Limit IP" "$LIMIT_IP device(s)"
    printf  "  ${CYN}│${N}  %-10s : ${YEL}%-22s${CYN}│${N}\n" "Expired" "$DAYS hari"
    echo -e "  ${CYN}└─────────────────────────────────────┘${N}"
    echo ""
    echo -ne "  ${W}Konfirmasi buat akun? [y/n]${N} : "; read -r CONFIRM
    [[ ! "$CONFIRM" =~ ^[Yy]$ ]] && echo -e "\n  ${YEL}Dibatalkan${N}\n" && sleep 1 && ssh_menu && return

    if id "$USER" &>/dev/null; then
        echo -e "\n  ${RED}✗ Username '$USER' sudah ada!${N}\n"
        sleep 2; ssh_menu; return
    fi

    local exp_date=$(date -d "+${DAYS} days" +"%Y-%m-%d")
    local exp_show=$(date -d "+${DAYS} days" +"%d %B %Y")

    useradd -e "$exp_date" -s /bin/false -M "$USER" 2>/dev/null
    echo "${USER}:${PASS}" | chpasswd 2>/dev/null
    set_ip_limit "$USER" "$LIMIT_IP"
    echo "#ssh#${USER}#${PASS}#${exp_date}#${LIMIT_IP}" >> "$DB"

    echo -e "\n  ${GRN}✓ Akun berhasil dibuat!${N}"
    show_account "$USER" "$PASS" "$exp_show" "$LIMIT_IP"
    echo -ne "  Tekan Enter untuk kembali..."; read -r
    ssh_menu
}

create_trial() {
    header_ssh
    echo -e "  ${W}Buat Akun SSH Trial (60 Menit)${N}\n"

    local USER="trial-$(cat /dev/urandom | tr -dc 'a-z0-9' | head -c 6)"
    local PASS=$(rnd_pass)
    local exp_date=$(date -d "+60 minutes" +"%Y-%m-%d")
    local exp_time=$(date -d "+60 minutes" +"%H:%M")

    useradd -e "$exp_date" -s /bin/false -M "$USER" 2>/dev/null
    echo "${USER}:${PASS}" | chpasswd 2>/dev/null
    set_ip_limit "$USER" 1
    echo "#ssh_trial#${USER}#${PASS}#$(date -d '+60 minutes' +'%Y-%m-%d %H:%M')#1" >> "$DB"

    show_account "$USER" "$PASS" "60 Menit (s/d $exp_time WIB)" "1"
    echo -ne "  Tekan Enter untuk kembali..."; read -r
    ssh_menu
}

renew_ssh() {
    header_ssh
    echo -e "  ${W}Perpanjang Akun SSH${N}\n"
    list_ssh_table
    echo ""
    echo -ne "  Username  : "; read -r USER
    echo -ne "  Tambah hari : "; read -r DAYS
    [[ -z "$DAYS" || ! "$DAYS" =~ ^[0-9]+$ ]] && DAYS=30

    if ! id "$USER" &>/dev/null; then
        echo -e "\n  ${RED}✗ Username tidak ditemukan!${N}\n"
        sleep 2; ssh_menu; return
    fi

    local new_exp=$(date -d "+${DAYS} days" +"%Y-%m-%d")
    usermod -e "$new_exp" "$USER" 2>/dev/null
    sed -i "s/\(^#ssh[^#]*#${USER}#[^#]*\)#[0-9-]*#/\1#${new_exp}#/" "$DB" 2>/dev/null
    echo -e "\n  ${GRN}✓ Akun '$USER' diperpanjang hingga ${new_exp}${N}\n"
    sleep 2; ssh_menu
}

delete_ssh() {
    header_ssh
    echo -e "  ${W}Hapus Akun SSH${N}\n"
    list_ssh_table
    echo ""
    echo -ne "  Username yang akan dihapus : "; read -r USER

    if ! id "$USER" &>/dev/null; then
        echo -e "\n  ${RED}✗ Username '$USER' tidak ditemukan!${N}\n"
        sleep 2; ssh_menu; return
    fi

    echo -ne "\n  ${RED}Yakin hapus akun '$USER'? [y/n]${N} : "; read -r c
    if [[ "$c" =~ ^[Yy]$ ]]; then
        userdel "$USER" 2>/dev/null
        remove_ip_limit "$USER"
        sed -i "/^#ssh[^#]*#${USER}#/d" "$DB"
        echo -e "\n  ${GRN}✓ Akun '${USER}' berhasil dihapus${N}\n"
    else
        echo -e "\n  ${YEL}Dibatalkan${N}\n"
    fi
    sleep 2; ssh_menu
}

list_ssh_table() {
    local count=0
    echo -e "  ${CYN}┌──────────────────┬──────────────┬────────────┬──────────┐${N}"
    printf  "  ${CYN}│${N} %-18s ${CYN}│${N} %-12s ${CYN}│${N} %-10s ${CYN}│${N} %-8s ${CYN}│${N}\n" \
            "USERNAME" "PASSWORD" "EXPIRED" "LIMIT IP"
    echo -e "  ${CYN}├──────────────────┼──────────────┼────────────┼──────────┤${N}"
    while IFS='#' read -r _ type user pass exp limit; do
        [[ "$type" == "ssh" || "$type" == "ssh_trial" ]] || continue
        [[ "$type" == "ssh_trial" ]] && tag="${YEL}(trial)${N}" || tag=""
        printf  "  ${CYN}│${N} ${W}%-18s${N} ${CYN}│${N} %-12s ${CYN}│${N} ${YEL}%-10s${N} ${CYN}│${N} %-8s ${CYN}│${N}\n" \
                "$user" "$pass" "$exp" "${limit:-2}"
        ((count++))
    done < "$DB"
    [[ $count -eq 0 ]] && printf "  ${CYN}│${N} %-55s ${CYN}│${N}\n" "  Belum ada akun SSH"
    echo -e "  ${CYN}└──────────────────┴──────────────┴────────────┴──────────┘${N}"
    echo -e "  Total: ${GRN}${count}${N} akun"
}

list_ssh() {
    header_ssh
    echo -e "  ${W}Daftar Akun SSH${N}\n"
    list_ssh_table
    echo ""
    echo -ne "  Tekan Enter untuk kembali..."; read -r
    ssh_menu
}

check_user() {
    header_ssh
    echo -e "  ${W}Cek Status User${N}\n"
    echo -ne "  Username : "; read -r USER

    local sessions=$(who 2>/dev/null | grep -c "^$USER " || echo 0)
    local exp=$(chage -l "$USER" 2>/dev/null | grep "Account expires" | cut -d: -f2 | xargs)
    local info=$(grep "^#ssh[^#]*#${USER}#" "$DB" 2>/dev/null | head -1)
    local pass=$(echo "$info" | cut -d'#' -f4)
    local limit=$(echo "$info" | cut -d'#' -f6)

    echo ""
    echo -e "  ${CYN}╭─────────────────────────────────────────╮${N}"
    printf  "  ${CYN}│${N}  %-12s : ${W}%-25s${CYN}│${N}\n" "Username" "$USER"
    printf  "  ${CYN}│${N}  %-12s : %-25s${CYN}│${N}\n" "Password" "${pass:--}"
    printf  "  ${CYN}│${N}  %-12s : ${YEL}%-25s${CYN}│${N}\n" "Expired" "${exp:-Tidak diketahui}"
    printf  "  ${CYN}│${N}  %-12s : %-25s${CYN}│${N}\n" "Limit IP" "${limit:-2} device(s)"
    printf  "  ${CYN}│${N}  %-12s : ${GRN}%-25s${CYN}│${N}\n" "Sesi Aktif" "${sessions} sesi"
    echo -e "  ${CYN}╰─────────────────────────────────────────╯${N}\n"
    echo -ne "  Tekan Enter untuk kembali..."; read -r
    ssh_menu
}

ssh_menu() {
    header_ssh
    echo -e "  ${CYN}┌──────────────────────────────┐${N}"
    echo -e "  ${CYN}│${N}  ${GRN}[1]${N} Buat Akun SSH          ${CYN}│${N}"
    echo -e "  ${CYN}│${N}  ${GRN}[2]${N} Buat Akun Trial 60 Mnt ${CYN}│${N}"
    echo -e "  ${CYN}│${N}  ${GRN}[3]${N} Perpanjang Akun        ${CYN}│${N}"
    echo -e "  ${CYN}│${N}  ${RED}[4]${N} Hapus Akun             ${CYN}│${N}"
    echo -e "  ${CYN}│${N}  ${YEL}[5]${N} Daftar Akun            ${CYN}│${N}"
    echo -e "  ${CYN}│${N}  ${YEL}[6]${N} Cek Status User        ${CYN}│${N}"
    echo -e "  ${CYN}│${N}  ${C}[0]${N} Kembali ke Menu Utama  ${CYN}│${N}"
    echo -e "  ${CYN}└──────────────────────────────┘${N}"
    echo ""
    echo -ne "  ${W}Pilih${N} : "
    read -r opt
    case $opt in
        1) create_ssh ;;
        2) create_trial ;;
        3) renew_ssh ;;
        4) delete_ssh ;;
        5) list_ssh ;;
        6) check_user ;;
        0|q) bash $DIR/menu.sh ;;
        *) ssh_menu ;;
    esac
}

ssh_menu
