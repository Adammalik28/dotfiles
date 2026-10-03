#!/bin/bash

# Menampilkan judul di terminal
echo -ne "\033]0;SCRCPY POCO F4 BY KING\007"

echo "======================================================="
echo "    MEMULAI OPTIMALISASI RESOLUSI POCO F4..."
echo "======================================================="
echo ""

# 1. Memaksa resolusi layar asli FHD+
echo "[+] Mengatur resolusi sistem ke 1080x2400..."
adb shell wm size 1080x2400

# 2. Mengatur kerapatan piksel agar proporsional
echo "[+] Mengatur kerapatan piksel (DPI) ke 440..."
adb shell wm density 440

# 3. Memaksa restart sistem antarmuka untuk mengurangi bug
echo "[+] Memuat ulang System UI..."
adb shell pkill com.android.systemui
adb shell am force-stop com.miui.home

echo ""
echo "======================================================="
echo "    MENJALANKAN SCRCPY DALAM MODE UKURAN PENUH"
echo "======================================================="
echo ""

# 4. Menjalankan scrcpy dengan batas ukuran maksimal sesuai resolusi baru
scrcpy --max-size=2400

echo ""
echo "======================================================="
echo "    SCRCPY DITUTUP. MENGEMBALIKAN SETELAN AWAL..."
echo "======================================================="
echo ""

# 5. Reset kembali saat scrcpy ditutup agar tidak crash di sistem
adb shell wm size reset
adb shell wm density reset

read -p "Tekan [Enter] untuk keluar..."
