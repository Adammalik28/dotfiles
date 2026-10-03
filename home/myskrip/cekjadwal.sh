#!/bin/bash
# cekjadwal.sh — tampilan ringkas jadwal kuliah dinamis
# Sumber data: ~/.local/share/jadwal-kuliah/jadwal.tsv via pengingat_jadwal.sh

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "${1:-}" in
    -a|--all)
        "$DIR/pengingat_jadwal.sh" --list
        ;;
    *)
        "$DIR/pengingat_jadwal.sh" --today
        echo -e "\033[2mTip: Jalankan 'jadwal -a' untuk melihat jadwal semua hari\033[0m"
        echo -e "\033[2m     Jalankan 'pengingat_jadwal.sh' untuk menambah/mengedit jadwal\033[0m"
        ;;
esac
