#!/bin/bash

# Warna untuk tampilan agar lebih estetik
BIRU='\033[0;34m'
HIJAU='\033[0;32m'
KUNING='\033[1;33m'
NORMAL='\033[0m'

clear
echo -e "${BIRU}=========================================================================="
echo -e "       JADWAL KULIAH - ADAM RIZKI PUTRA KHOIRI (SMT 6)       "
echo -e "=========================================================================="
echo -e "${NORMAL}"

tampilkan_jadwal() {
    printf "${KUNING}%-10s | %-12s | %-5s | %-6s | %-30s${NORMAL}\n" "HARI" "WAKTU" "RUANG" "SKS" "MATA KULIAH"
    echo "--------------------------------------------------------------------------"
    
    # SENIN
    printf "%-10s | %-12s | %-5s | %-6s | %-30s\n" "Senin" "14:40-16:10" "F24" "2" "Pancasila"
    printf "%-10s | %-12s | %-5s | %-6s | %-30s\n" "Senin" "16:30-17:40" "-" "4" "Praktik Kerja Pengabdian Masy."
    
    # SELASA
    printf "%-10s | %-12s | %-5s | %-6s | %-30s\n" "Selasa" "09:00-10:30" "E21" "4" "Augmented Reality"
    
    # KAMIS
    printf "%-10s | %-12s | %-5s | %-6s | %-30s\n" "Kamis" "10:30-12:00" "E22" "4" "Mobile Game"
    
    # JUMAT
    printf "%-10s | %-12s | %-5s | %-6s | %-30s\n" "Jumat" "07:30-09:00" "E21" "4" "Algoritma Data Mining"
    printf "%-10s | %-12s | %-5s | %-6s | %-30s\n" "Jumat" "13:00-14:30" "F25" "2" "Pengembangan Bisnis"
}

tampilkan_jadwal

echo -e "${BIRU}--------------------------------------------------------------------------"
echo -e "${HIJAU}Total SKS: 20 SKS"
echo -e "${BIRU}==========================================================================${NORMAL}"

# Info Hari Ini dengan Penerjemah Bahasa Indonesia
HARI_EN=$(date +%A)
HARI_ID=$(echo $HARI_EN | sed -e 's/Monday/Senin/g' \
                              -e 's/Tuesday/Selasa/g' \
                              -e 's/Wednesday/Rabu/g' \
                              -e 's/Thursday/Kamis/g' \
                              -e 's/Friday/Jumat/g' \
                              -e 's/Saturday/Sabtu/g' \
                              -e 's/Sunday/Minggu/g')

echo -e "Hari ini: ${KUNING}$HARI_ID${NORMAL}"

# Tambahan: Pesan jika hari ini tidak ada kuliah (Rabu, Sabtu, Minggu)
if [[ "$HARI_ID" == "Rabu" || "$HARI_ID" == "Sabtu" || "$HARI_ID" == "Minggu" ]]; then
    echo -e "${HIJAU}Tidak ada jadwal kuliah hari ini"
fi
