#!/bin/bash
# ================================================
#   AL STORE TUNNELING - Trojan Management
# ================================================

DIR="/etc/vps"
source $DIR/config.conf 2>/dev/null

W='\e[1;37m'  N='\e[0m'
RED='\e[1;31m' GRN='\e[1;32m' YEL='\e[1;33m' CYN='\e[1;36m' C='\e[0;36m' Y='\e[0;33m'

DB="$DIR/accounts.db"
XRAY_CFG="${XRAY_CONFIG:-/usr/local/etc/xray/config.json}"
DOMAIN="${DOMAIN:-$(curl -s ifconfig.me 2>/dev/null)}"

rnd_user() { echo "als-$(cat /dev/urandom | tr -dc 'a-z0-9' | head -c 5)"; }
rnd_pass() { cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 16; }

header_trojan() {
    clear
    echo -e "\n  ${CYN}╭─────────────────────────────────────────╮${N}"
    echo -e "  ${CYN}│${N}  ${W}AL STORE TUNNELING - Trojan Manager${N}$(printf '%4s')${CYN}│${N}"
    echo -e "  ${CYN}╰─────────────────────────────────────────╯${N}\n"
}

trojan_link() {
    local pass="$1" host="$2" port="$3" net="$4" path="$5" name="$6"
    local enc_path
    enc_path=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$path'))" 2>/dev/null || echo "$path")
    echo "trojan://${pass}@${host}:${port}?security=tls&sni=${host}&type=${net}&path=${enc_path}#${name}"
}

xray_add_trojan() {
    local pass="$1" name="$2"
    [[ ! -f "$XRAY_CFG" ]] && return
    cp "$XRAY_CFG" "${XRAY_CFG}.bak" 2>/dev/null
    flock -x -w 15 /tmp/als-xray.lock python3 -c "
import json
with open('$XRAY_CFG') as f: cfg = json.load(f)
for ib in cfg.get('inbounds',[]):
    if ib.get('tag') in ('trojan-ws','trojan-grpc','trojan-upgrade'):
        clients = ib['settings'].get('clients',[])
        if not any(c.get('password')=='$pass' for c in clients):
            clients.append({'password':'$pass','email':'${name}@alstore','level':0})
            ib['settings']['clients'] = clients
with open('$XRAY_CFG','w') as f: json.dump(cfg,f,indent=2)
" 2>/dev/null && systemctl reload xray 2>/dev/null || systemctl restart xray 2>/dev/null
}

xray_del_trojan() {
    local pass="$1"
    [[ ! -f "$XRAY_CFG" ]] && return
    cp "$XRAY_CFG" "${XRAY_CFG}.bak" 2>/dev/null
    flock -x -w 15 /tmp/als-xray.lock python3 -c "
import json
with open('$XRAY_CFG') as f: cfg = json.load(f)
for ib in cfg.get('inbounds',[]):
    if ib.get('tag') in ('trojan-ws','trojan-grpc','trojan-upgrade'):
        ib['settings']['clients'] = [c for c in ib['settings'].get('clients',[]) if c.get('password')!='$pass']
with open('$XRAY_CFG','w') as f: json.dump(cfg,f,indent=2)
" 2>/dev/null && systemctl reload xray 2>/dev/null || systemctl restart xray 2>/dev/null
}

show_trojan() {
    local name="$1" pass="$2" exp="$3" limit_ip="$4" quota="$5"
    local SEP="${CYN}————————————————————————————————————${N}"
    local kw=15

    local city isp
    city=$(curl -s --max-time 3 "https://ipinfo.io/city" 2>/dev/null || echo "Singapore")
    isp=$(curl -s --max-time 3 "https://ipinfo.io/org" 2>/dev/null | sed 's/AS[0-9]* //' || echo "N/A")

    local lWSTLS=$(trojan_link  "$pass" "$DOMAIN" "443" "ws"          "/trojan"   "$name")
    local lGRPC=$(trojan_link   "$pass" "$DOMAIN" "443" "grpc"        "trojan"    "$name")
    local lUPTLS=$(trojan_link  "$pass" "$DOMAIN" "443" "httpupgrade" "/uptrojan" "$name")

    echo ""
    echo -e "$SEP"
    printf "%*s\n" $(( (36 + 6) / 2 )) "TROJAN"
    echo -e "$SEP"
    printf "${CYN}%-${kw}s${N}: ${W}%s${N}\n"   "Remarks"       "$name"
    printf "${CYN}%-${kw}s${N}: %s\n"            "CITY"          "$city"
    printf "${CYN}%-${kw}s${N}: %s\n"            "ISP"           "$isp"
    printf "${CYN}%-${kw}s${N}: ${W}%s${N}\n"   "Domain"        "$DOMAIN"
    printf "${CYN}%-${kw}s${N}: %s\n"            "Port TLS"      "443,8443"
    printf "${CYN}%-${kw}s${N}: %s\n"            "Port any"      "2052,2053,8880"
    printf "${CYN}%-${kw}s${N}: ${C}%s${N}\n"   "Password"      "$pass"
    printf "${CYN}%-${kw}s${N}: %s\n"            "Security"      "tls"
    printf "${CYN}%-${kw}s${N}: %s\n"            "network"       "ws,grpc,upgrade"
    printf "${CYN}%-${kw}s${N}: %s\n"            "path ws"       "/trojan"
    printf "${CYN}%-${kw}s${N}: %s\n"            "serviceName"   "trojan"
    printf "${CYN}%-${kw}s${N}: %s\n"            "path upgrade"  "/uptrojan"
    printf "${CYN}%-${kw}s${N}: ${YEL}%s${N}\n" "Expired On"    "$exp"
    printf "${CYN}%-${kw}s${N}: %s\n"            "Limit IP"      "${limit_ip} Device"
    printf "${CYN}%-${kw}s${N}: %s\n"            "Quota"         "${quota} GB"
    echo -e "$SEP"
    printf "%*s\n" $(( (36 + 15) / 2 )) "TROJAN WS TLS"
    echo -e "$SEP"
    echo -e "${C}${lWSTLS}${N}"
    echo -e "$SEP"
    printf "%*s\n" $(( (36 + 11) / 2 )) "TROJAN GRPC"
    echo -e "$SEP"
    echo -e "${C}${lGRPC}${N}"
    echo -e "$SEP"
    printf "%*s\n" $(( (36 + 18) / 2 )) "TROJAN Upgrade TLS"
    echo -e "$SEP"
    echo -e "${C}${lUPTLS}${N}"
    echo -e "$SEP"
    echo ""
}

create_trojan() {
    header_trojan
    echo -e "  ${W}Buat Akun Trojan Baru${N}\n"

    echo -ne "  Username      ${Y}[kosong = random]${N} : "; read -r NAME
    [[ -z "$NAME" ]] && NAME=$(rnd_user)

    echo -ne "  Limit IP      ${Y}[jumlah device]${N}   : "; read -r LIMIT_IP
    [[ -z "$LIMIT_IP" || ! "$LIMIT_IP" =~ ^[0-9]+$ ]] && LIMIT_IP=2

    echo -ne "  Quota (GB)    ${Y}[0 = unlimited]${N}   : "; read -r QUOTA
    [[ -z "$QUOTA" || ! "$QUOTA" =~ ^[0-9]+$ ]] && QUOTA=0

    echo -ne "  Expired (day) ${Y}[default = 30]${N}    : "; read -r DAYS
    [[ -z "$DAYS" || ! "$DAYS" =~ ^[0-9]+$ ]] && DAYS=30

    local PASS=$(rnd_pass)

    echo ""
    echo -e "  ${CYN}┌─────────────────────────────────────┐${N}"
    printf  "  ${CYN}│${N}  %-12s : ${W}%-22s${CYN}│${N}\n" "Username" "$NAME"
    printf  "  ${CYN}│${N}  %-12s : %-22s${CYN}│${N}\n" "Limit IP" "$LIMIT_IP device(s)"
    printf  "  ${CYN}│${N}  %-12s : %-22s${CYN}│${N}\n" "Quota" "${QUOTA} GB (0=unlimited)"
    printf  "  ${CYN}│${N}  %-12s : ${YEL}%-22s${CYN}│${N}\n" "Expired" "$DAYS hari"
    echo -e "  ${CYN}└─────────────────────────────────────┘${N}"
    echo ""
    echo -ne "  ${W}Konfirmasi buat akun? [y/n]${N} : "; read -r CONFIRM
    [[ ! "$CONFIRM" =~ ^[Yy]$ ]] && echo -e "\n  ${YEL}Dibatalkan${N}\n" && sleep 1 && trojan_menu && return

    local exp_date=$(date -d "+${DAYS} days" +"%Y-%m-%d")
    local exp_show=$(date -d "+${DAYS} days" +"%d %B %Y")

    xray_add_trojan "$PASS" "$NAME"
    flock -x -w 10 /tmp/als-db.lock bash -c 'echo "#trojan#${NAME}#${PASS}#${exp_date}#${LIMIT_IP}#${QUOTA}" >> "$DB"'

    echo -e "\n  ${GRN}✓ Akun Trojan berhasil dibuat!${N}"
    show_trojan "$NAME" "$PASS" "$exp_show" "$LIMIT_IP" "$QUOTA"
    echo -ne "  Tekan Enter untuk kembali..."; read -r
    trojan_menu
}

delete_trojan() {
    header_trojan
    echo -e "  ${W}Hapus Akun Trojan${N}\n"
    list_trojan_table
    echo ""
    echo -ne "  Username yang akan dihapus : "; read -r NAME

    if ! grep -q "^#trojan#${NAME}#" "$DB"; then
        echo -e "\n  ${RED}✗ Akun '${NAME}' tidak ditemukan!${N}\n"
        sleep 2; trojan_menu; return
    fi

    echo -ne "\n  ${RED}Yakin hapus akun '$NAME'? [y/n]${N} : "; read -r c
    if [[ "$c" =~ ^[Yy]$ ]]; then
        local PASS=$(grep "^#trojan#${NAME}#" "$DB" | cut -d'#' -f4)
        xray_del_trojan "$PASS"
        flock -x -w 10 /tmp/als-db.lock sed -i "/^#trojan#${NAME}#/d" "$DB"
        echo -e "\n  ${GRN}✓ Akun '${NAME}' berhasil dihapus${N}\n"
    else
        echo -e "\n  ${YEL}Dibatalkan${N}\n"
    fi
    sleep 2; trojan_menu
}

list_trojan_table() {
    local count=0
    echo -e "  ${CYN}┌────────────────┬──────────────────────┬────────────┬──────────┬──────────┐${N}"
    printf  "  ${CYN}│${N} %-16s ${CYN}│${N} %-20s ${CYN}│${N} %-10s ${CYN}│${N} %-8s ${CYN}│${N} %-8s ${CYN}│${N}\n" \
            "NAMA" "PASSWORD" "EXPIRED" "LIMIT IP" "QUOTA GB"
    echo -e "  ${CYN}├────────────────┼──────────────────────┼────────────┼──────────┼──────────┤${N}"
    while IFS='#' read -r _ type name pass exp limit quota; do
        [[ "$type" == "trojan" ]] || continue
        printf  "  ${CYN}│${N} ${W}%-16s${N} ${CYN}│${N} ${C}%-20s${N} ${CYN}│${N} ${YEL}%-10s${N} ${CYN}│${N} %-8s ${CYN}│${N} %-8s ${CYN}│${N}\n" \
                "$name" "$pass" "$exp" "${limit:-2}" "${quota:-0}"
        ((count++))
    done < "$DB"
    [[ $count -eq 0 ]] && printf "  ${CYN}│${N} %-71s ${CYN}│${N}\n" "  Belum ada akun Trojan"
    echo -e "  ${CYN}└────────────────┴──────────────────────┴────────────┴──────────┴──────────┘${N}"
    echo -e "  Total: ${GRN}${count}${N} akun"
}

list_trojan() {
    header_trojan
    echo -e "  ${W}Daftar Akun Trojan${N}\n"
    list_trojan_table
    echo ""
    echo -ne "  Tekan Enter untuk kembali..."; read -r
    trojan_menu
}

trojan_menu() {
    header_trojan
    echo -e "  ${CYN}┌──────────────────────────────┐${N}"
    echo -e "  ${CYN}│${N}  ${GRN}[1]${N} Buat Akun Trojan       ${CYN}│${N}"
    echo -e "  ${CYN}│${N}  ${RED}[2]${N} Hapus Akun Trojan      ${CYN}│${N}"
    echo -e "  ${CYN}│${N}  ${YEL}[3]${N} Daftar Akun Trojan     ${CYN}│${N}"
    echo -e "  ${CYN}│${N}  ${C}[0]${N} Kembali ke Menu Utama  ${CYN}│${N}"
    echo -e "  ${CYN}└──────────────────────────────┘${N}"
    echo ""
    echo -ne "  ${W}Pilih${N} : "
    read -r opt
    case $opt in
        1) create_trojan ;;
        2) delete_trojan ;;
        3) list_trojan ;;
        0|q) bash $DIR/menu.sh ;;
        *) trojan_menu ;;
    esac
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && trojan_menu
