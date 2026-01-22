#!/bin/bash

# --- Warna ---
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

MAX_FAN=7200

# Fungsi Keluar Bersih
trap "tput cnorm; clear; exit" SIGINT SIGTERM
tput civis # Sembunyikan kursor

while true; do
    # --- PENGAMBILAN DATA ---
    UPTIME=$(uptime -p | sed 's/up //')
    GOV=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)
    CPU_TEMP=$(sensors | grep "Package id 0" | awk '{print $4}' | tr -d '+')
    
    # GPU Logic
    GPU_MODE=$(envycontrol -q 2>/dev/null)
    if [[ "$GPU_MODE" == *"nvidia"* ]] || [[ "$GPU_MODE" == *"hybrid"* ]]; then
        GPU_INFO=$(nvidia-smi --query-gpu=temperature.gpu,utilization.gpu,memory.used --format=csv,noheader,nounits 2>/dev/null)
        G_TEMP="$(echo $GPU_INFO | cut -d',' -f1)°C"
        G_LOAD="$(echo $GPU_INFO | cut -d',' -f2)%"
        G_MEM="$(echo $GPU_INFO | cut -d',' -f3)MB"
        G_NAME="NVIDIA RTX 3050"
    else
        G_TEMP="$CPU_TEMP"
        G_LOAD="N/A"
        G_MEM="Shared"
        G_NAME="Intel Iris Xe"
    fi

    # Fans
    F1_RPM=$(sensors | grep "fan1" | awk '{print $2}')
    F2_RPM=$(sensors | grep "fan2" | awk '{print $2}')
    F1_P=$(awk "BEGIN {printf \"%.1f\", ($F1_RPM/$MAX_FAN)*100}")
    F2_P=$(awk "BEGIN {printf \"%.1f\", ($F2_RPM/$MAX_FAN)*100}")
    
    # Battery & Power (Clean Up)
    BATT_INFO=$(upower -i $(upower -e | grep 'BAT') 2>/dev/null)
    B_PCT=$(echo "$BATT_INFO" | grep "percentage" | awk '{print $2}')
    B_STAT=$(echo "$BATT_INFO" | grep "state" | awk '{print $2}')
    B_DRAW=$(echo "$BATT_INFO" | grep "energy-rate" | awk '{print $2 " " $3}')
    B_HLT=$(echo "$BATT_INFO" | grep "capacity" | awk '{print $2}' | cut -d'.' -f1) # Ambil angka depan saja

    # Storage Thermal
    S_TEMP=$(sudo smartctl -a /dev/nvme0n1 | grep "Temperature:" | awk '{print $2}' | head -n 1)
    H_TEMP=$(sudo smartctl -a /dev/sda -d ata 2>/dev/null | grep "Temperature_Celsius" | awk '{print $10}' || echo "--")

    # Security (UFW & Ports)
    UFW_ST=$(sudo ufw status | head -n 1 | awk '{print $2}')
    PORT_COUNT=$(sudo ss -tuln | grep LISTEN | wc -l)

    # --- TAMPILAN DASHBOARD ---
    clear
    echo -e "${CYAN}┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}  ${PURPLE}NITRO 5 DASHBOARD${NC} | Active: ${GREEN}%-20s${NC} ${CYAN}│${NC}" "$UPTIME"
    echo -e "${CYAN}├──────────────────────────────────────────────────────────┤${NC}"

    echo -e "  ${BLUE}SYSTEM MODE${NC}"
    printf "  %-12s: ${YELLOW}%-13s${NC} %-12s: ${GREEN}%-10s${NC}\n" "CPU Gov" "$GOV" "GPU Mode" "$GPU_MODE"
    
    echo -e "\n  ${BLUE}THERMAL MONITOR${NC}"
    printf "  %-12s: ${RED}%-13s${NC} %-12s: ${RED}%-10s${NC}\n" "CPU Temp" "$CPU_TEMP" "GPU Temp" "$G_TEMP"
    printf "  %-12s: ${YELLOW}%-13s${NC} %-12s: ${YELLOW}%-10s${NC}\n" "SSD Temp" "${S_TEMP}°C" "HDD Temp" "${H_TEMP}°C"

    echo -e "\n  ${BLUE}COOLING SYSTEM (Max $MAX_FAN RPM)${NC}"
    printf "  %-12s: ${CYAN}%-35s${NC}\n" "Fan 1 (CPU)" "$F1_RPM RPM ($F1_P%)"
    printf "  %-12s: ${CYAN}%-35s${NC}\n" "Fan 2 (GPU)" "$F2_RPM RPM ($F2_P%)"

    echo -e "\n  ${BLUE}GPU DETAILS ($G_NAME)${NC}"
    printf "  %-12s: ${YELLOW}%-13s${NC} %-12s: ${GREEN}%-10s${NC}\n" "Load" "$G_LOAD" "VRAM Used" "$G_MEM"

    echo -e "\n  ${BLUE}ENERGY & BATTERY${NC}"
    printf "  %-12s: ${YELLOW}%-13s${NC} %-12s: ${PURPLE}%-10s${NC}\n" "Status" "${B_STAT^}" "Power" "$B_DRAW"
    printf "  %-12s: ${GREEN}%-13s${NC} %-12s: ${CYAN}%-10s${NC}\n" "Level" "$B_PCT" "Health" "$B_HLT%"

    echo -e "\n  ${BLUE}SECURITY STATUS${NC}"
    printf "  %-12s: ${GREEN}%-13s${NC} %-12s: ${YELLOW}%-10s${NC}\n" "UFW" "${UFW_ST^^}" "Open Ports" "$PORT_COUNT"

    echo -e "\n  ${BLUE}MEMORY USAGE${NC}"
    free -h | awk '/Mem:/ {printf "  RAM       : %s / %s (%s used)\n", $3, $2, $3}'
    
    echo -e "${CYAN}└──────────────────────────────────────────────────────────┘${NC}"
    echo -e "  ${YELLOW}Tip: Tekan CTRL+C untuk kembali ke terminal${NC}"
    
    sleep 1
done
