#!/bin/bash

# Fungsi untuk mengecek status CPU saat ini
check_status() {
    echo "--- Status CPU Saat Ini ---"
    printf "%-10s | %-15s | %-10s\n" "CPU" "Governor" "Freq (MHz)"
    echo "------------------------------------------"
    
    for CPU_DIR in /sys/devices/system/cpu/cpu[0-9]*; do
        CPU_NAME=$(basename "$CPU_DIR")
        GOVERNOR=$(cat "$CPU_DIR/cpufreq/scaling_governor" 2>/dev/null || echo "N/A")
        
        # Mengambil frekuensi saat ini (konversi dari kHz ke MHz)
        if [ -f "$CPU_DIR/cpufreq/scaling_cur_freq" ]; then
            FREQ_KHZ=$(cat "$CPU_DIR/cpufreq/scaling_cur_freq")
            FREQ_MHZ=$(($FREQ_KHZ / 1000))
        else
            FREQ_MHZ="N/A"
        fi
        
        printf "%-10s | %-15s | %-10s\n" "$CPU_NAME" "$GOVERNOR" "$FREQ_MHZ"
    done
}

case "$1" in
    1)
        echo "Mengatur ke mode: PERFORMANCE..."
        for CPU in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
            echo performance | sudo tee "$CPU" > /dev/null
        done
        echo "Selesai!"
        ;;
    2)
        echo "Mengatur ke mode: POWERSAVE..."
        for CPU in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
            echo powersave | sudo tee "$CPU" > /dev/null
        done
        echo "Selesai!"
        ;;
    3)
        check_status
        ;;
    *)
        echo "Penggunaan: sudo $0 {1|2|3}"
        echo "  1 = Mode Performance"
        echo "  2 = Mode Powersave"
        echo "  3 = Cek status CPU saat ini"
        ;;
esac
