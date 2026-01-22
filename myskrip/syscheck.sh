#!/bin/bash

# --- Warna ---
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo -e "${CYAN}=================================================="
echo -e "        ACER NITRO 5 - ULTIMATE SYSCHECK"
echo -e "==================================================${NC}"

# 1. HARDWARE MODE
GOV=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "N/A")
GPU_MODE=$(envycontrol -q 2>/dev/null || echo "integrated")
echo -e "${BLUE}[HARDWARE MODE]${NC}"
echo -e "CPU Governor : ${YELLOW}$GOV${NC}"
echo -e "GPU Mode     : ${GREEN}$GPU_MODE${NC}"

# 2. THERMAL & FANS (DENGAN PERSENTASE)
echo -e "\n${BLUE}[THERMAL & FANS]${NC}"
CPU_TEMP=$(sensors | grep "Package id 0" | awk '{print $4}' | tr -d '+')

# Ambil angka RPM saja untuk kalkulasi
FAN1_RPM=$(sensors | grep "fan1" | awk '{print $2}')
FAN2_RPM=$(sensors | grep "fan2" | awk '{print $2}')
MAX_FAN=7200

# Kalkulasi Persentase (menggunakan awk untuk angka desimal)
if [ ! -z "$FAN1_RPM" ] && [ "$FAN1_RPM" -ne 0 ]; then
    FAN1_PERC=$(awk "BEGIN {printf \"%.1f\", ($FAN1_RPM/$MAX_FAN)*100}")
    FAN1_DISPLAY="$FAN1_RPM RPM ($FAN1_PERC%)"
else
    FAN1_DISPLAY="0 RPM (0%)"
fi

if [ ! -z "$FAN2_RPM" ] && [ "$FAN2_RPM" -ne 0 ]; then
    FAN2_PERC=$(awk "BEGIN {printf \"%.1f\", ($FAN2_RPM/$MAX_FAN)*100}")
    FAN2_DISPLAY="$FAN2_RPM RPM ($FAN2_PERC%)"
else
    FAN2_DISPLAY="0 RPM (0%)"
fi

# Deteksi GPU Aktif & Suhu
if [[ "$GPU_MODE" == *"nvidia"* ]] || [[ "$GPU_MODE" == *"hybrid"* ]]; then
    GPU_NAME="NVIDIA RTX 3050"
    GPU_TEMP_VAL=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null)
    GPU_TEMP="${GPU_TEMP_VAL:-OFF}°C"
else
    GPU_NAME="Intel Iris Xe (Integrated)"
    GPU_TEMP=$(sensors | grep "Package id 0" | awk '{print $4}' | tr -d '+')
fi

echo -e "CPU Temp     : ${YELLOW}${CPU_TEMP:-N/A}${NC}"
echo -e "GPU Temp     : ${GREEN}${GPU_TEMP} (${GPU_NAME})${NC}"
echo -e "Fan 1 (CPU)  : ${CYAN}$FAN1_DISPLAY${NC}"
echo -e "Fan 2 (GPU)  : ${CYAN}$FAN2_DISPLAY${NC}"

# 3. BATTERY & POWER DETAILS
echo -e "\n${BLUE}[BATTERY & POWER]${NC}"
# Menggunakan upower untuk info detail
BATT_INFO=$(upower -i $(upower -e | grep 'BAT') 2>/dev/null)
BATT_PCT=$(echo "$BATT_INFO" | grep "percentage" | awk '{print $2}')
BATT_STAT=$(echo "$BATT_INFO" | grep "state" | awk '{print $2}')
BATT_DRAW=$(echo "$BATT_INFO" | grep "energy-rate" | awk '{print $2 " " $3}')
BATT_HEALTH=$(echo "$BATT_INFO" | grep "capacity" | awk '{print $2}')

echo -e "Status       : ${YELLOW}${BATT_STAT^}${NC}"
echo -e "Percentage   : ${GREEN}$BATT_PCT${NC}"
echo -e "Power Draw   : ${PURPLE}$BATT_DRAW${NC}"
echo -e "Health/Cap   : ${CYAN}${BATT_HEALTH}${NC}"

# 4. STORAGE TEMPERATURE (SSD & HDD)
echo -e "\n${BLUE}[STORAGE THERMAL]${NC}"
# NVME (SSD Utama)
SSD_TEMP=$(sudo smartctl -a /dev/nvme0n1 | grep "Temperature:" | awk '{print $2 " " $3}' | head -n 1)
# HDD/SATA (Jika ada)
HDD_TEMP=$(sudo smartctl -a /dev/sda -d ata 2>/dev/null | grep "Temperature_Celsius" | awk '{print $10}' || echo "N/A")

echo -e "SSD NVMe     : ${YELLOW}${SSD_TEMP:-N/A}${NC}"
[ "$HDD_TEMP" != "N/A" ] && echo -e "HDD SATA     : ${YELLOW}$HDD_TEMP °C${NC}"

# 5. MEMORY
echo -e "\n${BLUE}[MEMORY]${NC}"
printf "  %-10s %-10s %-10s\n" "TYPE" "USED" "FREE"
free -h | awk '/Mem:/ {printf "  %-10s %-10s %-10s\n", "RAM", $3, $4} /Swap:/ {printf "  %-10s %-10s %-10s\n", "SWAP", $3, $4}'

# 6. STORAGE USAGE
echo -e "\n${BLUE}[STORAGE USAGE]${NC}"
(printf "MOUNT SIZE USED AVAIL USE%%\n" ; df -h | grep -E '^/dev/nvme|^/dev/sda|^/dev/sdb' | awk '{print $6 " " $2 " " $3 " " $4 " " $5}') | column -t | sed 's/^/  /'

# 7. SECURITY (FIREWALL & PORTS)
echo -e "\n${PURPLE}[SECURITY]${NC}"
UFW_STATUS=$(sudo ufw status | head -n 1 | awk '{print $2}')
echo -e "UFW Status   : ${GREEN}${UFW_STATUS^^}${NC}"
printf "  ${YELLOW}%-10s %-20s${NC}\n" "PORT" "SERVICE"
sudo ss -tulnpH | awk '{split($5,a,":"); p=a[length(a)]; split($7,b,"\""); pr=b[2]; if(pr=="") pr="-"; print p " " pr}' | sort -un | head -n 5 | while read -r p pr; do
    printf "  %-10s %-20s\n" "$p" "$pr"
done

echo -e "\n${CYAN}==================================================${NC}"
