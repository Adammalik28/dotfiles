#!/bin/bash

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=== PENCARIAN FILE & FOLDER ===${NC}"
echo "1. Cari File"
echo "2. Cari Folder"
read -p "Pilih opsi (1/2): " OPSI

if [[ "$OPSI" != "1" && "$OPSI" != "2" ]]; then
    echo -e "${RED}Error: Pilihan harus 1 (File) atau 2 (Folder)!${NC}"
    exit 1
fi

read -p "Masukkan nama yang dicari (bisa dikosongkan): " NAMA
read -p "Cari di mana? (Kosongkan/ketik 'home' untuk $HOME): " INPUT_LOKASI

# Memperbaiki input lokasi (ekspansi tilde ~ dan keyword home)
if [ -z "$INPUT_LOKASI" ] || [ "$INPUT_LOKASI" == "home" ]; then
    LOKASI="$HOME"
else
    LOKASI="${INPUT_LOKASI/#\~/$HOME}"
fi

# Cek apakah folder lokasi benar-benar ada
if [ ! -d "$LOKASI" ]; then
    echo -e "${RED}Error: Lokasi '$LOKASI' tidak ditemukan!${NC}"
    exit 1
fi

echo -e "${YELLOW}Mencari di: $LOKASI...${NC}"

if [ "$OPSI" == "1" ]; then
    # Cari File
    HASIL=$(find "$LOKASI" -type f -iname "*$NAMA*" 2>/dev/null | fzf --height 50% --reverse --header "Pilih file (Esc untuk batal)")
else
    # Cari Folder
    HASIL=$(find "$LOKASI" -type d -iname "*$NAMA*" 2>/dev/null | fzf --height 50% --reverse --header "Pilih folder (Esc untuk batal)")
fi

if [ -n "$HASIL" ]; then
    echo -e "${GREEN}Terpilih:${NC} $HASIL"
    if [ -f "$HASIL" ]; then
        echo -e "${BLUE}Tindakan:${NC} 1) Buka file  2) Buka folder induk  3) Batal"
        read -p "Pilih opsi (1/2/3): " AKSI
        case "$AKSI" in
            1) xdg-open "$HASIL" ;;
            2) xdg-open "$(dirname "$HASIL")" ;;
            *) echo "Selesai." ;;
        esac
    else
        read -p "Buka folder di File Manager? (y/n): " BUKA
        [[ "$BUKA" =~ ^[Yy]$ ]] && xdg-open "$HASIL"
    fi
else
    echo -e "${RED}Pencarian dibatalkan atau tidak ditemukan.${NC}"
fi
