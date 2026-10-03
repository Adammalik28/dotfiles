#!/bin/bash
# ╔════════════════════════════════════════╗
# ║      arch-maintenance.sh               ║
# ║      Perawatan Arch Linux Lengkap      ║
# ╚════════════════════════════════════════╝
#
# Menu terpusat (2 level: kategori -> aksi) untuk maintenance Arch Linux.
#
# PRINSIP KEAMANAN:
# - Semua aksi yang mengubah sistem SELALU tampilkan dulu apa yang akan
#   terjadi, baru minta konfirmasi eksplisit. Default jawaban = TIDAK (N).
# - Tidak ada penghapusan/merge file .pacnew otomatis — itu keputusan manual.
# - Aksi yang butuh tool eksternal (reflector, arch-audit, docker, dll)
#   akan dicek dulu ketersediaannya dan dilewati dengan pesan jelas kalau
#   tidak terpasang — TIDAK memaksa install apapun tanpa persetujuan.
# - Terminal non-interactive (mis. dipanggil dari cron) otomatis menolak
#   semua aksi yang butuh konfirmasi.

set -uo pipefail
# "set -e" sengaja tidak dipakai: fzf keluar exit code 130 saat Esc,
# itu bukan error, jangan sampai mematikan skrip secara paksa.

LOG_FILE="$HOME/.arch_maintenance_log"
MAX_LOG_LINES=300
PKGLIST_DIR="$HOME/.arch_pkg_backups"

# ─── Warna ───────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

# ─── Cek dependensi dasar ────────────────
check_deps() {
    if ! command -v fzf &>/dev/null; then
        echo -e "${RED}Error: 'fzf' tidak ditemukan.${RESET} Install: sudo pacman -S fzf"
        exit 1
    fi
    if ! command -v pacman &>/dev/null; then
        echo -e "${RED}Error: skrip ini khusus Arch Linux (pacman tidak ditemukan).${RESET}"
        exit 1
    fi
}

detect_aur_helper() {
    if command -v yay &>/dev/null; then
        echo "yay"
    elif command -v paru &>/dev/null; then
        echo "paru"
    else
        echo ""
    fi
}

# ─── Logging ─────────────────────────────
write_log() {
    local action="$1"
    local status="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$status] $action" >> "$LOG_FILE"
    local tmp
    tmp=$(mktemp) || return
    tail -n "$MAX_LOG_LINES" "$LOG_FILE" > "$tmp" && mv "$tmp" "$LOG_FILE"
}

# ─── Konfirmasi generik (default: TIDAK) ──
confirm() {
    local msg="$1"
    if [ ! -t 0 ]; then
        echo -e "${RED}✖ Terminal non-interactive, dibatalkan demi keamanan.${RESET}"
        return 1
    fi
    echo -e "${YELLOW}${msg}${RESET}"
    read -rp "   Lanjutkan? [y/N] " ans
    [[ "$ans" =~ ^[Yy]$ ]]
}

pause() {
    echo ""
    read -rp "Tekan Enter untuk kembali..."
}

need_tool() {
    # need_tool <perintah> <paket-untuk-install> -> return 1 kalau tidak ada
    local cmd="$1" pkg="$2"
    if ! command -v "$cmd" &>/dev/null; then
        echo -e "${YELLOW}'$cmd' tidak ditemukan.${RESET} Install: ${CYAN}sudo pacman -S $pkg${RESET}"
        return 1
    fi
    return 0
}

# ════════════════════════════════════════════
#  KATEGORI 1: UPDATE
# ════════════════════════════════════════════

action_update_system() {
    echo -e "${CYAN}${BOLD}== Update Sistem (pacman) ==${RESET}\n"
    echo "Menyinkronkan database paket..."
    sudo pacman -Sy >/dev/null 2>&1
    local updates
    updates=$(pacman -Qu 2>/dev/null)

    if [ -z "$updates" ]; then
        echo -e "${GREEN}Sistem sudah paling update.${RESET}"
        write_log "update_system" "OK(no-updates)"
        pause; return
    fi

    echo -e "${YELLOW}Paket yang akan diupdate ($(echo "$updates" | wc -l) paket):${RESET}"
    echo "$updates"
    echo ""

    if confirm "Lanjutkan update paket di atas?"; then
        if sudo pacman -Su --noconfirm; then
            echo -e "${GREEN}Update selesai.${RESET}"
            write_log "update_system" "OK"
            # Ingatkan reboot kalau kernel baru saja diupdate
            if echo "$updates" | grep -qE '^linux(-lts|-zen|-hardened)?\s'; then
                echo -e "${YELLOW}⚠ Kernel baru saja diupdate — disarankan reboot.${RESET}"
            fi
        else
            echo -e "${RED}Update gagal / dibatalkan pacman.${RESET}"
            write_log "update_system" "ERR"
        fi
    else
        echo -e "${YELLOW}Dibatalkan.${RESET}"
        write_log "update_system" "CANCELLED"
    fi
    pause
}

action_update_aur() {
    echo -e "${CYAN}${BOLD}== Update Paket AUR ==${RESET}\n"
    local helper
    helper=$(detect_aur_helper)
    if [ -z "$helper" ]; then
        echo -e "${YELLOW}Tidak ada AUR helper (yay/paru) terpasang. Lewati.${RESET}"
        pause; return
    fi

    echo "Menggunakan: $helper"
    local updates
    updates=$("$helper" -Qua 2>/dev/null)

    if [ -z "$updates" ]; then
        echo -e "${GREEN}Tidak ada update AUR.${RESET}"
        write_log "update_aur" "OK(no-updates)"
        pause; return
    fi

    echo -e "${YELLOW}Paket AUR yang akan diupdate:${RESET}"
    echo "$updates"
    echo ""

    if confirm "Lanjutkan update paket AUR di atas?"; then
        if "$helper" -Sua --noconfirm; then
            echo -e "${GREEN}Update AUR selesai.${RESET}"
            write_log "update_aur" "OK"
        else
            echo -e "${RED}Update AUR gagal / dibatalkan.${RESET}"
            write_log "update_aur" "ERR"
        fi
    else
        echo -e "${YELLOW}Dibatalkan.${RESET}"
        write_log "update_aur" "CANCELLED"
    fi
    pause
}

action_optimize_mirrors() {
    echo -e "${CYAN}${BOLD}== Optimasi Mirrorlist (reflector) ==${RESET}\n"
    if ! need_tool reflector reflector; then pause; return; fi

    echo "Ini akan mengganti /etc/pacman.d/mirrorlist dengan mirror tercepat"
    echo "berdasarkan negara Indonesia + sekitarnya (bisa disesuaikan)."
    echo ""

    if confirm "Backup mirrorlist lama & jalankan reflector sekarang?"; then
        sudo cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak."$(date +%Y%m%d)"
        if sudo reflector --country Indonesia,Singapore --age 12 --protocol https \
            --sort rate --save /etc/pacman.d/mirrorlist; then
            echo -e "${GREEN}Mirrorlist berhasil diperbarui. Backup lama disimpan (.bak.TANGGAL).${RESET}"
            write_log "optimize_mirrors" "OK"
        else
            echo -e "${RED}Gagal menjalankan reflector.${RESET}"
            write_log "optimize_mirrors" "ERR"
        fi
    else
        echo -e "${YELLOW}Dibatalkan.${RESET}"
        write_log "optimize_mirrors" "CANCELLED"
    fi
    pause
}

action_kernel_check() {
    echo -e "${CYAN}${BOLD}== Cek Kernel Aktif vs Kernel Terpasang ==${RESET}\n"
    local running installed
    running=$(uname -r)
    echo -e "${CYAN}Kernel yang sedang berjalan:${RESET} $running"
    echo ""
    echo -e "${CYAN}Kernel terpasang di sistem:${RESET}"
    pacman -Qs "^linux$\|^linux-lts$\|^linux-zen$\|^linux-hardened$" 2>/dev/null | grep "^local" || echo "  (tidak terdeteksi lewat pola umum)"
    echo ""
    if [ -d "/usr/lib/modules/$running" ]; then
        echo -e "${GREEN}Modul kernel untuk versi yang berjalan masih tersedia.${RESET}"
    else
        echo -e "${YELLOW}⚠ Modul untuk kernel yang sedang berjalan ($running) tidak ditemukan —${RESET}"
        echo -e "${YELLOW}  kemungkinan kernel sudah diupdate tapi belum reboot. Disarankan reboot.${RESET}"
    fi
    write_log "kernel_check" "OK"
    pause
}

# ════════════════════════════════════════════
#  KATEGORI 2: CLEANUP
# ════════════════════════════════════════════

action_remove_orphans() {
    echo -e "${CYAN}${BOLD}== Hapus Paket Orphan ==${RESET}\n"
    local orphans
    orphans=$(pacman -Qtdq 2>/dev/null)

    if [ -z "$orphans" ]; then
        echo -e "${GREEN}Tidak ada paket orphan. Sistem bersih.${RESET}"
        write_log "remove_orphans" "OK(none)"
        pause; return
    fi

    echo -e "${YELLOW}Paket orphan yang terdeteksi:${RESET}"
    echo "$orphans"
    echo ""
    echo -e "${YELLOW}Paket yang terpasang sebagai dependency tapi sudah tak dipakai paket lain.${RESET}"

    if confirm "Hapus semua paket orphan di atas?"; then
        local -a orphan_arr
        mapfile -t orphan_arr <<< "$orphans"
        if sudo pacman -Rns --noconfirm "${orphan_arr[@]}"; then
            echo -e "${GREEN}Paket orphan berhasil dihapus.${RESET}"
            write_log "remove_orphans" "OK"
        else
            echo -e "${RED}Gagal menghapus sebagian/semua paket orphan.${RESET}"
            write_log "remove_orphans" "ERR"
        fi
    else
        echo -e "${YELLOW}Dibatalkan.${RESET}"
        write_log "remove_orphans" "CANCELLED"
    fi
    pause
}

action_clean_pacman_cache() {
    echo -e "${CYAN}${BOLD}== Bersihkan Cache Paket Pacman ==${RESET}\n"
    if ! need_tool paccache pacman-contrib; then pause; return; fi

    echo "Ukuran cache saat ini:"
    du -sh /var/cache/pacman/pkg/ 2>/dev/null
    echo ""
    echo -e "${YELLOW}Opsi:${RESET}"
    echo "  1) Aman: simpan 3 versi terakhir tiap paket (disarankan)"
    echo "  2) Agresif: hapus semua cache kecuali versi terpasang saat ini"
    echo ""
    read -rp "Pilih opsi [1/2] (kosongkan untuk batal): " opt

    case "$opt" in
        1)
            if confirm "Jalankan: sudo paccache -r (simpan 3 versi terakhir)?"; then
                sudo paccache -r
                echo -e "${GREEN}Selesai.${RESET}"; write_log "clean_pacman_cache" "OK(safe)"
            else
                write_log "clean_pacman_cache" "CANCELLED"
            fi ;;
        2)
            if confirm "PERINGATAN: hapus SEMUA cache versi lama. Yakin?"; then
                sudo paccache -rk1
                echo -e "${GREEN}Selesai.${RESET}"; write_log "clean_pacman_cache" "OK(aggressive)"
            else
                write_log "clean_pacman_cache" "CANCELLED"
            fi ;;
        *)
            echo -e "${YELLOW}Dibatalkan.${RESET}"; write_log "clean_pacman_cache" "CANCELLED" ;;
    esac
    pause
}

action_clean_aur_cache() {
    echo -e "${CYAN}${BOLD}== Bersihkan Cache Build AUR ==${RESET}\n"
    local helper
    helper=$(detect_aur_helper)
    if [ -z "$helper" ]; then
        echo -e "${YELLOW}Tidak ada AUR helper terpasang. Lewati.${RESET}"
        pause; return
    fi

    local cache_dir="$HOME/.cache/$helper"
    if [ ! -d "$cache_dir" ]; then
        echo -e "${GREEN}Tidak ada folder cache build ($cache_dir).${RESET}"
        pause; return
    fi

    echo "Ukuran cache build $helper:"
    du -sh "$cache_dir" 2>/dev/null

    if confirm "Bersihkan cache build $helper di $cache_dir?"; then
        "$helper" -Sc --noconfirm 2>/dev/null || rm -rf "${cache_dir:?}"/*
        echo -e "${GREEN}Selesai.${RESET}"
        write_log "clean_aur_cache" "OK"
    else
        echo -e "${YELLOW}Dibatalkan.${RESET}"
        write_log "clean_aur_cache" "CANCELLED"
    fi
    pause
}

action_clean_user_cache() {
    echo -e "${CYAN}${BOLD}== Bersihkan ~/.cache (User) ==${RESET}\n"
    echo "Isi ~/.cache terbesar (top 15):"
    du -sh "$HOME"/.cache/* 2>/dev/null | sort -rh | head -n 15
    echo ""
    echo -e "${YELLOW}Ini folder cache aplikasi (browser, thumbnail, dll) — aman dihapus,${RESET}"
    echo -e "${YELLOW}aplikasi akan membuatnya ulang otomatis saat dibutuhkan.${RESET}"

    if confirm "Hapus SEMUA isi ~/.cache?"; then
        find "$HOME/.cache" -mindepth 1 -delete 2>/dev/null
        echo -e "${GREEN}~/.cache dibersihkan.${RESET}"
        write_log "clean_user_cache" "OK"
    else
        echo -e "${YELLOW}Dibatalkan.${RESET}"
        write_log "clean_user_cache" "CANCELLED"
    fi
    pause
}

action_vacuum_journal() {
    echo -e "${CYAN}${BOLD}== Bersihkan Journal systemd ==${RESET}\n"
    echo "Ukuran journal saat ini:"
    journalctl --disk-usage 2>/dev/null
    echo ""
    if confirm "Pangkas journal, sisakan 2 minggu terakhir saja?"; then
        if sudo journalctl --vacuum-time=2weeks; then
            echo -e "${GREEN}Journal berhasil dipangkas.${RESET}"
            write_log "vacuum_journal" "OK"
        else
            echo -e "${RED}Gagal memangkas journal.${RESET}"
            write_log "vacuum_journal" "ERR"
        fi
    else
        echo -e "${YELLOW}Dibatalkan.${RESET}"
        write_log "vacuum_journal" "CANCELLED"
    fi
    pause
}

action_trim_ssd() {
    echo -e "${CYAN}${BOLD}== TRIM SSD (fstrim) ==${RESET}\n"
    if ! need_tool fstrim util-linux; then pause; return; fi

    echo "Filesystem yang mendukung TRIM akan di-trim (aman untuk SSD/NVMe)."
    if confirm "Jalankan fstrim di semua mount point yang didukung?"; then
        if sudo fstrim -av; then
            echo -e "${GREEN}TRIM selesai.${RESET}"
            write_log "trim_ssd" "OK"
        else
            echo -e "${RED}TRIM gagal (mungkin disk bukan SSD/tidak support).${RESET}"
            write_log "trim_ssd" "ERR"
        fi
    else
        echo -e "${YELLOW}Dibatalkan.${RESET}"
        write_log "trim_ssd" "CANCELLED"
    fi
    pause
}

action_clean_docker() {
    echo -e "${CYAN}${BOLD}== Bersihkan Docker (jika terpasang) ==${RESET}\n"
    if ! need_tool docker docker; then pause; return; fi

    echo "Resource Docker yang tidak terpakai (dangling image, stopped container, dll):"
    docker system df 2>/dev/null || echo -e "${YELLOW}Tidak bisa akses docker (mungkin perlu 'sudo' atau service belum jalan).${RESET}"
    echo ""

    if confirm "Jalankan 'docker system prune' (hapus container berhenti, network, image dangling)?"; then
        docker system prune -f
        echo -e "${GREEN}Selesai.${RESET}"
        write_log "clean_docker" "OK"
    else
        echo -e "${YELLOW}Dibatalkan.${RESET}"
        write_log "clean_docker" "CANCELLED"
    fi
    pause
}

action_clean_flatpak() {
    echo -e "${CYAN}${BOLD}== Bersihkan Flatpak (jika terpasang) ==${RESET}\n"
    if ! need_tool flatpak flatpak; then pause; return; fi

    echo "Runtime/extension Flatpak yang tidak terpakai:"
    flatpak uninstall --unused --noninteractive --assumeyes=false 2>&1 | head -n 20 || true
    echo ""

    if confirm "Hapus runtime Flatpak yang tidak terpakai?"; then
        flatpak uninstall --unused -y
        echo -e "${GREEN}Selesai.${RESET}"
        write_log "clean_flatpak" "OK"
    else
        echo -e "${YELLOW}Dibatalkan.${RESET}"
        write_log "clean_flatpak" "CANCELLED"
    fi
    pause
}

# ════════════════════════════════════════════
#  KATEGORI 3: HEALTH CHECK (read-only, aman)
# ════════════════════════════════════════════

action_check_failed_services() {
    echo -e "${CYAN}${BOLD}== Service systemd yang Gagal ==${RESET}\n"
    local failed
    failed=$(systemctl --failed --no-legend 2>/dev/null)
    if [ -z "$failed" ]; then
        echo -e "${GREEN}Tidak ada service yang gagal. Sistem sehat.${RESET}"
    else
        echo -e "${RED}Service bermasalah:${RESET}"
        systemctl --failed
    fi
    write_log "check_failed_services" "OK"
    pause
}

action_list_pacnew() {
    echo -e "${CYAN}${BOLD}== File .pacnew / .pacsave ==${RESET}\n"
    echo "File ini muncul saat update menemukan config yang sudah kamu ubah manual."
    echo "TIDAK di-merge otomatis di sini — perlu review manual."
    echo ""
    local found
    found=$(sudo find /etc -name "*.pacnew" -o -name "*.pacsave" 2>/dev/null)
    if [ -z "$found" ]; then
        echo -e "${GREEN}Tidak ada file .pacnew/.pacsave.${RESET}"
    else
        echo -e "${YELLOW}Ditemukan:${RESET}"
        echo "$found"
        echo ""
        if command -v pacdiff &>/dev/null; then
            echo -e "${CYAN}Jalankan 'sudo -E pacdiff' untuk review & merge satu per satu.${RESET}"
        else
            echo -e "${CYAN}Install 'pacman-contrib' untuk dapat tool 'pacdiff'.${RESET}"
        fi
    fi
    write_log "list_pacnew" "OK"
    pause
}

action_check_disk_usage() {
    echo -e "${CYAN}${BOLD}== Penggunaan Disk ==${RESET}\n"
    df -h --output=target,size,used,avail,pcent 2>/dev/null | grep -E '^/|Mounted'
    echo ""
    echo -e "${CYAN}Folder terbesar di \$HOME (top 10):${RESET}"
    du -sh "$HOME"/* 2>/dev/null | sort -rh | head -n 10
    write_log "check_disk_usage" "OK"
    pause
}

action_check_broken_symlinks() {
    echo -e "${CYAN}${BOLD}== Cek Symlink Rusak ==${RESET}\n"
    echo "Mencari di \$HOME dan /etc (bisa beberapa detik)..."
    local broken
    broken=$(find "$HOME" /etc -xtype l 2>/dev/null | head -n 50)
    if [ -z "$broken" ]; then
        echo -e "${GREEN}Tidak ada symlink rusak yang ditemukan.${RESET}"
    else
        echo -e "${YELLOW}Symlink rusak ditemukan (maks 50 ditampilkan):${RESET}"
        echo "$broken"
        echo -e "\n${CYAN}Skrip ini TIDAK menghapus otomatis — review manual dulu.${RESET}"
    fi
    write_log "check_broken_symlinks" "OK"
    pause
}

action_security_audit() {
    echo -e "${CYAN}${BOLD}== Audit Keamanan Paket (arch-audit) ==${RESET}\n"
    if ! need_tool arch-audit arch-audit; then pause; return; fi

    echo "Mengecek paket terpasang yang punya CVE diketahui..."
    arch-audit -u 2>/dev/null
    local result
    result=$(arch-audit 2>/dev/null)
    if [ -z "$result" ]; then
        echo -e "${GREEN}Tidak ada kerentanan yang diketahui saat ini.${RESET}"
    else
        echo "$result"
    fi
    write_log "security_audit" "OK"
    pause
}

action_check_pacman_db() {
    echo -e "${CYAN}${BOLD}== Cek Integritas Database Pacman ==${RESET}\n"
    echo "Mengecek dependency yang hilang/rusak..."
    sudo pacman -Dk 2>&1 | tail -n 40
    write_log "check_pacman_db" "OK"
    pause
}

action_check_sensors() {
    echo -e "${CYAN}${BOLD}== Suhu & Sensor ==${RESET}\n"
    if ! need_tool sensors lm_sensors; then
        echo -e "${CYAN}Setelah install, jalankan 'sudo sensors-detect' sekali untuk konfigurasi awal.${RESET}"
        pause; return
    fi
    sensors
    write_log "check_sensors" "OK"
    pause
}

action_check_boot_time() {
    echo -e "${CYAN}${BOLD}== Analisa Waktu Boot ==${RESET}\n"
    systemd-analyze 2>/dev/null
    echo ""
    echo -e "${CYAN}5 service paling lambat saat boot:${RESET}"
    systemd-analyze blame 2>/dev/null | head -n 5
    write_log "check_boot_time" "OK"
    pause
}

action_check_memory_swap() {
    echo -e "${CYAN}${BOLD}== Penggunaan Memory & Swap ==${RESET}\n"
    free -h
    echo ""
    echo -e "${CYAN}Proses dengan pemakaian RAM tertinggi (top 8):${RESET}"
    ps -eo pid,comm,%mem,%cpu --sort=-%mem | head -n 9
    write_log "check_memory_swap" "OK"
    pause
}

# ════════════════════════════════════════════
#  KATEGORI 4: BACKUP & INFO
# ════════════════════════════════════════════

action_backup_pkglist() {
    echo -e "${CYAN}${BOLD}== Backup Daftar Paket Terpasang ==${RESET}\n"
    mkdir -p "$PKGLIST_DIR"
    local ts explicit_file aur_file
    ts=$(date '+%Y%m%d-%H%M%S')
    explicit_file="$PKGLIST_DIR/explicit-$ts.txt"
    aur_file="$PKGLIST_DIR/foreign-$ts.txt"

    pacman -Qqe > "$explicit_file"
    pacman -Qqm > "$aur_file" 2>/dev/null || true

    echo -e "${GREEN}Backup disimpan:${RESET}"
    echo "  $explicit_file  ($(wc -l < "$explicit_file") paket resmi, explicit)"
    echo "  $aur_file  ($(wc -l < "$aur_file" 2>/dev/null || echo 0) paket AUR/foreign)"
    write_log "backup_pkglist" "OK"
    pause
}

action_restore_pkglist() {
    echo -e "${CYAN}${BOLD}== Restore / Install dari Backup Daftar Paket ==${RESET}\n"
    if [ ! -d "$PKGLIST_DIR" ] || [ -z "$(ls -A "$PKGLIST_DIR" 2>/dev/null)" ]; then
        echo -e "${YELLOW}Belum ada backup daftar paket. Jalankan 'Backup Daftar Paket' dulu.${RESET}"
        pause; return
    fi

    local file
    file=$(find "$PKGLIST_DIR" -name "*.txt" | sort -r | fzf \
        --prompt="Pilih file backup > " \
        --header="Enter: pilih | Esc: batal" \
        --height=40% --border --reverse \
        --preview 'cat {}' --preview-window=right:50%)

    if [ -z "$file" ]; then
        echo -e "${YELLOW}Dibatalkan.${RESET}"
        pause; return
    fi

    echo "Isi file: $file"
    echo "$(wc -l < "$file") paket akan diinstall (yang belum terpasang)."
    echo ""

    if confirm "Install semua paket dari daftar ini?"; then
        if sudo pacman -S --needed - < "$file"; then
            echo -e "${GREEN}Selesai.${RESET}"
            write_log "restore_pkglist" "OK"
        else
            echo -e "${RED}Sebagian paket gagal diinstall (mungkin sudah tidak ada di repo/AUR).${RESET}"
            write_log "restore_pkglist" "ERR"
        fi
    else
        echo -e "${YELLOW}Dibatalkan.${RESET}"
        write_log "restore_pkglist" "CANCELLED"
    fi
    pause
}

action_system_info() {
    echo -e "${CYAN}${BOLD}== Info Sistem Ringkas ==${RESET}\n"
    echo -e "${BLUE}Hostname   :${RESET} $(hostname)"
    echo -e "${BLUE}Kernel     :${RESET} $(uname -r)"
    echo -e "${BLUE}Uptime     :${RESET} $(uptime -p 2>/dev/null)"
    echo -e "${BLUE}Shell      :${RESET} $SHELL"
    if [ -f /etc/os-release ]; then
        echo -e "${BLUE}Distro     :${RESET} $(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')"
    fi
    echo -e "${BLUE}Paket total:${RESET} $(pacman -Q | wc -l)"
    echo -e "${BLUE}CPU        :${RESET} $(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | sed 's/^ *//')"
    echo -e "${BLUE}RAM total  :${RESET} $(free -h | awk '/^Mem:/ {print $2}')"
    write_log "system_info" "OK"
    pause
}

action_view_log() {
    echo -e "${CYAN}${BOLD}== Riwayat Maintenance ==${RESET}\n"
    if [ ! -f "$LOG_FILE" ]; then
        echo -e "${YELLOW}Belum ada riwayat.${RESET}"
    else
        tail -n 40 "$LOG_FILE" | while IFS= read -r line; do
            if [[ "$line" == *"[OK"* ]]; then
                echo -e "  ${GREEN}$line${RESET}"
            elif [[ "$line" == *"[CANCELLED]"* ]]; then
                echo -e "  ${YELLOW}$line${RESET}"
            else
                echo -e "  ${RED}$line${RESET}"
            fi
        done
    fi
    pause
}

# ════════════════════════════════════════════
#  MENU: dua level (kategori -> aksi)
# ════════════════════════════════════════════

menu_update() {
    while true; do
        clear
        choice=$(printf "%s\n" \
            "1) Update sistem (pacman)" \
            "2) Update paket AUR" \
            "3) Optimasi mirrorlist (reflector)" \
            "4) Cek kernel aktif vs terpasang" \
            "0) Kembali" \
            | fzf --prompt="Update > " --header="Esc: kembali" --height=50% --border --reverse)
        case "$choice" in
            "1) "*) action_update_system ;;
            "2) "*) action_update_aur ;;
            "3) "*) action_optimize_mirrors ;;
            "4) "*) action_kernel_check ;;
            "0) "*|"") return ;;
        esac
    done
}

menu_cleanup() {
    while true; do
        clear
        choice=$(printf "%s\n" \
            "1) Hapus paket orphan" \
            "2) Bersihkan cache pacman" \
            "3) Bersihkan cache build AUR" \
            "4) Bersihkan ~/.cache (user)" \
            "5) Bersihkan journal systemd" \
            "6) TRIM SSD (fstrim)" \
            "7) Bersihkan Docker" \
            "8) Bersihkan Flatpak" \
            "0) Kembali" \
            | fzf --prompt="Cleanup > " --header="Esc: kembali" --height=60% --border --reverse)
        case "$choice" in
            "1) "*) action_remove_orphans ;;
            "2) "*) action_clean_pacman_cache ;;
            "3) "*) action_clean_aur_cache ;;
            "4) "*) action_clean_user_cache ;;
            "5) "*) action_vacuum_journal ;;
            "6) "*) action_trim_ssd ;;
            "7) "*) action_clean_docker ;;
            "8) "*) action_clean_flatpak ;;
            "0) "*|"") return ;;
        esac
    done
}

menu_health() {
    while true; do
        clear
        choice=$(printf "%s\n" \
            "1) Cek service yang gagal" \
            "2) Cek file .pacnew/.pacsave" \
            "3) Cek penggunaan disk" \
            "4) Cek symlink rusak" \
            "5) Audit keamanan paket (arch-audit)" \
            "6) Cek integritas database pacman" \
            "7) Cek suhu & sensor" \
            "8) Analisa waktu boot" \
            "9) Cek memory & swap" \
            "0) Kembali" \
            | fzf --prompt="Health Check > " --header="Esc: kembali" --height=70% --border --reverse)
        case "$choice" in
            "1) "*) action_check_failed_services ;;
            "2) "*) action_list_pacnew ;;
            "3) "*) action_check_disk_usage ;;
            "4) "*) action_check_broken_symlinks ;;
            "5) "*) action_security_audit ;;
            "6) "*) action_check_pacman_db ;;
            "7) "*) action_check_sensors ;;
            "8) "*) action_check_boot_time ;;
            "9) "*) action_check_memory_swap ;;
            "0) "*|"") return ;;
        esac
    done
}

menu_backup_info() {
    while true; do
        clear
        choice=$(printf "%s\n" \
            "1) Backup daftar paket terpasang" \
            "2) Install dari backup daftar paket" \
            "3) Info sistem ringkas" \
            "4) Lihat riwayat maintenance" \
            "0) Kembali" \
            | fzf --prompt="Backup & Info > " --header="Esc: kembali" --height=50% --border --reverse)
        case "$choice" in
            "1) "*) action_backup_pkglist ;;
            "2) "*) action_restore_pkglist ;;
            "3) "*) action_system_info ;;
            "4) "*) action_view_log ;;
            "0) "*|"") return ;;
        esac
    done
}

# ════════════════════════════════════════════
#  MENU UTAMA
# ════════════════════════════════════════════

check_deps

# Shortcut CLI: `maintance.sh <kategori>` langsung buka satu submenu lalu keluar.
# Dipakai oleh script lain di folder ini (mis. bersih.sh) supaya tidak duplikasi logika.
case "${1:-}" in
    cleanup) menu_cleanup; exit 0 ;;
    update)  menu_update; exit 0 ;;
    health)  menu_health; exit 0 ;;
    backup)  menu_backup_info; exit 0 ;;
esac

while true; do
    clear
    category=$(printf "%s\n" \
        "1) Update (sistem, AUR, mirror, kernel)" \
        "2) Cleanup (cache, orphan, journal, docker, flatpak)" \
        "3) Health Check (service, disk, keamanan, sensor)" \
        "4) Backup & Info (daftar paket, info sistem, log)" \
        "0) Keluar" \
        | fzf \
        --prompt="Arch Maintenance > " \
        --header="Pilih kategori | Esc: keluar" \
        --height=40% \
        --border \
        --reverse)

    case "$category" in
        "1) "*) menu_update ;;
        "2) "*) menu_cleanup ;;
        "3) "*) menu_health ;;
        "4) "*) menu_backup_info ;;
        "0) "*|"") echo -e "${CYAN}Sampai jumpa.${RESET}"; exit 0 ;;
    esac
done