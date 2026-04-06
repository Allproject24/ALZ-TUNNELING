#!/bin/bash
# ================================================
#   AL STORE TUNNELING - VLESS Management
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

header_vless() {
    clear
    echo -e "\n  ${CYN}╭─────────────────────────────────────────╮${N}"
    echo -e "  ${CYN}│${N}  ${W}AL STORE TUNNELING - VLESS Manager${N}$(printf '%5s')${CYN}│${N}"
    echo -e "  ${CYN}╰─────────────────────────────────────────╯${N}\n"
}

vless_link() {
    local uuid="$1" host="$2" port="$3" net="$4" path="$5" tls="$6" name="$7"
    local sec="none"; [[ "$tls" == "tls" ]] && sec="tls"
    local enc_path
    enc_path=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$path'))" 2>/dev/null || echo "$path")
    echo "vless://${uuid}@${host}:${port}?encryption=none&security=${sec}&sni=${host}&type=${net}&path=${enc_path}&fp=chrome#${name}"
}

vless_reality_link() {
    local uuid="$1" host="$2" name="$3"
    local pubkey="${REALITY_PUBKEY:-H506hn2NUT1W1v55K3CV7hQaecE6VjPMSMNtUO1KDB0}"
    local shortid="${REALITY_SHORTID:-f7603b4833894470}"
    echo "vless://${uuid}@${host}:443?encryption=none&security=reality&sni=www.google.com&fp=chrome&pbk=${pubkey}&sid=${shortid}&type=tcp&flow=xtls-rprx-vision#${name}-REALITY"
}

xray_add_vless() {
    local uuid="$1" name="$2"
    [[ ! -f "$XRAY_CFG" ]] && return
    cp "$XRAY_CFG" "${XRAY_CFG}.bak" 2>/dev/null
    flock -x -w 15 /tmp/als-xray.lock python3 -c "
import json
with open('$XRAY_CFG') as f: cfg = json.load(f)
for ib in cfg.get('inbounds',[]):
    tag = ib.get('tag','')
    if tag in ('vless-ws','vless-grpc','vless-upgrade'):
        clients = ib['settings'].get('clients',[])
        if not any(c.get('id')=='$uuid' for c in clients):
            clients.append({'id':'$uuid','flow':'','email':'${name}@alstore','level':0})
            ib['settings']['clients'] = clients
    elif tag == 'vless-reality':
        clients = ib['settings'].get('clients',[])
        if not any(c.get('id')=='$uuid' for c in clients):
            clients.append({'id':'$uuid','flow':'xtls-rprx-vision','email':'${name}@alstore','level':0})
            ib['settings']['clients'] = clients
with open('$XRAY_CFG','w') as f: json.dump(cfg,f,indent=2)
" 2>/dev/null && systemctl restart xray 2>/dev/null
}

xray_del_vless() {
    local uuid="$1"
    [[ ! -f "$XRAY_CFG" ]] && return
    cp "$XRAY_CFG" "${XRAY_CFG}.bak" 2>/dev/null
    flock -x -w 15 /tmp/als-xray.lock python3 -c "
import json
with open('$XRAY_CFG') as f: cfg = json.load(f)
for ib in cfg.get('inbounds',[]):
    if ib.get('tag') in ('vless-ws','vless-grpc','vless-upgrade','vless-reality'):
        ib['settings']['clients'] = [c for c in ib['settings'].get('clients',[]) if c.get('id')!='$uuid']
with open('$XRAY_CFG','w') as f: json.dump(cfg,f,indent=2)
" 2>/dev/null && systemctl restart xray 2>/dev/null
}

show_vless() {
    local name="$1" uuid="$2" exp="$3" limit_ip="$4" quota="$5"
    local SEP="${CYN}————————————————————————————————————${N}"
    local kw=15

    local city isp
    city=$(curl -s --max-time 3 "https://ipinfo.io/city" 2>/dev/null || echo "Singapore")
    isp=$(curl -s --max-time 3 "https://ipinfo.io/org" 2>/dev/null | sed 's/AS[0-9]* //' || echo "N/A")

    local lREALITY=$(vless_reality_link "$uuid" "$DOMAIN" "$name")
    local lWSTLS=$(vless_link   "$uuid" "$DOMAIN" "8443" "ws"          "/vless"   "tls"  "$name")
    local lWSNTLS=$(vless_link  "$uuid" "$DOMAIN" "80"   "ws"          "/vless"   "none" "$name")
    local lGRPC=$(vless_link    "$uuid" "$DOMAIN" "8443" "grpc"        "vless"    "tls"  "$name")
    local lUPTLS=$(vless_link   "$uuid" "$DOMAIN" "8443" "httpupgrade" "/upvless" "tls"  "$name")
    local lUPNTLS=$(vless_link  "$uuid" "$DOMAIN" "80"   "httpupgrade" "/upvless" "none" "$name")

    echo ""
    echo -e "$SEP"
    printf "%*s\n" $(( (36 + 5) / 2 )) "VLESS"
    echo -e "$SEP"
    printf "${CYN}%-${kw}s${N}: ${W}%s${N}\n"   "Remarks"       "$name"
    printf "${CYN}%-${kw}s${N}: %s\n"            "CITY"          "$city"
    printf "${CYN}%-${kw}s${N}: %s\n"            "ISP"           "$isp"
    printf "${CYN}%-${kw}s${N}: ${W}%s${N}\n"   "Domain"        "$DOMAIN"
    printf "${CYN}%-${kw}s${N}: %s\n"            "Port REALITY"  "443 (Xray Direct)"
    printf "${CYN}%-${kw}s${N}: %s\n"            "Port TLS"      "8443"
    printf "${CYN}%-${kw}s${N}: %s\n"            "Port none TLS" "80,8080"
    printf "${CYN}%-${kw}s${N}: %s\n"            "Port any"      "2052,2053,8880"
    printf "${CYN}%-${kw}s${N}: ${C}%s${N}\n"   "id"            "$uuid"
    printf "${CYN}%-${kw}s${N}: %s\n"            "Encryption"    "none"
    printf "${CYN}%-${kw}s${N}: %s\n"            "network"       "tcp(reality),ws,grpc,upgrade"
    printf "${CYN}%-${kw}s${N}: %s\n"            "path ws"       "/vless"
    printf "${CYN}%-${kw}s${N}: %s\n"            "serviceName"   "vless"
    printf "${CYN}%-${kw}s${N}: %s\n"            "path upgrade"  "/upvless"
    printf "${CYN}%-${kw}s${N}: ${YEL}%s${N}\n" "Expired On"    "$exp"
    printf "${CYN}%-${kw}s${N}: %s\n"            "Limit IP"      "${limit_ip} Device"
    printf "${CYN}%-${kw}s${N}: %s\n"            "Quota"         "${quota} GB"
    echo -e "$SEP"
    printf "%*s\n" $(( (36 + 18) / 2 )) "★ VLESS REALITY TCP"
    echo -e "$SEP"
    echo -e "${GRN}${lREALITY}${N}"
    echo -e "$SEP"
    printf "%*s\n" $(( (36 + 14) / 2 )) "VLESS WS TLS"
    echo -e "$SEP"
    echo -e "${C}${lWSTLS}${N}"
    echo -e "$SEP"
    printf "%*s\n" $(( (36 + 16) / 2 )) "VLESS WS NO TLS"
    echo -e "$SEP"
    echo -e "${C}${lWSNTLS}${N}"
    echo -e "$SEP"
    printf "%*s\n" $(( (36 + 10) / 2 )) "VLESS GRPC"
    echo -e "$SEP"
    echo -e "${C}${lGRPC}${N}"
    echo -e "$SEP"
    printf "%*s\n" $(( (36 + 16) / 2 )) "VLESS Upgrade TLS"
    echo -e "$SEP"
    echo -e "${C}${lUPTLS}${N}"
    echo -e "$SEP"
    printf "%*s\n" $(( (36 + 19) / 2 )) "VLESS Upgrade NO TLS"
    echo -e "$SEP"
    echo -e "${C}${lUPNTLS}${N}"
    echo -e "$SEP"
    echo ""
}

create_vless() {
    header_vless
    echo -e "  ${W}Buat Akun VLESS Baru${N}\n"

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
    [[ ! "$CONFIRM" =~ ^[Yy]$ ]] && echo -e "\n  ${YEL}Dibatalkan${N}\n" && sleep 1 && vless_menu && return

    local UUID=$(gen_uuid)
    local exp_date=$(date -d "+${DAYS} days" +"%Y-%m-%d")
    local exp_show=$(date -d "+${DAYS} days" +"%d %B %Y")

    xray_add_vless "$UUID" "$NAME"
    flock -x -w 10 /tmp/als-db.lock bash -c 'echo "#vless#${NAME}#${UUID}#${exp_date}#${LIMIT_IP}#${QUOTA}" >> "$DB"'

    echo -e "\n  ${GRN}✓ Akun VLESS berhasil dibuat!${N}"
    show_vless "$NAME" "$UUID" "$exp_show" "$LIMIT_IP" "$QUOTA"
    echo -ne "  Tekan Enter untuk kembali..."; read -r
    vless_menu
}

delete_vless() {
    header_vless
    echo -e "  ${W}Hapus Akun VLESS${N}\n"
    list_vless_table
    echo ""
    echo -ne "  Username yang akan dihapus : "; read -r NAME

    if ! grep -q "^#vless#${NAME}#" "$DB"; then
        echo -e "\n  ${RED}✗ Akun '${NAME}' tidak ditemukan!${N}\n"
        sleep 2; vless_menu; return
    fi

    echo -ne "\n  ${RED}Yakin hapus akun '$NAME'? [y/n]${N} : "; read -r c
    if [[ "$c" =~ ^[Yy]$ ]]; then
        local UUID=$(grep "^#vless#${NAME}#" "$DB" | cut -d'#' -f4)
        xray_del_vless "$UUID"
        flock -x -w 10 /tmp/als-db.lock sed -i "/^#vless#${NAME}#/d" "$DB"
        echo -e "\n  ${GRN}✓ Akun '${NAME}' berhasil dihapus${N}\n"
    else
        echo -e "\n  ${YEL}Dibatalkan${N}\n"
    fi
    sleep 2; vless_menu
}

list_vless_table() {
    local count=0
    echo -e "  ${CYN}┌────────────────┬──────────────────────────────────────┬────────────┬──────────┬──────────┐${N}"
    printf  "  ${CYN}│${N} %-16s ${CYN}│${N} %-36s ${CYN}│${N} %-10s ${CYN}│${N} %-8s ${CYN}│${N} %-8s ${CYN}│${N}\n" \
            "NAMA" "UUID" "EXPIRED" "LIMIT IP" "QUOTA GB"
    echo -e "  ${CYN}├────────────────┼──────────────────────────────────────┼────────────┼──────────┼──────────┤${N}"
    while IFS='#' read -r _ type name uuid exp limit quota; do
        [[ "$type" == "vless" ]] || continue
        printf  "  ${CYN}│${N} ${W}%-16s${N} ${CYN}│${N} ${C}%-36s${N} ${CYN}│${N} ${YEL}%-10s${N} ${CYN}│${N} %-8s ${CYN}│${N} %-8s ${CYN}│${N}\n" \
                "$name" "$uuid" "$exp" "${limit:-2}" "${quota:-0}"
        ((count++))
    done < "$DB"
    [[ $count -eq 0 ]] && printf "  ${CYN}│${N} %-93s ${CYN}│${N}\n" "  Belum ada akun VLESS"
    echo -e "  ${CYN}└────────────────┴──────────────────────────────────────┴────────────┴──────────┴──────────┘${N}"
    echo -e "  Total: ${GRN}${count}${N} akun"
}

list_vless() {
    header_vless
    echo -e "  ${W}Daftar Akun VLESS${N}\n"
    list_vless_table
    echo ""
    echo -ne "  Tekan Enter untuk kembali..."; read -r
    vless_menu
}

vless_menu() {
    header_vless
    echo -e "  ${CYN}┌──────────────────────────────┐${N}"
    echo -e "  ${CYN}│${N}  ${GRN}[1]${N} Buat Akun VLESS        ${CYN}│${N}"
    echo -e "  ${CYN}│${N}  ${RED}[2]${N} Hapus Akun VLESS       ${CYN}│${N}"
    echo -e "  ${CYN}│${N}  ${YEL}[3]${N} Daftar Akun VLESS      ${CYN}│${N}"
    echo -e "  ${CYN}│${N}  ${C}[0]${N} Kembali ke Menu Utama  ${CYN}│${N}"
    echo -e "  ${CYN}└──────────────────────────────┘${N}"
    echo ""
    echo -ne "  ${W}Pilih${N} : "
    read -r opt
    case $opt in
        1) create_vless ;;
        2) delete_vless ;;
        3) list_vless ;;
        0|q) bash $DIR/menu.sh ;;
        *) vless_menu ;;
    esac
}

vless_menu
