#!/bin/bash
# ================================================
#   AL STORE TUNNELING - Multi Deploy Script
#   Deploy ke: GitHub + VPS (bisa multi VPS)
# ================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Warna
W='\e[1;37m' N='\e[0m'
RED='\e[1;31m' GRN='\e[1;32m' YEL='\e[1;33m' CYN='\e[1;36m'

# ============================================
# KONFIGURASI - Sesuaikan di sini
# ============================================
GITHUB_REPO="Allproject24/ALZ-TUNNELING"
GITHUB_BRANCH="main"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"           # Dari env var Replit

# VPS List (tambah baris baru untuk VPS ke-2, dst)
VPS_LIST=(
    "${VPS_USER:-}:${VPS_PASS:-}:${VPS_HOST:-}:${VPS_PORT:-22}"
    # "user2:pass2:ip2:port2"   # <-- uncomment untuk VPS ke-2
)

SCRIPTS=(
    "menu.sh"
    "ssh.sh"
    "vmess.sh"
    "vless.sh"
    "trojan.sh"
    "services.sh"
    "settings.sh"
    "reduce.sh"
    "bot.sh"
    "deploy.sh"
    "configs/xray.json"
)

# ============================================

log_ok()   { echo -e "  ${GRN}✓${N} $1"; }
log_err()  { echo -e "  ${RED}✗${N} $1"; }
log_info() { echo -e "  ${YEL}→${N} $1"; }

header() {
    clear
    echo -e "${CYN}"
    echo -e "  ╭─────────────────────────────────────────╮"
    echo -e "  │  ${W}AL STORE TUNNELING - Multi Deploy${N}${CYN}       │"
    echo -e "  │  Repo  : ${W}github.com/${GITHUB_REPO}${N}${CYN}  │"
    echo -e "  ╰─────────────────────────────────────────╯${N}"
    echo ""
}

# ============================================
# GITHUB DEPLOY via API
# ============================================
deploy_github() {
    log_info "Memulai push ke GitHub..."
    echo ""

    [[ -z "$GITHUB_TOKEN" ]] && {
        log_err "GITHUB_TOKEN tidak ditemukan! Set env var GITHUB_TOKEN."
        return 1
    }

    local API="https://api.github.com/repos/${GITHUB_REPO}/contents"
    local success=0 failed=0

    for file in "${SCRIPTS[@]}"; do
        local local_path="${SCRIPT_DIR}/${file}"
        [[ ! -f "$local_path" ]] && continue

        local content=$(base64 -w 0 "$local_path" 2>/dev/null)
        local remote_path="vpstunneling/${file}"

        # Ambil SHA file yang ada (untuk update)
        local sha=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
            "${API}/${remote_path}" 2>/dev/null | \
            python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('sha',''))" 2>/dev/null)

        # Buat payload
        local payload
        if [[ -n "$sha" ]]; then
            payload=$(python3 -c "
import json
print(json.dumps({
    'message': 'Update ${file} - $(date +%Y-%m-%d)',
    'content': '$content',
    'sha': '$sha',
    'branch': '$GITHUB_BRANCH'
}))
")
        else
            payload=$(python3 -c "
import json
print(json.dumps({
    'message': 'Add ${file} - $(date +%Y-%m-%d)',
    'content': '$content',
    'branch': '$GITHUB_BRANCH'
}))
")
        fi

        local response=$(curl -s -o /dev/null -w "%{http_code}" \
            -X PUT \
            -H "Authorization: token $GITHUB_TOKEN" \
            -H "Content-Type: application/json" \
            -d "$payload" \
            "${API}/${remote_path}")

        if [[ "$response" == "200" || "$response" == "201" ]]; then
            log_ok "GitHub: ${file}"
            ((success++))
        else
            log_err "GitHub: ${file} (HTTP $response)"
            ((failed++))
        fi

        sleep 0.3  # Hindari rate limit
    done

    echo ""
    echo -e "  ${W}GitHub Summary:${N} ${GRN}${success} berhasil${N} | ${RED}${failed} gagal${N}"
    return 0
}

# ============================================
# VPS DEPLOY via SCP+SSH
# ============================================
deploy_vps() {
    local vps_entry="$1"
    local vps_num="$2"

    IFS=':' read -r user pass host port <<< "$vps_entry"

    [[ -z "$user" || -z "$pass" || -z "$host" ]] && {
        log_err "VPS #${vps_num}: Konfigurasi tidak lengkap, skip."
        return 1
    }

    log_info "Memulai deploy ke VPS #${vps_num} (${host})..."
    echo ""

    # Test koneksi
    if ! sshpass -p "$pass" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
         -p "${port:-22}" "${user}@${host}" "echo OK" &>/dev/null; then
        log_err "VPS #${vps_num}: Tidak bisa konek ke ${host}:${port}"
        return 1
    fi

    # Buat direktori sementara
    sshpass -p "$pass" ssh -o StrictHostKeyChecking=no -p "${port:-22}" \
        "${user}@${host}" "mkdir -p /tmp/als_deploy /tmp/als_deploy/configs" 2>/dev/null

    # Upload semua file
    local success=0 failed=0
    for file in "${SCRIPTS[@]}"; do
        local local_path="${SCRIPT_DIR}/${file}"
        [[ ! -f "$local_path" ]] && continue

        local remote_tmp="/tmp/als_deploy/${file}"
        if sshpass -p "$pass" scp -o StrictHostKeyChecking=no -P "${port:-22}" \
            "$local_path" "${user}@${host}:${remote_tmp}" 2>/dev/null; then
            log_ok "VPS #${vps_num} upload: ${file}"
            ((success++))
        else
            log_err "VPS #${vps_num} upload: ${file}"
            ((failed++))
        fi
    done

    # Install ke /etc/vps/
    sshpass -p "$pass" ssh -o StrictHostKeyChecking=no -p "${port:-22}" \
        "${user}@${host}" "
echo '$pass' | sudo -S bash -c '
    mkdir -p /etc/vps /etc/vps/configs
    cd /tmp/als_deploy
    for f in *.sh; do
        cp \"\$f\" /etc/vps/\$f
        chmod +x /etc/vps/\$f
    done
    [[ -f configs/xray.json ]] && cp configs/xray.json /usr/local/etc/xray/config.json 2>/dev/null
    ln -sf /etc/vps/menu.sh /usr/local/bin/menu 2>/dev/null
    rm -rf /tmp/als_deploy
    echo INSTALL_OK
'
" 2>/dev/null | grep "INSTALL_OK" && log_ok "VPS #${vps_num} install selesai" || log_err "VPS #${vps_num} install gagal"

    echo ""
    echo -e "  ${W}VPS #${vps_num} Summary:${N} ${GRN}${success} berhasil${N} | ${RED}${failed} gagal${N}"
}

# ============================================
# MAIN
# ============================================
header

echo -e "  ${W}Mode Deploy:${N}"
echo -e "  ${CYN}┌──────────────────────────────────┐${N}"
echo -e "  ${CYN}│${N}  ${GRN}[1]${N} Deploy ke GitHub saja       ${CYN}│${N}"
echo -e "  ${CYN}│${N}  ${GRN}[2]${N} Deploy ke VPS saja          ${CYN}│${N}"
echo -e "  ${CYN}│${N}  ${GRN}[3]${N} Deploy ke GitHub + VPS      ${CYN}│${N}"
echo -e "  ${CYN}│${N}  ${RED}[0]${N} Keluar                      ${CYN}│${N}"
echo -e "  ${CYN}└──────────────────────────────────┘${N}"
echo ""
echo -ne "  ${W}Pilih${N} : "
read -r OPT

case "$OPT" in
    1)
        echo -e "\n  ${YEL}=== GITHUB DEPLOY ===${N}\n"
        deploy_github
        ;;
    2)
        echo -e "\n  ${YEL}=== VPS DEPLOY ===${N}\n"
        local_idx=1
        for vps in "${VPS_LIST[@]}"; do
            deploy_vps "$vps" "$local_idx"
            ((local_idx++))
        done
        ;;
    3)
        echo -e "\n  ${YEL}=== GITHUB + VPS DEPLOY ===${N}\n"
        deploy_github
        echo ""
        local_idx=1
        for vps in "${VPS_LIST[@]}"; do
            deploy_vps "$vps" "$local_idx"
            ((local_idx++))
        done
        ;;
    0|q)
        exit 0
        ;;
esac

echo ""
echo -e "  ${GRN}✓ Deploy selesai! $(date '+%d %b %Y %H:%M:%S')${N}\n"
