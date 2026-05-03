#!/bin/bash

# Pastikan environment variabel terbaca
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
export DISPLAY=:0

# Fungsi Notif
kirim_notif() {
    notify-send -u critical -i appointment-soon "PENGINGAT JADWAL" "$1"
}

echo "Skrip Aktif - Menunggu waktu yang tepat..."

while true; do
    HARI=$(date +%A)
    JAM_MENIT=$(date +%H:%M)

    # --- TES KHUSUS HARI RABU (HARI INI) ---
    # Ganti "02:15" dengan 1 menit dari jam Anda sekarang!
    if [[ "$HARI" == "Wednesday" ]]; then
        [[ "$JAM_MENIT" == "02:12" ]] && notify-send "TEST" "Skrip Berhasil Jalan di Hari Rabu!"
    fi

    # JADWAL KULIAH (Tetap Ada)
    case $HARI in
        "Monday"|"Senin")
            [[ "$JAM_MENIT" == "13:40" ]] && kirim_notif "Kuliah Pancasila dimulai dalam 1 jam!"
            [[ "$JAM_MENIT" == "15:30" ]] && kirim_notif "Praktik Kerja Pengabdian Masyarakat dimulai dalam 1 jam!"
            ;;
        "Tuesday"|"Selasa")
            [[ "$JAM_MENIT" == "08:00" ]] && kirim_notif "Kuliah Augmented Reality dimulai dalam 1 jam!"
            ;;
        "Thursday"|"Kamis")
            [[ "$JAM_MENIT" == "09:30" ]] && kirim_notif "Kuliah Mobile Game dimulai dalam 1 jam!"
            ;;
        "Friday"|"Jumat")
            [[ "$JAM_MENIT" == "06:30" ]] && kirim_notif "Kuliah Algoritma Data Mining dimulai dalam 1 jam!"
            [[ "$JAM_MENIT" == "12:00" ]] && kirim_notif "Kuliah Pengembangan Bisnis dimulai dalam 1 jam!"
            ;;
    esac

    # Notifikasi Jaga Rental PS
    if [[ "$JAM_MENIT" == "17:00" ]]; then
        notify-send -u critical -i preferences-desktop-remote-desktop "RENTAL PS" "Waktunya standby jaga rental PS!"
    fi

    sleep 30
done
