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

read -p "Masukkan nama yang dicari: " NAMA
read -p "Cari di mana? (Kosongkan untuk Home): " INPUT_LOKASI

# Memperbaiki input lokasi
if [ -z "$INPUT_LOKASI" ]; then
    LOKASI=$HOME
elif [ "$INPUT_LOKASI" == "home" ]; then
    LOKASI=$HOME
else
    LOKASI=$INPUT_LOKASI
fi

# Cek apakah folder lokasi benar-benar ada
if [ ! -d "$LOKASI" ]; then
    echo -e "${RED}Error: Lokasi '$LOKASI' tidak ditemukan!${NC}"
    exit 1
fi

echo -e "${YELLOW}Mencari di: $LOKASI...${NC}"

if [ "$OPSI" == "1" ]; then
    # Cari File
    HASIL=$(find "$LOKASI" -type f -iname "*$NAMA*" 2>/dev/null | fzf --height 40% --reverse --header "Gunakan panah untuk memilih file")
else
    # Cari Folder
    HASIL=$(find "$LOKASI" -type d -iname "*$NAMA*" 2>/dev/null | fzf --height 40% --reverse --header "Gunakan panah untuk memilih folder")
fi

if [ -n "$HASIL" ]; then
    echo -e "${GREEN}Terpilih:${NC} $HASIL"
    read -p "Buka lokasi di File Manager? (y/n): " BUKA
    if [[ "$BUKA" == "y" ]]; then
        [ -f "$HASIL" ] && xdg-open "$(dirname "$HASIL")" || xdg-open "$HASIL"
    fi
else
    echo -e "${RED}Pencarian dibatalkan atau tidak ditemukan.${NC}"
fi
