#!/bin/bash
# ================================================
#   AL STORE TUNNELING - Auto VPS Deploy
#   Non-interaktif, dipanggil oleh auto_deploy.js
# ================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# VPS List: "user:pass:host:port"
VPS_LIST=(
    "${VPS_USER:-}:${VPS_PASS:-}:${VPS_HOST:-}:${VPS_PORT:-22}"
    # "user2:pass2:host2:22"   # <-- VPS ke-2 (uncomment jika ada)
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
)

deploy_one_vps() {
    local entry="$1" idx="$2"
    IFS=':' read -r user pass host port <<< "$entry"

    [[ -z "$user" || -z "$pass" || -z "$host" ]] && {
        echo "✗ VPS #${idx}: Konfigurasi tidak lengkap, skip."
        return 1
    }

    port="${port:-22}"
    local ok=0 fail=0

    # Test koneksi dulu
    if ! sshpass -p "$pass" ssh -o StrictHostKeyChecking=no \
         -o ConnectTimeout=10 -p "$port" "${user}@${host}" \
         "echo PING" &>/dev/null; then
        echo "✗ VPS #${idx} (${host}): Tidak bisa konek"
        return 1
    fi

    # Buat temp dir di VPS
    sshpass -p "$pass" ssh -o StrictHostKeyChecking=no -p "$port" \
        "${user}@${host}" "mkdir -p /tmp/als_auto" &>/dev/null

    # Upload file satu per satu
    for f in "${SCRIPTS[@]}"; do
        local fpath="${SCRIPT_DIR}/${f}"
        [[ ! -f "$fpath" ]] && continue
        if sshpass -p "$pass" scp -o StrictHostKeyChecking=no \
           -P "$port" "$fpath" "${user}@${host}:/tmp/als_auto/${f}" &>/dev/null; then
            ((ok++))
        else
            echo "✗ VPS #${idx}: gagal upload ${f}"
            ((fail++))
        fi
    done

    # Install ke /etc/vps
    sshpass -p "$pass" ssh -o StrictHostKeyChecking=no -p "$port" \
        "${user}@${host}" "
echo '$pass' | sudo -S bash -c '
cd /tmp/als_auto
for f in *.sh; do
    cp \"\$f\" /etc/vps/\$f 2>/dev/null
    chmod +x /etc/vps/\$f 2>/dev/null
done
ln -sf /etc/vps/menu.sh /usr/local/bin/menu 2>/dev/null
rm -rf /tmp/als_auto
echo INSTALL_OK
' 2>/dev/null
" 2>/dev/null | grep -q "INSTALL_OK" \
    && echo "✓ VPS #${idx} (${host}): ${ok} file deployed" \
    || echo "✗ VPS #${idx} (${host}): Install gagal"
}

# Deploy ke semua VPS
idx=1
for vps in "${VPS_LIST[@]}"; do
    deploy_one_vps "$vps" "$idx"
    ((idx++))
done
