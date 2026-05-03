#!/bin/bash

GAME_DIR="/mnt/new_windows/Story of Seasons Grand Bazaar"
GAME_EXE="SOSGrandBazaar.exe"
LOGFILE="$HOME/.local/share/sos.log"

echo "=== Launching Game ==="

# Cek folder
if [ ! -d "$GAME_DIR" ]; then
  echo "Folder tidak ditemukan: $GAME_DIR"
  exit 1
fi

cd "$GAME_DIR" || exit 1

# Cek file exe
if [ ! -f "$GAME_EXE" ]; then
  echo "File EXE tidak ditemukan!"
  exit 1
fi

# Run
echo "Menjalankan game..."
prime-run wine "$GAME_EXE" &> "$LOGFILE"

echo "Game selesai / crash. Log tersimpan di:"
echo "$LOGFILE"
