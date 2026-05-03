#!/bin/bash
# ========================================
# Improved Power Manager Script - Versi Diperbaiki
# Untuk Arch Linux + Hyprland (Intel CPU dengan intel_pstate)
# Perbaikan: dynamic battery, max freq hardware, logging, error handling
# ========================================

# CONFIGURATION
CPU_PATH="/sys/devices/system/cpu"
PSTATE_PATH="/sys/devices/system/cpu/intel_pstate"
LOG_FILE="$HOME/.power-manager.log"

# ========================================
# FUNCTIONS
# ========================================

log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [POWER-MANAGER] $1" >> "$LOG_FILE"
}

set_epp() {
    local mode=$1
    local changed=0
    for cpu in $CPU_PATH/cpu[0-9]*; do
        if [ -f "$cpu/cpufreq/energy_performance_preference" ]; then
            echo "$mode" | sudo tee "$cpu/cpufreq/energy_performance_preference" >/dev/null
            changed=1
        fi
    done
    if [ $changed -eq 0 ]; then
        echo "Peringatan: energy_performance_preference tidak ditemukan (bukan Intel pstate?)." >&2
    fi
}

set_max_freq() {
    local freq=$1  # dalam kHz
    for cpu in $CPU_PATH/cpu[0-9]*; do
        if [ -f "$cpu/cpufreq/scaling_max_freq" ]; then
            echo "$freq" | sudo tee "$cpu/cpufreq/scaling_max_freq" >/dev/null
        fi
    done
}

set_unlimited_freq() {
    local max_freq=0
    if [ -f "/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq" ]; then
        max_freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq 2>/dev/null)
    fi
    if [ "$max_freq" -gt 0 ]; then
        set_max_freq "$max_freq"
        echo "Frekuensi maksimum diatur ke batas hardware: $((max_freq / 1000)) MHz"
    else
        echo "Peringatan: Tidak dapat menentukan frekuensi maksimum hardware."
        set_max_freq 9999999  # fallback
    fi
}

set_turbo() {
    local state=$1  # 0 = ON, 1 = OFF
    if [ -f "$PSTATE_PATH/no_turbo" ]; then
        echo "$state" | sudo tee "$PSTATE_PATH/no_turbo" >/dev/null
    else
        echo "Peringatan: intel_pstate/no_turbo tidak ditemukan." >&2
    fi
}

get_battery_path() {
    upower -e | grep -m1 battery || echo "/org/freedesktop/UPower/devices/battery_BAT1"
}

cek_status() {
    echo "--- Status Real-time CPU ---"
    printf "%-10s | %-15s | %-10s\n" "CPU" "Governor" "Freq (MHz)"
    echo "------------------------------------------"
    for CPU_DIR in $CPU_PATH/cpu[0-9]*; do
        CPU_NAME=$(basename "$CPU_DIR")
        GOVERNOR=$(cat "$CPU_DIR/cpufreq/scaling_governor" 2>/dev/null || echo "N/A")
        if [ -f "$CPU_DIR/cpufreq/scaling_cur_freq" ]; then
            FREQ_MHZ=$(($(cat "$CPU_DIR/cpufreq/scaling_cur_freq") / 1000))
        else
            FREQ_MHZ="N/A"
        fi
        printf "%-10s | %-15s | %-10s\n" "$CPU_NAME" "$GOVERNOR" "$FREQ_MHZ"
    done
    echo ""
    BAT_PATH=$(get_battery_path)
    if [ -n "$BAT_PATH" ]; then
        upower -i "$BAT_PATH" | grep -E "percentage|energy-rate|time to empty"
    else
        echo "Tidak ditemukan informasi baterai."
    fi
    echo ""
    if [ -f "$PSTATE_PATH/no_turbo" ]; then
        TURBO_STATE=$(cat "$PSTATE_PATH/no_turbo")
        echo "Turbo: $TURBO_STATE (0=ON, 1=OFF)"
    fi
}

# ========================================
# MENU
# ========================================

echo "=== Power Manager Arch Linux + Hyprland ==="
echo "1. Power-Saver (Ultra Hemat - 1.2GHz, Turbo OFF)"
echo "2. Balanced (Normal Harian - Adaptive)"
echo "3. Performance (Full Power - Turbo ON, Max Freq)"
echo "4. Cek Status"
read -p "Pilih [1-4]: " pil

case $pil in
    1)
        powerprofilesctl set power-saver
        set_epp power
        set_max_freq 1200000
        set_turbo 1
        nbfc set -s 5
        notify-send "Power Manager" "Power Saver Aktif (Limit 1.2GHz, Turbo OFF)"
        log_action "Power-Saver mode activated"
        ;;
    2)
        powerprofilesctl set balanced
        set_epp balance_performance
        set_max_freq 2500000
        set_turbo 0
        nbfc set -s 5
        notify-send "Power Manager" "Balanced Aktif (Adaptive Mode)"
        log_action "Balanced mode activated"
        ;;
    3)
        powerprofilesctl set performance
        set_epp performance
        set_unlimited_freq
        set_turbo 0
        nbfc set -a
        notify-send "Power Manager" "Performance Aktif (Turbo ON, Fan Auto, Max Freq)"
        log_action "Performance mode activated"
        ;;
    4)
        cek_status
        ;;
    *)
        echo "Pilihan tidak valid. Keluar."
        exit 0
        ;;
esac
