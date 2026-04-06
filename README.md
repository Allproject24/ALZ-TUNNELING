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
