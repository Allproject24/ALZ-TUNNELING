#!/bin/bash
# ================================================
#   KyoStore VPN - Telegram Bot
# ================================================

DIR="/etc/vps"
source $DIR/config.conf 2>/dev/null

W='\e[1;37m'  N='\e[0m'
RED='\e[1;31m' GRN='\e[1;32m' YEL='\e[1;33m' CYN='\e[1;36m' C='\e[0;36m' Y='\e[0;33m'

BOT_SVC="/etc/systemd/system/kyostore-bot.service"
BOT_SCRIPT="$DIR/bot_daemon.sh"

save_cfg() {
    local k="$1" v="$2"
    grep -q "^${k}=" "$DIR/config.conf" 2>/dev/null \
        && sed -i "s|^${k}=.*|${k}=\"${v}\"|" "$DIR/config.conf" \
        || echo "${k}=\"${v}\"" >> "$DIR/config.conf"
}

header_bot() {
    clear
    echo -e "\n  ${CYN}╭─────────────────────────────────────────╮${N}"
    echo -e "  ${CYN}│${N}  ${W}Telegram Bot Manager${N}$(printf '%21s')${CYN}│${N}"
    echo -e "  ${CYN}╰─────────────────────────────────────────╯${N}\n"
}

bot_status() {
    systemctl is-active --quiet kyostore-bot 2>/dev/null \
        && echo -e "${GRN}BERJALAN${N}" || echo -e "${RED}BERHENTI${N}"
}

setup_bot() {
    header_bot
    echo -e "  ${W}Konfigurasi Telegram Bot${N}\n"
    echo -e "  ${YEL}Cara mendapatkan token:${N}"
    echo -e "  1. Chat @BotFather di Telegram"
    echo -e "  2. Ketik /newbot lalu ikuti instruksi"
    echo -e "  3. Copy token yang diberikan\n"
    echo -e "  ${YEL}Cara mendapatkan Chat ID:${N}"
    echo -e "  1. Chat @userinfobot di Telegram"
    echo -e "  2. Ketik /start, lihat 'Id' di respons\n"

    echo -ne "  Bot Token : "; read -r BOT_TOKEN
    echo -ne "  Chat ID Admin : "; read -r CHAT_ID

    [[ -z "$BOT_TOKEN" || -z "$CHAT_ID" ]] && {
        echo -e "\n  ${RED}✗ Token dan Chat ID wajib diisi!${N}\n"
        sleep 2; bot_menu; return
    }

    save_cfg "BOT_TOKEN" "$BOT_TOKEN"
    save_cfg "ADMIN_CHAT_ID" "$CHAT_ID"

    # Buat bot daemon script
    cat > "$BOT_SCRIPT" << 'BOTEOF'
#!/bin/bash
source /etc/vps/config.conf
API="https://api.telegram.org/bot${BOT_TOKEN}"
OFFSET=0
DB="/etc/vps/accounts.db"
DIR="/etc/vps"

send() { curl -s -X POST "${API}/sendMessage" -d "chat_id=$1&text=$2&parse_mode=HTML" > /dev/null; }

rnd() { cat /dev/urandom | tr -dc 'a-z0-9' | head -c "${1:-8}"; }
gen_uuid() { cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen; }

handle_cmd() {
    local chat_id="$1" text="$2" from_id="$3"
    [[ "$from_id" != "$ADMIN_CHAT_ID" ]] && send "$chat_id" "⛔ <b>Akses Ditolak</b>" && return

    read -r cmd arg1 arg2 arg3 <<< "$text"
    case "$cmd" in
        /start)
            send "$chat_id" "✅ <b>KyoStore VPN Bot Aktif!</b>%0A%0AKetik /help untuk bantuan."
            ;;
        /help)
            send "$chat_id" "📋 <b>PERINTAH BOT</b>%0A%0A<b>SSH:</b>%0A/ssh_buat [user] [pass] [hari]%0A/ssh_trial%0A/ssh_hapus [user]%0A/ssh_list%0A%0A<b>VMESS:</b>%0A/vmess_buat [nama] [hari]%0A/vmess_hapus [nama]%0A%0A<b>VLESS:</b>%0A/vless_buat [nama] [hari]%0A/vless_hapus [nama]%0A%0A<b>TROJAN:</b>%0A/trojan_buat [nama] [hari]%0A/trojan_hapus [nama]%0A%0A<b>Lainnya:</b>%0A/status%0A/info%0A/cleanup"
            ;;
        /status)
            local xs=$(systemctl is-active xray 2>/dev/null)
            local ss=$(systemctl is-active ssh 2>/dev/null)
            local ds=$(systemctl is-active dropbear 2>/dev/null)
            local sq=$(systemctl is-active squid 2>/dev/null)
            local ng=$(systemctl is-active nginx 2>/dev/null)
            local ssh_n=$(grep -c '^#ssh#' $DB 2>/dev/null || echo 0)
            local vmess_n=$(grep -c '^#vmess#' $DB 2>/dev/null || echo 0)
            local vless_n=$(grep -c '^#vless#' $DB 2>/dev/null || echo 0)
            local trj_n=$(grep -c '^#trojan#' $DB 2>/dev/null || echo 0)
            send "$chat_id" "🖥 <b>STATUS VPS</b>%0A%0AXray: $xs | SSH: $ss%0ADrop: $ds | Squid: $sq | Nginx: $ng%0A%0A<b>Akun:</b>%0ASSH: $ssh_n | VMESS: $vmess_n%0AVLESS: $vless_n | Trojan: $trj_n"
            ;;
        /info)
            local ip=$(curl -s ifconfig.me 2>/dev/null)
            local os=$(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)
            local ram=$(free -m | awk '/^Mem:/{printf "%s/%s MB",$3,$2}')
            local up=$(uptime -p | sed 's/up //')
            send "$chat_id" "ℹ️ <b>INFO SERVER</b>%0AIP: $ip%0ADomain: $DOMAIN%0AOS: $os%0ARAM: $ram%0AUptime: $up"
            ;;
        /ssh_trial)
            local user="trial-$(rnd 8)" pass="$(rnd 8)"
            local exp=$(date -d '+60 minutes' +'%Y-%m-%d')
            useradd -e "$exp" -s /bin/false -M "$user" 2>/dev/null
            echo "${user}:${pass}" | chpasswd 2>/dev/null
            echo "#ssh_trial#${user}#${pass}#$(date -d '+60 minutes' +'%Y-%m-%d %H:%M')" >> $DB
            send "$chat_id" "✅ <b>SSH TRIAL 60 MENIT</b>%0AHost: $DOMAIN%0AUser: <code>$user</code>%0APass: <code>$pass</code>%0AExp: 60 Menit%0APort: 22 | 109 | 143"
            ;;
        /ssh_buat)
            local user="${arg1:-kyo-$(rnd 6)}" pass="${arg2:-$(rnd 10)}" days="${arg3:-30}"
            local exp=$(date -d "+${days} days" +'%Y-%m-%d')
            useradd -e "$exp" -s /bin/false -M "$user" 2>/dev/null
            echo "${user}:${pass}" | chpasswd 2>/dev/null
            echo "#ssh#${user}#${pass}#${exp}" >> $DB
            send "$chat_id" "✅ <b>AKUN SSH DIBUAT</b>%0AHost: $DOMAIN%0AUser: <code>$user</code>%0APass: <code>$pass</code>%0AExp: $exp%0APort: 22 | 109 | 143 | 3128"
            ;;
        /ssh_hapus)
            userdel "$arg1" 2>/dev/null
            sed -i "/^#ssh[^#]*#${arg1}#/d" $DB
            send "$chat_id" "🗑 Akun SSH <b>$arg1</b> dihapus"
            ;;
        /ssh_list)
            local list=$(grep '^#ssh' $DB | awk -F'#' '{printf "%-15s | %s\n",$3,$5}' | head -20)
            [[ -z "$list" ]] && list="Belum ada akun SSH"
            send "$chat_id" "📋 <b>LIST SSH</b>%0A<pre>$list</pre>"
            ;;
        /vmess_buat)
            local name="${arg1:-kyo-$(rnd 6)}" days="${arg2:-30}"
            local uuid=$(gen_uuid)
            local exp=$(date -d "+${days} days" +'%Y-%m-%d')
            echo "#vmess#${name}#${uuid}#${exp}" >> $DB
            python3 -c "
import json
try:
    with open('/usr/local/etc/xray/config.json') as f: cfg=json.load(f)
    for ib in cfg.get('inbounds',[]):
        if ib.get('tag') in ('vmess-ws','vmess-grpc'):
            ib['settings'].setdefault('clients',[]).append({'id':'$uuid','alterId':0,'email':'${name}@kyo'})
    with open('/usr/local/etc/xray/config.json','w') as f: json.dump(cfg,f,indent=2)
except: pass
" 2>/dev/null
            systemctl restart xray 2>/dev/null
            local link=$(python3 -c "import base64,json; d={'v':'2','ps':'$name','add':'$DOMAIN','port':'443','id':'$uuid','aid':'0','net':'ws','path':'/vmess','type':'none','host':'$DOMAIN','sni':'$DOMAIN','tls':'tls'}; print('vmess://'+base64.b64encode(json.dumps(d).encode()).decode())")
            send "$chat_id" "✅ <b>AKUN VMESS DIBUAT</b>%0ANama: $name%0AHost: $DOMAIN%0AUUID: <code>$uuid</code>%0AExp: $exp%0A%0ALink TLS:%0A<code>$link</code>"
            ;;
        /vmess_hapus)
            local uuid=$(grep "^#vmess#${arg1}#" $DB | cut -d'#' -f4)
            sed -i "/^#vmess#${arg1}#/d" $DB
            send "$chat_id" "🗑 Akun VMESS <b>$arg1</b> dihapus"
            ;;
        /vless_buat)
            local name="${arg1:-kyo-$(rnd 6)}" days="${arg2:-30}"
            local uuid=$(gen_uuid)
            local exp=$(date -d "+${days} days" +'%Y-%m-%d')
            echo "#vless#${name}#${uuid}#${exp}" >> $DB
            local link="vless://${uuid}@${DOMAIN}:443?encryption=none&security=tls&sni=${DOMAIN}&type=ws&path=%2Fvless#${name}"
            send "$chat_id" "✅ <b>AKUN VLESS DIBUAT</b>%0ANama: $name%0AUUID: <code>$uuid</code>%0AExp: $exp%0A%0ALink:%0A<code>$link</code>"
            ;;
        /vless_hapus)
            sed -i "/^#vless#${arg1}#/d" $DB
            send "$chat_id" "🗑 Akun VLESS <b>$arg1</b> dihapus"
            ;;
        /trojan_buat)
            local name="${arg1:-kyo-$(rnd 6)}" days="${arg2:-30}"
            local pass="$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 16)"
            local exp=$(date -d "+${days} days" +'%Y-%m-%d')
            echo "#trojan#${name}#${pass}#${exp}" >> $DB
            local link="trojan://${pass}@${DOMAIN}:443?security=tls&sni=${DOMAIN}&type=ws&path=%2Ftrojan#${name}"
            send "$chat_id" "✅ <b>AKUN TROJAN DIBUAT</b>%0ANama: $name%0APass: <code>$pass</code>%0AExp: $exp%0A%0ALink:%0A<code>$link</code>"
            ;;
        /trojan_hapus)
            sed -i "/^#trojan#${arg1}#/d" $DB
            send "$chat_id" "🗑 Akun Trojan <b>$arg1</b> dihapus"
            ;;
        /cleanup)
            bash $DIR/reduce.sh auto
            send "$chat_id" "✅ Pembersihan akun expired selesai!"
            ;;
        *)
            send "$chat_id" "❓ Perintah tidak dikenal. Ketik /help"
            ;;
    esac
}

while true; do
    resp=$(curl -s "${API}/getUpdates?offset=${OFFSET}&timeout=25" 2>/dev/null)
    updates=$(echo "$resp" | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    for u in d.get('result',[]):
        m=u.get('message',{})
        cid=m.get('chat',{}).get('id','')
        fid=m.get('from',{}).get('id','')
        txt=m.get('text','')
        uid=u.get('update_id',0)
        if txt: print(f'{uid}|{cid}|{fid}|{txt}')
except: pass
" 2>/dev/null)
    while IFS='|' read -r uid cid fid txt; do
        [[ -z "$uid" ]] && continue
        OFFSET=$((uid+1))
        handle_cmd "$cid" "$txt" "$fid" &
    done <<< "$updates"
    sleep 1
done
BOTEOF

    chmod +x "$BOT_SCRIPT"

    cat > "$BOT_SVC" << EOF
[Unit]
Description=KyoStore VPN Telegram Bot
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash ${BOT_SCRIPT}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable kyostore-bot 2>/dev/null
    systemctl restart kyostore-bot 2>/dev/null
    sleep 2

    echo -e "\n  ${GRN}✓ Bot Telegram berhasil dikonfigurasi!${N}"
    echo -e "  Status: $(bot_status)\n"
    sleep 3; bot_menu
}

bot_menu() {
    header_bot
    source $DIR/config.conf 2>/dev/null
    echo -e "  ${CYN}╭─────────────────────────────────────────╮${N}"
    printf  "  ${CYN}│${N}  %-14s : %-23s${CYN}│${N}\n" "Status Bot" "$(bot_status)"
    printf  "  ${CYN}│${N}  %-14s : %-23s${CYN}│${N}\n" "Token" "${BOT_TOKEN:+${BOT_TOKEN:0:15}...}"
    printf  "  ${CYN}│${N}  %-14s : %-23s${CYN}│${N}\n" "Admin Chat ID" "${ADMIN_CHAT_ID:-belum diset}"
    echo -e "  ${CYN}╰─────────────────────────────────────────╯${N}\n"

    echo -e "  ${CYN}┌──────────────────────────────┐${N}"
    echo -e "  ${CYN}│${N}  ${GRN}[1]${N} Setup Bot Telegram     ${CYN}│${N}"
    echo -e "  ${CYN}│${N}  ${GRN}[2]${N} Start Bot              ${CYN}│${N}"
    echo -e "  ${CYN}│${N}  ${RED}[3]${N} Stop Bot               ${CYN}│${N}"
    echo -e "  ${CYN}│${N}  ${YEL}[4]${N} Restart Bot            ${CYN}│${N}"
    echo -e "  ${CYN}│${N}  ${C}[0]${N} Kembali ke Menu Utama  ${CYN}│${N}"
    echo -e "  ${CYN}└──────────────────────────────┘${N}"
    echo ""
    echo -ne "  ${W}Pilih${N} : "
    read -r opt
    case $opt in
        1) setup_bot ;;
        2) systemctl start kyostore-bot 2>/dev/null && echo -e "\n  ${GRN}✓ Bot dijalankan${N}\n" ; sleep 2; bot_menu ;;
        3) systemctl stop kyostore-bot 2>/dev/null && echo -e "\n  ${GRN}✓ Bot dihentikan${N}\n" ; sleep 2; bot_menu ;;
        4) systemctl restart kyostore-bot 2>/dev/null && echo -e "\n  ${GRN}✓ Bot direstart${N}\n" ; sleep 2; bot_menu ;;
        0|q) bash $DIR/menu.sh ;;
        *) bot_menu ;;
    esac
}

bot_menu
