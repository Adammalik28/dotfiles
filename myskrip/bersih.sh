#!/bin/bash

# --- Warna ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=================================================="
echo -e "       SISTEM PEMBERSIH ARCH LINUX (ADAM)"
echo -e "==================================================${NC}"

# 1. Membersihkan Cache Pacman
echo -e "${YELLOW}[1/4] Membersihkan Cache Pacman (Sisakan 2 versi)...${NC}"
# Menggunakan paccache (bagian dari pacman-contrib)
if command -v paccache &> /dev/null; then
    sudo paccache -r -k 2
else
    echo -e "${RED}paccache tidak ditemukan, jalankan: sudo pacman -S pacman-contrib${NC}"
fi

# 2. Menghapus Paket Orphan (Yatim Piatu)
echo -e "\n${YELLOW}[2/4] Mencari Paket Orphan...${NC}"
ORPHANS=$(pacman -Qtdq)
if [ -z "$ORPHANS" ]; then
    echo -e "${GREEN}✔ Tidak ada paket yatim piatu.${NC}"
else
    sudo pacman -Rns $ORPHANS --noconfirm
fi

# 3. Membersihkan Cache User (~/.cache)
echo -e "\n${YELLOW}[3/4] Membersihkan Cache Aplikasi User...${NC}"
# Kita sisakan folder cache yang penting (seperti ollama/prakerja jika ada)
# Tapi secara umum ~/.cache aman dihapus karena akan dibuat ulang saat aplikasi jalan
find ~/.cache -type f -atime +7 -delete 
echo -e "${GREEN}✔ Cache file yang tidak diakses > 7 hari telah dihapus.${NC}"

# 4. Membersihkan Journalctl Log
echo -e "\n${YELLOW}[4/4] Membatasi Ukuran Log Sistem (Max 50MB)...${NC}"
sudo journalctl --vacuum-size=50M

echo -e "\n${BLUE}=================================================="
echo -e "          PEMBERSIHAN SELESAI! ✨"
echo -e "==================================================${NC}"
