#!/bin/bash
# ╔════════════════════════════════════════════════════════╗
# ║        baterai_limit.sh — Acer Battery Health Manager  ║
# ║        by Adam | Hyprland & Arch Linux Setup           ║
# ╚════════════════════════════════════════════════════════╝
#
# Mengontrol batas pengisian daya 80% (Health Mode / Care Mode)
# untuk laptop Acer (Acer Nitro AN515-58 dan seri lainnya)
# menggunakan driver kernel acer-wmi-battery.
#
# Penggunaan:
#   baterai_limit.sh          -> Buka menu interaktif
#   baterai_limit.sh status   -> Cek status limit & info baterai
#   baterai_limit.sh on       -> Aktifkan limit 80%
#   baterai_limit.sh off      -> Nonaktifkan limit (charge 100%)
#   baterai_limit.sh toggle   -> Alihkan status (80% <-> 100%)
#   baterai_limit.sh persist  -> Set agar limit 80% permanen saat boot

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$SCRIPT_DIR/lib.sh" ] && source "$SCRIPT_DIR/lib.sh"

# ─── Warna Fallback jika lib.sh tidak ada ─────────────────
RED=${RED:-$'\033[0;31m'}
GREEN=${GREEN:-$'\033[0;32m'}
YELLOW=${YELLOW:-$'\033[1;33m'}
CYAN=${CYAN:-$'\033[0;36m'}
MAGENTA=${MAGENTA:-$'\033[0;35m'}
BOLD=${BOLD:-$'\033[1m'}
DIM=${DIM:-$'\033[2m'}
RESET=${RESET:-$'\033[0m'}

# ─── Path Sistem & Konfigurasi ───────────────────────────
MODULE_NAME="acer_wmi_battery"
WMI_DRIVER_PATH="/sys/bus/wmi/drivers/acer-wmi-battery"
HEALTH_FILE="$WMI_DRIVER_PATH/health_mode"
TEMP_FILE="$WMI_DRIVER_PATH/temperature"
PERSIST_CONF="/etc/modprobe.d/acer-wmi-battery.conf"

# Cari direktori baterai utama (biasanya BAT1 atau BAT0)
BAT_DIR=""
for b in /sys/class/power_supply/BAT*; do
    if [ -d "$b" ]; then
        BAT_DIR="$b"
        break
    fi
done

# ─── Notifikasi Desktop ───────────────────────────────────
kirim_notif() {
    local judul="$1"
    local pesan="$2"
    local icon="${3:-battery}"
    if command -v notify-send &>/dev/null; then
        notify-send -t 3500 -i "$icon" "$judul" "$pesan"
    fi
}

# ─── Cek & Muat Modul Kernel ──────────────────────────────
pastikan_modul() {
    if [ ! -d "$WMI_DRIVER_PATH" ]; then
        echo -e "${YELLOW}Modul ${BOLD}$MODULE_NAME${RESET}${YELLOW} belum dimuat.${RESET}"
        echo -e "${CYAN}Memuat modul kernel via sudo...${RESET}"
        if sudo modprobe "$MODULE_NAME"; then
            echo -e "${GREEN}✓ Modul berhasil dimuat.${RESET}"
            sleep 0.5
        else
            echo -e "${RED}✖ Gagal memuat modul $MODULE_NAME! Pastikan paket acer-wmi-battery-dkms sudah terpasang.${RESET}" >&2
            return 1
        fi
    fi
    return 0
}

# ─── Baca Status Limit ────────────────────────────────────
# Return: 1 = Aktif (80%), 0 = Nonaktif (100%), 2 = Error/Modul belum aktif
cek_nilai_limit() {
    if [ -f "$HEALTH_FILE" ]; then
        cat "$HEALTH_FILE" 2>/dev/null
    else
        echo "2"
    fi
}

# ─── Tampilkan Status Lengkap ─────────────────────────────
tampil_status() {
    pastikan_modul || return 1

    local status_limit
    status_limit=$(cek_nilai_limit)

    echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${CYAN}║             STATUS KONTROL BATERAI ACER                ║${RESET}"
    echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════╝${RESET}"
    echo ""

    # Status Limit 80%
    echo -n "  • Status Batas Pengisian: "
    case "$status_limit" in
        1)
            echo -e "${BOLD}${GREEN}[ AKTIF — DIBATASI 80% ]${RESET} ${DIM}(Battery Health Mode)${RESET}"
            ;;
        0)
            echo -e "${BOLD}${YELLOW}[ NONAKTIF — MENGISI 100% ]${RESET} ${DIM}(Normal Full Charge)${RESET}"
            ;;
        *)
            echo -e "${BOLD}${RED}[ TIDAK TERDETEKSI / DRIVER BERMASALAH ]${RESET}"
            ;;
    esac

    # Status Auto-Load / Persistensi Boot
    echo -n "  • Persistensi Saat Boot : "
    if [ -f "$PERSIST_CONF" ] && grep -q "enable_health_mode=1" "$PERSIST_CONF" 2>/dev/null; then
        echo -e "${GREEN}Permanen 80%${RESET} ${DIM}($PERSIST_CONF)${RESET}"
    else
        echo -e "${YELLOW}Default / Belum diatur permanen${RESET}"
    fi

    # Suhu Baterai dari Driver WMI
    if [ -f "$TEMP_FILE" ]; then
        local raw_temp
        raw_temp=$(cat "$TEMP_FILE" 2>/dev/null)
        if [ -n "$raw_temp" ] && [ "$raw_temp" -gt 0 ] 2>/dev/null; then
            local temp_c
            temp_c=$(awk "BEGIN {printf \"%.1f\", $raw_temp / 1000}")
            echo -e "  • Suhu Baterai (WMI)    : ${BOLD}${CYAN}${temp_c} °C${RESET}"
        fi
    fi

    # Info Baterai dari sysfs jika ada
    if [ -n "$BAT_DIR" ] && [ -d "$BAT_DIR" ]; then
        echo ""
        echo -e "${BOLD}${CYAN}── Informasi Baterai Fisik (${BAT_DIR##*/}) ───────────────${RESET}"

        local cap stat vnow vdes cnow cfull cdes
        cap=$(cat "$BAT_DIR/capacity" 2>/dev/null || echo "N/A")
        stat=$(cat "$BAT_DIR/status" 2>/dev/null || echo "N/A")

        # Warna kapasitas
        local cap_color="$GREEN"
        if [ "$cap" != "N/A" ]; then
            [ "$cap" -le 30 ] && cap_color="$YELLOW"
            [ "$cap" -le 15 ] && cap_color="$RED"
        fi

        echo -e "  • Daya Tersisa          : ${BOLD}${cap_color}${cap}%${RESET}"
        echo -e "  • Status Daya           : ${BOLD}${stat}${RESET}"

        # Hitung Kesehatan Baterai (Health / Wear Level)
        cfull=$(cat "$BAT_DIR/charge_full" 2>/dev/null || cat "$BAT_DIR/energy_full" 2>/dev/null || echo "")
        cdes=$(cat "$BAT_DIR/charge_full_design" 2>/dev/null || cat "$BAT_DIR/energy_full_design" 2>/dev/null || echo "")
        if [ -n "$cfull" ] && [ -n "$cdes" ] && [ "$cdes" -gt 0 ] 2>/dev/null; then
            local health_pct
            health_pct=$(awk "BEGIN {printf \"%.1f\", ($cfull / $cdes) * 100}")
            echo -e "  • Kesehatan Baterai     : ${BOLD}${health_pct}%${RESET} ${DIM}(Kapasitas maks: ${cfull} / Desain: ${cdes})${RESET}"
        fi

        # Tegangan saat ini
        vnow=$(cat "$BAT_DIR/voltage_now" 2>/dev/null || echo "")
        if [ -n "$vnow" ] && [ "$vnow" -gt 0 ] 2>/dev/null; then
            local volt_v
            volt_v=$(awk "BEGIN {printf \"%.2f\", $vnow / 1000000}")
            echo -e "  • Tegangan              : ${volt_v} V"
        fi
    fi
    echo ""
}

# ─── Aktifkan Limit 80% ───────────────────────────────────
aktifkan_limit() {
    pastikan_modul || return 1

    echo -e "${CYAN}Mengaktifkan limit baterai di 80%...${RESET}"
    if echo 1 | sudo tee "$HEALTH_FILE" >/dev/null; then
        echo -e "${GREEN}✓ Berhasil: Batas pengisian baterai 80% (Health Mode) telah DIAKTIFKAN.${RESET}"
        kirim_notif "🔋 Kontrol Baterai Acer" "Limit 80% DIAKTIFKAN (Health Mode)" "battery-charging"
    else
        echo -e "${RED}✖ Gagal menulis ke $HEALTH_FILE!${RESET}" >&2
        return 1
    fi
}

# ─── Nonaktifkan Limit (Charge 100%) ──────────────────────
nonaktifkan_limit() {
    pastikan_modul || return 1

    echo -e "${CYAN}Menonaktifkan limit baterai (mengisi hingga 100%)...${RESET}"
    if echo 0 | sudo tee "$HEALTH_FILE" >/dev/null; then
        echo -e "${YELLOW}✓ Berhasil: Batas baterai DINONAKTIFKAN (Laptop akan mengisi hingga 100%).${RESET}"
        kirim_notif "⚡ Kontrol Baterai Acer" "Limit dinonaktifkan (Isi penuh hingga 100%)" "battery-full"
    else
        echo -e "${RED}✖ Gagal menulis ke $HEALTH_FILE!${RESET}" >&2
        return 1
    fi
}

# ─── Toggle Limit ─────────────────────────────────────────
toggle_limit() {
    pastikan_modul || return 1
    local current
    current=$(cek_nilai_limit)
    if [ "$current" = "1" ]; then
        nonaktifkan_limit
    else
        aktifkan_limit
    fi
}

# ─── Atur Persistensi Boot ────────────────────────────────
atur_persistensi() {
    echo -e "${BOLD}${CYAN}── Pengaturan Persistensi Boot ──────────────────────────────${RESET}"
    echo "Pengaturan ini memastikan limit 80% langsung aktif otomatis"
    echo "setiap kali Arch Linux dinyalakan (booting)."
    echo ""
    echo -e "File yang akan dikonfigurasi:"
    echo -e "  1. ${CYAN}/etc/modules-load.d/acer-wmi-battery.conf${RESET} (auto-load modul)"
    echo -e "  2. ${CYAN}/etc/modprobe.d/acer-wmi-battery.conf${RESET}     (opsi enable_health_mode=1)"
    echo ""
    read -rp "Terapkan konfigurasi boot permanen sekarang? (y/N): " konfirmasi
    if [[ "$konfirmasi" =~ ^[yY]$ ]]; then
        echo "acer_wmi_battery" | sudo tee /etc/modules-load.d/acer-wmi-battery.conf >/dev/null
        echo "options acer-wmi-battery enable_health_mode=1" | sudo tee /etc/modprobe.d/acer-wmi-battery.conf >/dev/null
        echo -e "${GREEN}✓ Konfigurasi permanen berhasil disimpan!${RESET}"
        kirim_notif "⚙️ Kontrol Baterai Acer" "Persistensi boot 80% berhasil diatur"
    else
        echo -e "${YELLOW}Dibatalkan.${RESET}"
    fi
}

# ─── Menu Interaktif ──────────────────────────────────────
menu_interaktif() {
    while true; do
        clear
        tampil_status

        echo -e "${BOLD}Pilih Aksi:${RESET}"
        echo "  [1] Aktifkan Limit 80% (Health Mode)"
        echo "  [2] Nonaktifkan Limit (Isi Penuh 100%)"
        echo "  [3] Toggle Limit (Alihkan Aktif/Nonaktif)"
        echo "  [4] Simpan Permanen saat Booting"
        echo "  [5] Refresh Status"
        echo "  [0] Keluar"
        echo ""
        read -rp "Masukkan pilihan [0-5]: " pilihan

        case "$pilihan" in
            1)
                echo ""
                aktifkan_limit
                ;;
            2)
                echo ""
                nonaktifkan_limit
                ;;
            3)
                echo ""
                toggle_limit
                ;;
            4)
                echo ""
                atur_persistensi
                ;;
            5)
                continue
                ;;
            0|q|Q)
                echo -e "${DIM}Sampai jumpa!${RESET}"
                exit 0
                ;;
            *)
                echo -e "${RED}Pilihan tidak valid.${RESET}"
                ;;
        esac

        echo ""
        read -rp "Tekan Enter untuk melanjutkan..." _
    done
}

# ─── Main Dispatcher ──────────────────────────────────────
case "${1:-}" in
    status|cek|info)
        tampil_status
        ;;
    on|enable|aktif|80)
        aktifkan_limit
        ;;
    off|disable|nonaktif|100)
        nonaktifkan_limit
        ;;
    toggle|switch)
        toggle_limit
        ;;
    persist|permanen)
        atur_persistensi
        ;;
    *)
        menu_interaktif
        ;;
esac
