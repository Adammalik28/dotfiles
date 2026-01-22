#!/bin/bash

# --- Warna ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${RED}🚀 MEMASUKI MODE NITRO BOOST...${NC}"

# 1. Atur CPU ke Performance
echo -e "${YELLOW}[1/3] Mengatur CPU ke Mode Performance...${NC}"
for CPU in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    echo performance | sudo tee "$CPU" > /dev/null
done

# 2. Bebaskan VRAM (Matikan Ollama sementara jika jalan)
if pgrep -x "ollama" > /dev/null; then
    echo -e "${YELLOW}[2/3] Mematikan Ollama untuk membebaskan VRAM...${NC}"
    systemctl --user stop ollama
    OLLAMA_STOPPED=true
fi

# 3. Jalankan Game (Tekken 7)
echo -e "${GREEN}[3/3] Menjalankan Tekken 7 via Steam/Proton...${NC}"
# Ganti dengan perintah jalankan game kamu, atau panggil alias tekken
~/myskrip/run-tekken7.sh

# --- SETELAH GAME DITUTUP (Cleanup) ---
echo -e "\n${BLUE}🎮 Game ditutup. Mengembalikan settingan sistem...${NC}"

# Kembalikan CPU ke Powersave
for CPU in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    echo powersave | sudo tee "$CPU" > /dev/null
done

# Jalankan kembali Ollama jika tadi dimatikan
if [ "$OLLAMA_STOPPED" = true ]; then
    echo -e "${YELLOW}Menjalankan kembali Ollama...${NC}"
    systemctl --user start ollama
fi

echo -e "${GREEN}Selesai! Sistem kembali ke mode hemat daya.${NC}"
