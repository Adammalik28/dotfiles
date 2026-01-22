#!/bin/bash

# --- Konfigurasi ---
BACKUP_DIR="/mnt/DATA_HDD/Backup_System"
DATE=$(date +%Y-%m-%d_%H-%M)
FILENAME="backup_config_$DATE.tar.gz"

# Warna
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}📦 Memulai Backup ke DATA_HDD...${NC}"

# Pastikan folder backup ada
mkdir -p "$BACKUP_DIR"

# Melakukan kompresi (Zshrc, Hyprland Config, dan MySkrip)
tar -czf "$BACKUP_DIR/$FILENAME" \
    ~/.zshrc \
    ~/.config/hypr \
    ~/myskrip \
    ~/data/catatan.txt

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✔ Backup Berhasil!${NC}"
    echo -e "Lokasi: $BACKUP_DIR/$FILENAME"
    # Hanya simpan 5 backup terakhir agar HDD tidak penuh
    ls -t "$BACKUP_DIR"/backup_config_* | tail -n +6 | xargs -r rm
    echo -e "${BLUE}Hanya 5 backup terbaru yang disimpan.${NC}"
else
    echo -e "${RED}✘ Backup Gagal! Periksa apakah HDD ter-mount.${NC}"
fi
