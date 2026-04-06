#!/bin/bash
# ================================================
#   AL STORE TUNNELING - Cleanup Manager
# ================================================

DIR="/etc/vps"
source $DIR/config.conf 2>/dev/null
source $DIR/vmess.sh 2>/dev/null  # provides xray_hot_reload_vmess
source $DIR/vless.sh 2>/dev/null  # provides xray_hot_reload_vless
source $DIR/trojan.sh 2>/dev/null # provides xray_hot_reload_trojan

W='\e[1;37m'  N='\e[0m'
RED='\e[1;31m' GRN='\e[1;32m' YEL='\e[1;33m' CYN='\e[1;36m' C='\e[0;36m'

DB="$DIR/accounts.db"
CFG_VMESS="/etc/xray/vmess.json"
CFG_VLESS="/etc/xray/vless.json"
CFG_TROJAN="/etc/xray/trojan.json"

header_clean() {
    clear
    echo -e "\n  ${CYN}╭─────────────────────────────────────────╮${N}"
    echo -e "  ${CYN}│${N}  ${W}Cleanup & Manajemen Akun${N}$(printf '%17s')${CYN}│${N}"
    echo -e "  ${CYN}╰─────────────────────────────────────────╯${N}\n"
}

delete_expired_ssh() {
    local today=$(date +"%Y-%m-%d")
    local count=0
    local tmp=$(mktemp)

    while IFS='#' read -r _ type user pass exp rest; do
        if [[ "$type" == "ssh" || "$type" == "ssh_trial" ]]; then
            if [[ "$exp" < "$today" || "$exp" == "$today" ]]; then
                userdel "$user" 2>/dev/null && ((count++))
            else
                echo "#${type}#${user}#${pass}#${exp}${rest:+#$rest}" >> "$tmp"
            fi
        else
            echo "#${type}#${user}#${pass}#${exp}${rest:+#$rest}" >> "$tmp"
        fi
    done < "$DB"

    mv "$tmp" "$DB"
    echo $count
}

delete_expired_xray() {
    local today=$(date +"%Y-%m-%d")
    local types=("vmess" "vless" "trojan")
    local count=0

    for t in "${types[@]}"; do
        local tmp=$(mktemp)
        while IFS='#' read -r _ type name val expfull; do
            local exp="${expfull%%#*}"  # Ambil hanya tanggal
            if [[ "$type" == "$t" && ("$exp" < "$today" || "$exp" == "$today") ]]; then
                # Hapus dari xray config
                if [[ -f "$XRAY_CFG" ]]; then
                    python3 -c "
import json
with open('$XRAY_CFG') as f: cfg=json.load(f)
for ib in cfg.get('inbounds',[]):
    tag=ib.get('tag','')
    if '$t' in tag:
        key='password' if '$t'=='trojan' else 'id'
        ib['settings']['clients']=[c for c in ib['settings'].get('clients',[]) if c.get(key)!='$val']
with open('$XRAY_CFG','w') as f: json.dump(cfg,f,indent=2)
" 2>/dev/null
                fi
                ((count++))
            else
                echo "#${type}#${name}#${val}#${expfull}" >> "$tmp"
            fi
        done < "$DB"
        # Merge back
        grep -v "^#${t}#" "$DB" > "${DB}.tmp2" 2>/dev/null
        cat "$tmp" >> "${DB}.tmp2"
        mv "${DB}.tmp2" "$DB"
        rm -f "$tmp"
    done

    [[ $count -gt 0 ]] && systemctl restart xray 2>/dev/null
    echo $count
}

run_cleanup() {
    header_clean
    echo -e "  ${W}Membersihkan akun expired...${N}\n"
    local ssh_del=$(delete_expired_ssh)
    local xray_del=$(delete_expired_xray)
    local total=$((ssh_del + xray_del))

    echo -e "  ${CYN}╭─────────────────────────────────────────╮${N}"
    printf  "  ${CYN}│${N}  %-20s : ${RED}%-17s${CYN}│${N}\n" "SSH dihapus" "${ssh_del} akun"
    printf  "  ${CYN}│${N}  %-20s : ${RED}%-17s${CYN}│${N}\n" "Xray dihapus" "${xray_del} akun"
    printf  "  ${CYN}│${N}  %-20s : ${GRN}%-17s${CYN}│${N}\n" "Total dihapus" "${total} akun"
    echo -e "  ${CYN}╰─────────────────────────────────────────╯${N}\n"
    echo -e "  ${GRN}✓ Pembersihan selesai!${N}\n"
    sleep 2; reduce_menu
}

delete_all_trial() {
    header_clean
    local count=$(grep -c "^#ssh_trial#" "$DB" 2>/dev/null || echo 0)
    echo -e "  Ditemukan ${YEL}${count}${N} akun trial\n"
    echo -ne "  ${RED}Hapus semua akun trial? [y/N]${N} : "; read -r c
    if [[ "$c" =~ ^[Yy]$ ]]; then
        while IFS='#' read -r _ type user _; do
            [[ "$type" == "ssh_trial" ]] && userdel "$user" 2>/dev/null
        done < "$DB"
        sed -i '/^#ssh_trial#/d' "$DB"
        echo -e "\n  ${GRN}✓ ${count} akun trial berhasil dihapus${N}\n"
    else
        echo -e "\n  ${YEL}Dibatalkan${N}\n"
    fi
    sleep 2; reduce_menu
}

show_expired_list() {
    header_clean
    local today=$(date +"%Y-%m-%d")
    echo -e "  ${W}Daftar Akun Expired (s/d hari ini)${N}\n"

    echo -e "  ${CYN}┌────────────────────┬──────────┬────────────┐${N}"
    printf  "  ${CYN}│${N} %-20s ${CYN}│${N} %-8s ${CYN}│${N} %-10s ${CYN}│${N}\n" "NAMA/USER" "TIPE" "EXPIRED"
    echo -e "  ${CYN}├────────────────────┼──────────┼────────────┤${N}"

    local count=0
    while IFS='#' read -r _ type name val exp; do
        [[ -z "$type" || -z "$exp" ]] && continue
        if [[ "$exp" < "$today" || "$exp" == "$today" ]]; then
            printf  "  ${CYN}│${N} ${RED}%-20s${N} ${CYN}│${N} %-8s ${CYN}│${N} ${RED}%-10s${N} ${CYN}│${N}\n" "$name" "$type" "$exp"
            ((count++))
        fi
    done < "$DB"

    [[ $count -eq 0 ]] && printf "  ${CYN}│${N} %-43s ${CYN}│${N}\n" "  Tidak ada akun expired"
    echo -e "  ${CYN}└────────────────────┴──────────┴────────────┘${N}"
    echo -e "  Total expired: ${RED}${count}${N} akun\n"

    echo -ne "  Tekan Enter untuk kembali..."; read -r
    reduce_menu
}

# Mode otomatis (dipanggil dari cron)
if [[ "$1" == "auto" ]]; then
    delete_expired_ssh > /dev/null
    delete_expired_xray > /dev/null
    exit 0
fi

reduce_menu() {
    header_clean
    echo -e "  ${CYN}┌──────────────────────────────┐${N}"
    echo -e "  ${CYN}│${N}  ${GRN}[1]${N} Hapus Akun Expired     ${CYN}│${N}"
    echo -e "  ${CYN}│${N}  ${GRN}[2]${N} Hapus Semua Trial      ${CYN}│${N}"
    echo -e "  ${CYN}│${N}  ${YEL}[3]${N} Lihat Akun Expired     ${CYN}│${N}"
    echo -e "  ${CYN}│${N}  ${C}[0]${N} Kembali ke Menu Utama  ${CYN}│${N}"
    echo -e "  ${CYN}└──────────────────────────────┘${N}"
    echo ""
    echo -ne "  ${W}Pilih${N} : "
    read -r opt
    case $opt in
        1) run_cleanup ;;
        2) delete_all_trial ;;
        3) show_expired_list ;;
        0|q) bash $DIR/menu.sh ;;
        *) reduce_menu ;;
    esac
}

reduce_menu
