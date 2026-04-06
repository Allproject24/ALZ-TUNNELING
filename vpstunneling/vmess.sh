#!/bin/bash
# ================================================
#   AL STORE TUNNELING - VMESS Management
# ================================================

DIR="/etc/vps"
source $DIR/config.conf 2>/dev/null

W='\e[1;37m'  N='\e[0m'
RED='\e[1;31m' GRN='\e[1;32m' YEL='\e[1;33m' CYN='\e[1;36m' C='\e[0;36m' Y='\e[0;33m'

DB="$DIR/accounts.db"
XRAY_CFG="${XRAY_CONFIG:-/usr/local/etc/xray/config.json}"
DOMAIN="${DOMAIN:-$(curl -s ifconfig.me 2>/dev/null)}"

rnd_user() { echo "als-$(cat /dev/urandom | tr -dc 'a-z0-9' | head -c 5)"; }
gen_uuid() { cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen 2>/dev/null; }

header_vmess() {
    clear
    echo -e "\n  ${CYN}╭─────────────────────────────────────────╮${N}"
    echo -e "  ${CYN}│${N}  ${W}AL STORE TUNNELING - VMESS Manager${N}$(printf '%5s')${CYN}│${N}"
    echo -e "  ${CYN}╰─────────────────────────────────────────╯${N}\n"
}

vmess_link() {
    local ps="$1" add="$2" port="$3" id="$4" net="$5" path="$6" tls="$7"
    local json="{\"v\":\"2\",\"ps\":\"${ps}\",\"add\":\"${add}\",\"port\":\"${port}\",\"id\":\"${id}\",\"aid\":\"0\",\"net\":\"${net}\",\"path\":\"${path}\",\"type\":\"none\",\"host\":\"${add}\",\"sni\":\"${add}\",\"tls\":\"${tls}\"}"
    echo "vmess://$(echo -n "$json" | base64 -w 0)"
}

xray_add_vmess() {
    local uuid="$1" name="$2" limit_ip="$3"
    [[ ! -f "$XRAY_CFG" ]] && return
    python3 -c "
import json
with open('$XRAY_CFG') as f: cfg = json.load(f)
for ib in cfg.get('inbounds',[]):
    if ib.get('tag') in ('vmess-ws','vmess-grpc'):
        clients = ib['settings'].get('clients',[])
        if not any(c.get('id')=='$uuid' for c in clients):
            clients.append({'id':'$uuid','alterId':0,'email':'${name}@alstore','level':0})
            ib['settings']['clients'] = clients
with open('$XRAY_CFG','w') as f: json.dump(cfg,f,indent=2)
" 2>/dev/null && systemctl restart xray 2>/dev/null
}

xray_del_vmess() {
    local uuid="$1"
    [[ ! -f "$XRAY_CFG" ]] && return
    python3 -c "
import json
with open('$XRAY_CFG') as f: cfg = json.load(f)
for ib in cfg.get('inbounds',[]):
    if ib.get('tag') in ('vmess-ws','vmess-grpc'):
        ib['settings']['clients'] = [c for c in ib['settings'].get('clients',[]) if c.get('id')!='$uuid']
with open('$XRAY_CFG','w') as f: json.dump(cfg,f,indent=2)
" 2>/dev/null && systemctl restart xray 2>/dev/null
}

show_vmess() {
    local name="$1" uuid="$2" exp="$3" limit_ip="$4" quota="$5"
    local lTLS=$(vmess_link "$name" "$DOMAIN" "443" "$uuid" "ws" "/vmess" "tls")
    local lNTLS=$(vmess_link "$name" "$DOMAIN" "80" "$uuid" "ws" "/vmess" "none")
    local lGRPC=$(vmess_link "$name-grpc" "$DOMAIN" "443" "$uuid" "grpc" "vmess" "tls")

    echo ""
    echo -e "  ${CYN}╭─────────────────────────────────────────╮${N}"
    echo -e "  ${CYN}│${N}  ${YEL}✦ Detail Akun VMESS${N}$(printf '%21s')${CYN}│${N}"
    echo -e "  ${CYN}├─────────────────────────────────────────┤${N}"
    printf  "  ${CYN}│${N}  %-12s : ${W}%-25s${CYN}│${N}\n" "Nama" "$name"
    printf  "  ${CYN}│${N}  %-12s : ${GRN}%-25s${CYN}│${N}\n" "Host" "$DOMAIN"
    printf  "  ${CYN}│${N}  %-12s : %-25s${CYN}│${N}\n" "Port TLS" "443 · 8443"
    printf  "  ${CYN}│${N}  %-12s : %-25s${CYN}│${N}\n" "Port NTLS" "80 · 8080"
    printf  "  ${CYN}│${N}  %-12s : ${C}%-25s${CYN}│${N}\n" "UUID" "${uuid:0:25}"
    printf  "  ${CYN}│${N}  %-12s : ${C}%-25s${CYN}│${N}\n" "" "${uuid:25}"
    printf  "  ${CYN}│${N}  %-12s : %-25s${CYN}│${N}\n" "AlterId" "0"
    printf  "  ${CYN}│${N}  %-12s : %-25s${CYN}│${N}\n" "Network" "ws · grpc"
    printf  "  ${CYN}│${N}  %-12s : %-25s${CYN}│${N}\n" "Path WS" "/vmess"
    printf  "  ${CYN}│${N}  %-12s : %-25s${CYN}│${N}\n" "Service GRPC" "vmess"
    printf  "  ${CYN}│${N}  %-12s : ${YEL}%-25s${CYN}│${N}\n" "Expired" "$exp"
    printf  "  ${CYN}│${N}  %-12s : %-25s${CYN}│${N}\n" "Limit IP" "${limit_ip} device(s)"
    printf  "  ${CYN}│${N}  %-12s : %-25s${CYN}│${N}\n" "Quota" "${quota} GB"
    echo -e "  ${CYN}├─────────────────────────────────────────┤${N}"
    echo -e "  ${CYN}│${N}  ${GRN}Link TLS WS${N}$(printf '%29s')${CYN}│${N}"
    # Print link in chunks of 41 chars
    local i=0
    while [[ $i -lt ${#lTLS} ]]; do
        printf  "  ${CYN}│${N}  ${C}%-41s${CYN}│${N}\n" "${lTLS:$i:41}"
        ((i+=41))
    done
    echo -e "  ${CYN}├─────────────────────────────────────────┤${N}"
    echo -e "  ${CYN}│${N}  ${GRN}Link NTLS WS${N}$(printf '%28s')${CYN}│${N}"
    local i=0
    while [[ $i -lt ${#lNTLS} ]]; do
        printf  "  ${CYN}│${N}  ${C}%-41s${CYN}│${N}\n" "${lNTLS:$i:41}"
        ((i+=41))
    done
    echo -e "  ${CYN}╰─────────────────────────────────────────╯${N}\n"
}

create_vmess() {
    header_vmess
    echo -e "  ${W}Buat Akun VMESS Baru${N}\n"

    echo -ne "  Username      ${Y}[kosong = random]${N} : "; read -r NAME
    [[ -z "$NAME" ]] && NAME=$(rnd_user)

    echo -ne "  Limit IP      ${Y}[jumlah device]${N}   : "; read -r LIMIT_IP
    [[ -z "$LIMIT_IP" || ! "$LIMIT_IP" =~ ^[0-9]+$ ]] && LIMIT_IP=2

    echo -ne "  Quota (GB)    ${Y}[0 = unlimited]${N}   : "; read -r QUOTA
    [[ -z "$QUOTA" || ! "$QUOTA" =~ ^[0-9]+$ ]] && QUOTA=0

    echo -ne "  Expired (day) ${Y}[default = 30]${N}    : "; read -r DAYS
    [[ -z "$DAYS" || ! "$DAYS" =~ ^[0-9]+$ ]] && DAYS=30

    echo ""
    echo -e "  ${CYN}┌─────────────────────────────────────┐${N}"
    printf  "  ${CYN}│${N}  %-12s : ${W}%-22s${CYN}│${N}\n" "Username" "$NAME"
    printf  "  ${CYN}│${N}  %-12s : %-22s${CYN}│${N}\n" "Limit IP" "$LIMIT_IP device(s)"
    printf  "  ${CYN}│${N}  %-12s : %-22s${CYN}│${N}\n" "Quota" "${QUOTA} GB (0=unlimited)"
    printf  "  ${CYN}│${N}  %-12s : ${YEL}%-22s${CYN}│${N}\n" "Expired" "$DAYS hari"
    echo -e "  ${CYN}└─────────────────────────────────────┘${N}"
    echo ""
    echo -ne "  ${W}Konfirmasi buat akun? [y/n]${N} : "; read -r CONFIRM
    [[ ! "$CONFIRM" =~ ^[Yy]$ ]] && echo -e "\n  ${YEL}Dibatalkan${N}\n" && sleep 1 && vmess_menu && return

    local UUID=$(gen_uuid)
    local exp_date=$(date -d "+${DAYS} days" +"%Y-%m-%d")
    local exp_show=$(date -d "+${DAYS} days" +"%d %B %Y")

    xray_add_vmess "$UUID" "$NAME" "$LIMIT_IP"
    echo "#vmess#${NAME}#${UUID}#${exp_date}#${LIMIT_IP}#${QUOTA}" >> "$DB"

    echo -e "\n  ${GRN}✓ Akun VMESS berhasil dibuat!${N}"
    show_vmess "$NAME" "$UUID" "$exp_show" "$LIMIT_IP" "$QUOTA"
    echo -ne "  Tekan Enter untuk kembali..."; read -r
    vmess_menu
}

delete_vmess() {
    header_vmess
    echo -e "  ${W}Hapus Akun VMESS${N}\n"
    list_vmess_table
    echo ""
    echo -ne "  Username yang akan dihapus : "; read -r NAME

    if ! grep -q "^#vmess#${NAME}#" "$DB"; then
        echo -e "\n  ${RED}✗ Akun '${NAME}' tidak ditemukan!${N}\n"
        sleep 2; vmess_menu; return
    fi

    echo -ne "\n  ${RED}Yakin hapus akun '$NAME'? [y/n]${N} : "; read -r c
    if [[ "$c" =~ ^[Yy]$ ]]; then
        local UUID=$(grep "^#vmess#${NAME}#" "$DB" | cut -d'#' -f4)
        xray_del_vmess "$UUID"
        sed -i "/^#vmess#${NAME}#/d" "$DB"
        echo -e "\n  ${GRN}✓ Akun '${NAME}' berhasil dihapus${N}\n"
    else
        echo -e "\n  ${YEL}Dibatalkan${N}\n"
    fi
    sleep 2; vmess_menu
}

list_vmess_table() {
    local count=0
    echo -e "  ${CYN}┌────────────────┬──────────────────────────────────────┬────────────┬──────────┬──────────┐${N}"
    printf  "  ${CYN}│${N} %-16s ${CYN}│${N} %-36s ${CYN}│${N} %-10s ${CYN}│${N} %-8s ${CYN}│${N} %-8s ${CYN}│${N}\n" \
            "NAMA" "UUID" "EXPIRED" "LIMIT IP" "QUOTA GB"
    echo -e "  ${CYN}├────────────────┼──────────────────────────────────────┼────────────┼──────────┼──────────┤${N}"
    while IFS='#' read -r _ type name uuid exp limit quota; do
        [[ "$type" == "vmess" ]] || continue
        printf  "  ${CYN}│${N} ${W}%-16s${N} ${CYN}│${N} ${C}%-36s${N} ${CYN}│${N} ${YEL}%-10s${N} ${CYN}│${N} %-8s ${CYN}│${N} %-8s ${CYN}│${N}\n" \
                "$name" "$uuid" "$exp" "${limit:-2}" "${quota:-0}"
        ((count++))
    done < "$DB"
    [[ $count -eq 0 ]] && printf "  ${CYN}│${N} %-93s ${CYN}│${N}\n" "  Belum ada akun VMESS"
    echo -e "  ${CYN}└────────────────┴──────────────────────────────────────┴────────────┴──────────┴──────────┘${N}"
    echo -e "  Total: ${GRN}${count}${N} akun"
}

list_vmess() {
    header_vmess
    echo -e "  ${W}Daftar Akun VMESS${N}\n"
    list_vmess_table
    echo ""
    echo -ne "  Tekan Enter untuk kembali..."; read -r
    vmess_menu
}

vmess_menu() {
    header_vmess
    echo -e "  ${CYN}┌──────────────────────────────┐${N}"
    echo -e "  ${CYN}│${N}  ${GRN}[1]${N} Buat Akun VMESS        ${CYN}│${N}"
    echo -e "  ${CYN}│${N}  ${RED}[2]${N} Hapus Akun VMESS       ${CYN}│${N}"
    echo -e "  ${CYN}│${N}  ${YEL}[3]${N} Daftar Akun VMESS      ${CYN}│${N}"
    echo -e "  ${CYN}│${N}  ${C}[0]${N} Kembali ke Menu Utama  ${CYN}│${N}"
    echo -e "  ${CYN}└──────────────────────────────┘${N}"
    echo ""
    echo -ne "  ${W}Pilih${N} : "
    read -r opt
    case $opt in
        1) create_vmess ;;
        2) delete_vmess ;;
        3) list_vmess ;;
        0|q) bash $DIR/menu.sh ;;
        *) vmess_menu ;;
    esac
}

vmess_menu
