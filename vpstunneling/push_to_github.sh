#!/bin/bash
# ================================================
#   AL STORE TUNNELING
#   Push otomatis ke GitHub via API
#   Jalankan: bash vpstunneling/push_to_github.sh
# ================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GITHUB_REPO="Allproject24/ALZ-TUNNELING"
GITHUB_BRANCH="main"
API="https://api.github.com/repos/${GITHUB_REPO}/contents"

W='\e[1;37m' N='\e[0m'
RED='\e[1;31m' GRN='\e[1;32m' YEL='\e[1;33m' CYN='\e[1;36m'

[[ -z "$GITHUB_TOKEN" ]] && {
    echo -e "${RED}✗ GITHUB_TOKEN tidak ditemukan!${N}"
    exit 1
}

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
    "push_to_github.sh"
    "install.sh"
)

CONFIGS=(
    "configs/xray_config.json"
    "configs/nginx_vpstunnel.conf"
    "configs/als-tunneling.conf"
)

clear
echo -e "${CYN}"
echo -e "  ╭─────────────────────────────────────────╮"
echo -e "  │  ${W}Push ke GitHub: Allproject24/ALZ-TUNNELING${N}${CYN} │"
echo -e "  ╰─────────────────────────────────────────╯${N}"
echo ""

success=0; failed=0

# Fungsi: buat JSON payload pakai node
make_payload() {
    local content="$1" message="$2" sha="$3" branch="$4"
    if [[ -n "$sha" ]]; then
        node -e "
const p={message:process.argv[1],content:process.argv[2],sha:process.argv[3],branch:process.argv[4]};
process.stdout.write(JSON.stringify(p));
" -- "$message" "$content" "$sha" "$branch"
    else
        node -e "
const p={message:process.argv[1],content:process.argv[2],branch:process.argv[3]};
process.stdout.write(JSON.stringify(p));
" -- "$message" "$content" "$branch"
    fi
}

# Fungsi: ambil SHA file dari GitHub
get_sha() {
    local remote_path="$1"
    curl -s \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "${API}/${remote_path}?ref=${GITHUB_BRANCH}" 2>/dev/null | \
        node -e "
let d='';
process.stdin.on('data',c=>d+=c);
process.stdin.on('end',()=>{
    try{const j=JSON.parse(d); process.stdout.write(j.sha||'');}catch(e){}
});
"
}

# Fungsi: push 1 file
push_file() {
    local file="$1"
    local local_path="${SCRIPT_DIR}/${file}"
    [[ ! -f "$local_path" ]] && return

    local content=$(base64 -w 0 "$local_path" 2>/dev/null)
    local remote_path="vpstunneling/${file}"
    local commit_msg="Update ${file} [$(date '+%Y-%m-%d %H:%M')]"
    local sha=$(get_sha "$remote_path")

    local payload=$(make_payload "$content" "$commit_msg" "$sha" "$GITHUB_BRANCH")

    local http_code=$(curl -s -o /dev/null -w "%{http_code}" \
        -X PUT \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "${API}/${remote_path}")

    if [[ "$http_code" == "200" || "$http_code" == "201" ]]; then
        echo -e "  ${GRN}✓${N} ${file}"
        ((success++))
    else
        echo -e "  ${RED}✗${N} ${file} (HTTP $http_code)"
        ((failed++))
    fi
    sleep 0.3
}

# --- Push README.md ---
README=$(cat << 'RDEOF'
# ALZ-TUNNELING Scripts

Script manajemen VPS tunneling untuk **AL STORE TUNNELING**.

## Protokol
- SSH (OpenSSH port 22/80/443, Dropbear 109/143, Squid 3128/8080)
- VMESS (WebSocket & gRPC, TLS/NTLS)
- VLESS (WebSocket & gRPC, TLS/NTLS)
- Trojan (WebSocket & gRPC, TLS)

## Fitur
- Buat/hapus/perpanjang akun dengan konfirmasi y/n
- Limit IP (multi-device) per akun
- Quota bandwidth per akun
- Auto delete akun expired via cron
- Telegram Bot management
- Deploy ke multi-VPS + push GitHub otomatis

## Instalasi VPS Baru
```bash
bash <(curl -s https://raw.githubusercontent.com/Allproject24/ALZ-TUNNELING/main/vpstunneling/install.sh)
```

## Perintah
```bash
menu   # Buka main menu
```

## Deploy Update ke GitHub & VPS
Dari Replit:
```bash
bash vpstunneling/push_to_github.sh
```
Dari VPS:
```bash
bash /etc/vps/deploy.sh
```
RDEOF
)

README_B64=$(echo "$README" | base64 -w 0)
SHA_README=$(get_sha "README.md")

# README langsung di root repo (bukan subfolder)
README_PAYLOAD=$(make_payload "$README_B64" "Update README.md [$(date '+%Y-%m-%d')]" "$SHA_README" "$GITHUB_BRANCH")
HTTP=$(curl -s -o /dev/null -w "%{http_code}" \
    -X PUT \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$README_PAYLOAD" \
    "https://api.github.com/repos/${GITHUB_REPO}/contents/README.md")

[[ "$HTTP" == "200" || "$HTTP" == "201" ]] \
    && echo -e "  ${GRN}✓${N} README.md" \
    || echo -e "  ${RED}✗${N} README.md (HTTP $HTTP)"
sleep 0.3

# --- Push semua script ---
for f in "${SCRIPTS[@]}"; do
    push_file "$f"
done

echo ""
echo -e "  ${CYN}══════════════════════════════════════════${N}"
echo -e "  ${W}Hasil Push:${N}  ${GRN}${success} berhasil${N}  |  ${RED}${failed} gagal${N}"
echo -e "  ${W}Repo   :${N}  https://github.com/${GITHUB_REPO}"
echo -e "  ${W}Branch :${N}  ${GITHUB_BRANCH}"
echo -e "  ${W}Waktu  :${N}  $(date '+%d %b %Y %H:%M:%S')"
echo -e "  ${CYN}══════════════════════════════════════════${N}"
echo ""
