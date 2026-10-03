#!/bin/bash

echo -e "\n========================================================"
echo -e "             👑 KING'S ULTIMATE CPU DASHBOARD 👑          "
echo -e "========================================================\n"

# 1. Informasi Hardware Inti
MODEL=$(grep -m 1 'model name' /proc/cpuinfo | awk -F: '{print $2}' | sed 's/^[ \t]*//')
ARCH=$(uname -m)
CORES=$(nproc)
L3_CACHE=$(lscpu | grep -i "L3 cache" | awk -F: '{print $2}' | sed 's/^[ \t]*//' 2>/dev/null)
MAX_FREQ=$(lscpu | grep -i "CPU max MHz" | awk -F: '{print $2}' | sed 's/^[ \t]*//' 2>/dev/null)

echo -e "🖥️  \033[1mINFORMASI HARDWARE\033[0m"
echo -e "   ▪ Model CPU : $MODEL"
echo -e "   ▪ Arsitektur: $ARCH"
echo -e "   ▪ Total Core: $CORES Threads"
echo -e "   ▪ L3 Cache  : ${L3_CACHE:-Tidak terdeteksi}"
echo -e "   ▪ Max Freq  : ${MAX_FREQ:-Tidak terdeteksi} MHz\n"

# 2. Status Sistem Real-Time
GOV=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "N/A")
LOAD=$(cat /proc/loadavg | awk '{print $1", "$2", "$3}')

echo -e "⚙️  \033[1mSTATUS SISTEM\033[0m"
echo -e "   ▪ Governor  : $GOV"
echo -e "   ▪ Load Avg  : $LOAD (1m, 5m, 15m)"

# Suhu CPU
TEMP=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
if [ -n "$TEMP" ]; then
    TEMP_C=$(echo "scale=1; $TEMP / 1000" | bc 2>/dev/null)
    echo -e "   ▪ Suhu CPU  : $TEMP_C°C 🌡️"
fi

# Penggunaan RAM
RAM_USED=$(free -h | awk '/^Mem:/ {print $3}')
RAM_TOT=$(free -h | awk '/^Mem:/ {print $2}')
echo -e "   ▪ RAM Usage : $RAM_USED / $RAM_TOT 🧠\n"

# 3. Kalkulasi Daya (Intel RAPL / Battery Fallback)
echo -e "⚡ \033[1mKONSUMSI DAYA\033[0m (Kalkulasi 1 Detik...)"
if [ -r /sys/class/powercap/intel-rapl:0/energy_uj ]; then
    E1=$(cat /sys/class/powercap/intel-rapl:0/energy_uj)
    sleep 1
    E2=$(cat /sys/class/powercap/intel-rapl:0/energy_uj)
    WATT=$(echo "scale=2; ($E2 - $E1) / 1000000" | bc 2>/dev/null)
    echo -e "   ▪ Power Draw: $WATT Watt 🔋\n"
else
    BATT_DRAW=$(upower -i "$(upower -e 2>/dev/null | grep 'BAT' | head -1)" 2>/dev/null | grep "energy-rate" | awk '{print $2 " " $3}')
    if [ -n "$BATT_DRAW" ]; then
        echo -e "   ▪ Power Draw: $BATT_DRAW (via Baterai) 🔋\n"
    else
        echo -e "   ▪ Power Draw: \033[33mButuh 'sudo' untuk sensor Intel RAPL\033[0m ⚠️\n"
    fi
fi

# 4. Frekuensi Masing-Masing Core
echo -e "📊 \033[1mFREKUENSI PER-CORE (MHz)\033[0m"
grep "cpu MHz" /proc/cpuinfo | awk '{printf "   Core %-2d : %8s MHz\n", NR-1, $4}' | pr -3 -t -w 100

echo -e "\n========================================================"