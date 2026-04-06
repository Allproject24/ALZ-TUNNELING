#!/bin/bash
# ================================================
#   AL STORE TUNNELING - VMESS Management
# ================================================

DIR="/etc/vps"
source $DIR/config.conf 2>/dev/null

W='\e[1;37m'  N='\e[0m'
RED='\e[1;31m' GRN='\e[1;32m' YEL='\e[1;33m' CYN='\e[1;36m' C='\e[0;36m' Y='\e[0;33m'

DB="$DIR/accounts.db"
XRAY_CFG="${XRAY_CONFIG:-/etc/xray/vmess.json}"
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
    local json
    json=$(printf '{\n  "v": "2",\n  "ps": "%s",\n  "add": "%s",\n  "port": "%s",\n  "id": "%s",\n  "aid": "0",\n  "net": "%s",\n  "path": "%s",\n  "type": "none",\n  "host": "%s",\n  "sni": "%s",\n  "tls": "%s"\n}\n' \
        "$ps" "$add" "$port" "$id" "$net" "$path" "$add" "$add" "$tls")
    echo "vmess://$(echo -n "$json" | base64 -w 0)"
}

xray_hot_reload_vmess() {
    local api_port=10099
    local all_ok=true
    for tag in vmess-ws vmess-grpc vmess-upgrade; do
        local tmp
        tmp=$(mktemp /tmp/als-ib-XXXXXX.json)
        python3 -c "
import json, sys
try:
    cfg = json.load(open('$XRAY_CFG'))
    for ib in cfg['inbounds']:
        if ib['tag'] == '$tag':
            json.dump({'inbounds':[ib]}, sys.stdout)
            break
except: pass
" > "$tmp" 2>/dev/null
        if [[ -s "$tmp" ]]; then
            xray api rmi --server=127.0.0.1:${api_port} "$tag" >/dev/null 2>&1 || true
            sleep 0.2
            local out
            out=$(xray api adi --server=127.0.0.1:${api_port} "$tmp" 2>&1)
            echo "$out" | grep -qiE "^failed|rpc error" && all_ok=false
        fi
        rm -f "$tmp"
    done
    if [[ "$all_ok" == "false" ]]; then
        systemctl reload xray-vmess 2>/dev/null || systemctl restart xray-vmess 2>/dev/null
    fi
    return 0
}

xray_add_vmess() {
    local uuid="$1" name="$2" limit_ip="$3"
    [[ ! -f "$XRAY_CFG" ]] && return
    cp "$XRAY_CFG" "${XRAY_CFG}.bak" 2>/dev/null
    flock -x -w 15 /tmp/als-xray.lock python3 -c "
import json
with open('$XRAY_CFG') as f: cfg = json.load(f)
for ib in cfg.get('inbounds',[]):
    if ib.get('tag') in ('vmess-ws','vmess-grpc','vmess-upgrade'):
        clients = ib['settings'].get('clients',[])
        if not any(c.get('id')=='$uuid' for c in clients):
            clients.append({'id':'$uuid','alterId':0,'email':'${name}@alstore','level':0})
            ib['settings']['clients'] = clients
with open('$XRAY_CFG','w') as f: json.dump(cfg,f,indent=2)
" 2>/dev/null && xray_hot_reload_vmess || systemctl restart xray-vmess 2>/dev/null
}

xray_del_vmess() {
    local uuid="$1"
    [[ ! -f "$XRAY_CFG" ]] && return
    cp "$XRAY_CFG" "${XRAY_CFG}.bak" 2>/dev/null
    flock -x -w 15 /tmp/als-xray.lock python3 -c "
import json
with open('$XRAY_CFG') as f: cfg = json.load(f)
for ib in cfg.get('inbounds',[]):
    if ib.get('tag') in ('vmess-ws','vmess-grpc','vmess-upgrade'):
        ib['settings']['clients'] = [c for c in ib['settings'].get('clients',[]) if c.get('id')!='$uuid']
with open('$XRAY_CFG','w') as f: json.dump(cfg,f,indent=2)
" 2>/dev/null && xray_hot_reload_vmess || systemctl restart xray-vmess 2>/dev/null
}

show_vmess() {
    local name="$1" uuid="$2" exp="$3" limit_ip="$4" quota="$5"
    local SEP="${CYN}————————————————————————————————————${N}"
    local kw=15

    local city isp
    city=$(curl -s --max-time 3 "https://ipinfo.io/city" 2>/dev/null || echo "Singapore")
    isp=$(curl -s --max-time 3 "https://ipinfo.io/org" 2>/dev/null | sed 's/AS[0-9]* //' || echo "N/A")

    local lWSTLS=$(vmess_link  "$name" "$DOMAIN" "443" "$uuid" "ws"          "/vmess"   "tls")
    local lWSNTLS=$(vmess_link "$name" "$DOMAIN" "80"  "$uuid" "ws"          "/vmess"   "none")
    local lGRPC=$(vmess_link   "$name" "$DOMAIN" "443" "$uuid" "grpc"        "vmess"    "tls")
    local lUPTLS=$(vmess_link  "$name" "$DOMAIN" "443" "$uuid" "httpupgrade" "/upvmess" "tls")
    local lUPNTLS=$(vmess_link "$name" "$DOMAIN" "80"  "$uuid" "httpupgrade" "/upvmess" "none")

    echo ""
    echo -e "$SEP"
    printf "%*s\n" $(( (36 + 5) / 2 )) "VMESS"
    echo -e "$SEP"
    printf "${CYN}%-${kw}s${N}: ${W}%s${N}\n"  "Remarks"       "$name"
    printf "${CYN}%-${kw}s${N}: %s\n"           "CITY"          "$city"
    printf "${CYN}%-${kw}s${N}: %s\n"           "ISP"           "$isp"
    printf "${CYN}%-${kw}s${N}: ${W}%s${N}\n"  "Domain"        "$DOMAIN"
    printf "${CYN}%-${kw}s${N}: %s\n"           "Port TLS"      "443,8443"
    printf "${CYN}%-${kw}s${N}: %s\n"           "Port none TLS" "80,8080"
    printf "${CYN}%-${kw}s${N}: %s\n"           "Port any"      "2052,2053,8880"
    printf "${CYN}%-${kw}s${N}: ${C}%s${N}\n"  "id"            "$uuid"
    printf "${CYN}%-${kw}s${N}: %s\n"           "alterId"       "0"
    printf "${CYN}%-${kw}s${N}: %s\n"           "Security"      "auto"
    printf "${CYN}%-${kw}s${N}: %s\n"           "network"       "ws,grpc,upgrade"
    printf "${CYN}%-${kw}s${N}: %s\n"           "path ws"       "/vmess"
    printf "${CYN}%-${kw}s${N}: %s\n"           "serviceName"   "vmess"
    printf "${CYN}%-${kw}s${N}: %s\n"           "path upgrade"  "/upvmess"
    printf "${CYN}%-${kw}s${N}: ${YEL}%s${N}\n" "Expired On"   "$exp"
    printf "${CYN}%-${kw}s${N}: %s\n"           "Limit IP"      "${limit_ip} Device"
    printf "${CYN}%-${kw}s${N}: %s\n"           "Quota"         "${quota} GB"
    echo -e "$SEP"
    printf "%*s\n" $(( (36 + 14) / 2 )) "VMESS WS TLS"
    echo -e "$SEP"
    echo -e "${C}${lWSTLS}${N}"
    echo -e "$SEP"
    printf "%*s\n" $(( (36 + 16) / 2 )) "VMESS WS NO TLS"
    echo -e "$SEP"
    echo -e "${C}${lWSNTLS}${N}"
    echo -e "$SEP"
    printf "%*s\n" $(( (36 + 10) / 2 )) "VMESS GRPC"
    echo -e "$SEP"
    echo -e "${C}${lGRPC}${N}"
    echo -e "$SEP"
    printf "%*s\n" $(( (36 + 16) / 2 )) "VMESS Upgrade TLS"
    echo -e "$SEP"
    echo -e "${C}${lUPTLS}${N}"
    echo -e "$SEP"
    printf "%*s\n" $(( (36 + 19) / 2 )) "VMESS Upgrade NO TLS"
    echo -e "$SEP"
    echo -e "${C}${lUPNTLS}${N}"
    echo -e "$SEP"
    echo ""
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
        flock -x -w 10 /tmp/als-db.lock sed -i "/^#vmess#${NAME}#/d" "$DB"
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

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && vmess_menu
