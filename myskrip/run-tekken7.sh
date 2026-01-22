#!/bin/bash

# Lokasi prefix khusus Tekken 7
export WINEPREFIX=$HOME/games/tekken7

# PERBAIKAN: Gunakan lokasi di /mnt/DRIVE_D
GAME_PATH="/mnt/DRIVE_D/Tekken 7/TEKKEN 7.exe"

# Kalau prefix belum ada → bikin baru
if [ ! -d "$WINEPREFIX" ]; then
    echo "[*] Membuat WINEPREFIX baru..."
    wineboot
    winetricks -q corefonts dxvk
fi

# Jalankan game dengan masuk ke foldernya terlebih dahulu (Penting untuk Wine)
cd "/mnt/DRIVE_D/Tekken 7/"
echo "[*] Menjalankan Tekken 7..."
wine "TEKKEN 7.exe"
