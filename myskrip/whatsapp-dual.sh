#!/bin/bash

# Folder config terpisah
CONFIG1="$HOME/.config/whatsdesk-1"
CONFIG2="$HOME/.config/whatsdesk-2"

# Buat folder kalau belum ada
mkdir -p "$CONFIG1" "$CONFIG2"

case "$1" in
  1)
    echo "Menjalankan Whatsdesk (Akun 1)..."
    /usr/bin/whatsdesk --user-data-dir="$CONFIG1" > /dev/null 2>&1 & disown
    ;;
  2)
    echo "Menjalankan Whatsdesk (Akun 2)..."
    /usr/bin/whatsdesk --user-data-dir="$CONFIG2" > /dev/null 2>&1 & disown
    ;;
  *)
    echo "Usage: $0 {1|2}"
    echo "  1 = buka akun WhatsApp pertama"
    echo "  2 = buka akun WhatsApp kedua"
    ;;
esac
