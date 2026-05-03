#!/bin/bash
# ============================================================
#   ADVANCED LOG MONITOR - v2.0
#   Dibuat untuk Arch Linux + Hyprland
#   Fitur: Loop menu, validasi file, deteksi layanan otomatis,
#          export log, filter keyword, dan penanganan error
# ============================================================

set -euo pipefail

# ─── Warna & Gaya ───────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ─── Konfigurasi ────────────────────────────────────────────
LOG_DIR="${HOME}/.cache/log-monitor"
EXPORT_DIR="${HOME}/log-exports"
VERSION="2.0"

# ─── Fungsi Utilitas ─────────────────────────────────────────

# Tampilkan header
header() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════╗${RESET}"
    echo -e "${BLUE}║${RESET}  ${BOLD}${GREEN} ADVANCED LOG MONITOR  v${VERSION}${RESET}  ${BLUE}║${RESET}"
    echo -e "${BLUE}╚══════════════════════════════════════════════╝${RESET}"
    echo ""
}

# Pesan info
info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

# Tunggu input sebelum kembali ke menu
kembali_ke_menu() {
    echo ""
    echo -e "${DIM}──────────────────────────────────────────────${RESET}"
    echo -e "${YELLOW}Tekan ${BOLD}Enter${RESET}${YELLOW} untuk kembali ke menu...${RESET}"
    read -r
}

# Cek apakah file/path ada sebelum ditampilkan
cek_file() {
    local path="$1"
    if [[ ! -f "$path" ]]; then
        error "File tidak ditemukan: ${BOLD}${path}${RESET}"
        warn "Pastikan layanan sudah terinstal dan pernah berjalan."
        return 1
    fi
    return 0
}

# Cek apakah perintah tersedia
cek_cmd() {
    command -v "$1" &>/dev/null
}

# Ekspor log ke file
ekspor_log() {
    local nama_log="$1"
    local konten="$2"
    mkdir -p "${EXPORT_DIR}"
    local filename="${EXPORT_DIR}/${nama_log}_$(date +%Y%m%d_%H%M%S).log"
    echo "$konten" > "$filename"
    success "Log diekspor ke: ${BOLD}${filename}${RESET}"
}

# Tanya user apakah ingin ekspor
tanya_ekspor() {
    local nama="$1"
    echo ""
    echo -e "${CYAN}Ekspor log ini ke file? [y/N]:${RESET} \c"
    read -r jawab
    if [[ "${jawab,,}" == "y" ]]; then
        return 0
    fi
    return 1
}

# Filter log dengan fzf (mode non-live)
filter_dengan_fzf() {
    local judul="$1"
    shift
    local output
    output=$("$@" 2>/dev/null) || { error "Gagal menjalankan perintah."; return 1; }

    if [[ -z "$output" ]]; then
        warn "Tidak ada output yang ditemukan."
        return 0
    fi

    local baris_dipilih
    baris_dipilih=$(echo "$output" | fzf \
        --prompt="🔍 Filter ${judul} ❯ " \
        --border=rounded \
        --margin=2%,3% \
        --color="bg+:#1e2030,fg+:#c8d3f5,pointer:#ff757f,marker:#c3e88d,prompt:#82aaff,border:#3d59a1" \
        --preview='echo {}' \
        --preview-window='down:3:wrap' \
        --multi \
        --height=80% \
        --reverse \
        --header="Tab=multi-select | Enter=pilih | Ctrl+C=batal") || true

    if [[ -n "$baris_dipilih" ]]; then
        echo ""
        echo -e "${BOLD}${GREEN}═══ Hasil Filter ═══${RESET}"
        echo "$baris_dipilih"

        if tanya_ekspor "${judul}"; then
            ekspor_log "${judul// /_}" "$baris_dipilih"
        fi
    fi
}

# ─── Deteksi Layanan Otomatis ────────────────────────────────
deteksi_layanan() {
    XAMPP_TERSEDIA=false
    DOCKER_TERSEDIA=false
    HYPRLAND_TERSEDIA=false
    NGINX_TERSEDIA=false
    POSTGRES_TERSEDIA=false

    [[ -d "/opt/lampp" ]] && XAMPP_TERSEDIA=true
    cek_cmd docker && DOCKER_TERSEDIA=true
    [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && HYPRLAND_TERSEDIA=true
    cek_cmd nginx && NGINX_TERSEDIA=true
    cek_cmd psql && POSTGRES_TERSEDIA=true
}

# ─── Bangun Menu Secara Dinamis ──────────────────────────────
bangun_menu() {
    local menu=""
    menu+="1.  System Journal (Live)\n"
    menu+="2.  Boot Errors - Prioritas Tinggi\n"
    menu+="3.  Kernel & Hardware (dmesg)\n"
    menu+="4.  Pacman Update History\n"
    menu+="5.  Security & Auth Logs\n"
    menu+="6.  Journal - Filter Keyword\n"

    if $HYPRLAND_TERSEDIA; then
        menu+="7.  Hyprland Session Log\n"
    fi

    if $XAMPP_TERSEDIA; then
        menu+="8.  XAMPP - Apache Error Log\n"
        menu+="9.  XAMPP - MySQL Error Log\n"
    fi

    if $DOCKER_TERSEDIA; then
        menu+="10. Docker Containers (Live)\n"
    fi

    if $NGINX_TERSEDIA; then
        menu+="11. Nginx - Error Log\n"
    fi

    if $POSTGRES_TERSEDIA; then
        menu+="12. PostgreSQL - Log\n"
    fi

    menu+="──────────────────────────\n"
    menu+="0.  ❌ Keluar"

    echo -e "$menu"
}

# ─── Handler Setiap Menu ─────────────────────────────────────

menu_journal_live() {
    info "Memantau System Journal... ${DIM}(Ctrl+C untuk berhenti)${RESET}"
    echo ""
    sudo journalctl -f --output=short-precise 2>/dev/null || true
}

menu_boot_errors() {
    info "Menampilkan error boot saat ini..."
    echo ""
    filter_dengan_fzf "Boot_Errors" sudo journalctl -p 3 -xb --no-pager
}

menu_dmesg() {
    info "Memantau Kernel & Hardware... ${DIM}(Ctrl+C untuk berhenti)${RESET}"
    echo ""
    sudo dmesg -wH 2>/dev/null || true
}

menu_pacman() {
    info "Menampilkan log Pacman..."
    echo ""
    if cek_file "/var/log/pacman.log"; then
        filter_dengan_fzf "Pacman_History" tail -n 200 /var/log/pacman.log
    fi
}

menu_security() {
    info "Memantau log keamanan (sudo, sshd, su)... ${DIM}(Ctrl+C untuk berhenti)${RESET}"
    echo ""
    sudo journalctl -f -t sudo -t sshd -t su --output=short-precise 2>/dev/null || true
}

menu_filter_keyword() {
    echo -e "${CYAN}Masukkan keyword untuk dicari di journal:${RESET} \c"
    read -r keyword
    if [[ -z "$keyword" ]]; then
        warn "Keyword kosong, dibatalkan."
        return
    fi
    info "Mencari '${keyword}' di journal..."
    echo ""
    filter_dengan_fzf "Journal_${keyword}" sudo journalctl --no-pager -n 500 --grep="$keyword"
}

menu_hyprland() {
    local logfile="${XDG_RUNTIME_DIR}/hypr/${HYPRLAND_INSTANCE_SIGNATURE}/hyprland.log"
    if cek_file "$logfile"; then
        info "Memantau log Hyprland... ${DIM}(Ctrl+C untuk berhenti)${RESET}"
        echo ""
        tail -f "$logfile" 2>/dev/null || true
    fi
}

menu_xampp_apache() {
    local logfile="/opt/lampp/logs/error_log"
    if cek_file "$logfile"; then
        info "Memantau Apache Error Log... ${DIM}(Ctrl+C untuk berhenti)${RESET}"
        echo ""
        sudo tail -f "$logfile" 2>/dev/null || true
    fi
}

menu_xampp_mysql() {
    local logfile="/opt/lampp/var/mysql/$(hostname).err"
    if cek_file "$logfile"; then
        info "Memantau MySQL Error Log... ${DIM}(Ctrl+C untuk berhenti)${RESET}"
        echo ""
        sudo tail -f "$logfile" 2>/dev/null || true
    fi
}

menu_docker() {
    if ! sudo docker info &>/dev/null; then
        error "Docker daemon tidak berjalan atau tidak punya akses."
        return
    fi

    local containers
    containers=$(sudo docker ps --format "{{.Names}}\t{{.Status}}\t{{.Image}}" 2>/dev/null)

    if [[ -z "$containers" ]]; then
        warn "Tidak ada container yang sedang berjalan."
        return
    fi

    local container
    container=$(echo "$containers" | fzf \
        --prompt="🐳 Pilih Container ❯ " \
        --border=rounded \
        --height=50% \
        --margin=2%,3% \
        --color="prompt:#82aaff,pointer:#ff757f,border:#3d59a1" \
        --reverse \
        --header="Nama | Status | Image" \
        | awk '{print $1}') || true

    if [[ -n "$container" ]]; then
        info "Memantau log container: ${BOLD}${container}${RESET}... ${DIM}(Ctrl+C untuk berhenti)${RESET}"
        echo ""
        sudo docker logs -f --timestamps "$container" 2>/dev/null || true
    else
        warn "Tidak ada container yang dipilih."
    fi
}

menu_nginx() {
    local logfile="/var/log/nginx/error.log"
    if cek_file "$logfile"; then
        info "Memantau Nginx Error Log... ${DIM}(Ctrl+C untuk berhenti)${RESET}"
        echo ""
        sudo tail -f "$logfile" 2>/dev/null || true
    fi
}

menu_postgres() {
    local logdir="/var/log/postgresql"
    if [[ ! -d "$logdir" ]]; then
        error "Direktori log PostgreSQL tidak ditemukan: ${logdir}"
        warn "Sesuaikan path di skrip jika lokasinya berbeda."
        return
    fi

    local logfile
    logfile=$(find "$logdir" -name "*.log" -type f 2>/dev/null | sort | tail -n 1)

    if [[ -z "$logfile" ]]; then
        warn "Tidak ada file log PostgreSQL yang ditemukan."
        return
    fi

    info "Memantau PostgreSQL Log: ${BOLD}${logfile}${RESET}... ${DIM}(Ctrl+C untuk berhenti)${RESET}"
    echo ""
    sudo tail -f "$logfile" 2>/dev/null || true
}

# ─── Main Loop ───────────────────────────────────────────────
main() {
    # Pastikan fzf tersedia
    if ! cek_cmd fzf; then
        echo -e "${RED}[ERROR]${RESET} fzf tidak ditemukan."
        echo -e "Install dengan: ${BOLD}sudo pacman -S fzf${RESET}"
        exit 1
    fi

    # Buat direktori cache jika belum ada
    mkdir -p "${LOG_DIR}"

    # Deteksi layanan yang tersedia
    deteksi_layanan

    # Loop utama
    while true; do
        header

        # Info layanan yang terdeteksi
        echo -e "${DIM}  Layanan terdeteksi:${RESET}"
        $HYPRLAND_TERSEDIA && echo -e "  ${GREEN}✔${RESET} Hyprland" || true
        $XAMPP_TERSEDIA    && echo -e "  ${GREEN}✔${RESET} XAMPP"    || true
        $DOCKER_TERSEDIA   && echo -e "  ${GREEN}✔${RESET} Docker"   || true
        $NGINX_TERSEDIA    && echo -e "  ${GREEN}✔${RESET} Nginx"    || true
        $POSTGRES_TERSEDIA && echo -e "  ${GREEN}✔${RESET} PostgreSQL" || true
        echo ""

        local pilihan
        pilihan=$(bangun_menu | fzf \
            --prompt="  Pilih Log ❯ " \
            --border=rounded \
            --margin=3%,5% \
            --color="bg+:#1e2030,fg+:#c8d3f5,pointer:#ff757f,marker:#c3e88d,prompt:#82aaff,border:#3d59a1,header:#7aa2f7" \
            --reverse \
            --height=75% \
            --header="Log Monitor | q/0=Keluar | Enter=Pilih" \
            --no-sort \
            --bind='esc:abort') || true

        clear

        case "$pilihan" in
            "1.  System Journal (Live)")         menu_journal_live   ;;
            "2.  Boot Errors - Prioritas Tinggi") menu_boot_errors   ;;
            "3.  Kernel & Hardware (dmesg)")      menu_dmesg         ;;
            "4.  Pacman Update History")          menu_pacman        ;;
            "5.  Security & Auth Logs")           menu_security      ;;
            "6.  Journal - Filter Keyword")       menu_filter_keyword ;;
            "7.  Hyprland Session Log")           menu_hyprland      ;;
            "8.  XAMPP - Apache Error Log")       menu_xampp_apache  ;;
            "9.  XAMPP - MySQL Error Log")        menu_xampp_mysql   ;;
            "10. Docker Containers (Live)")       menu_docker        ;;
            "11. Nginx - Error Log")              menu_nginx         ;;
            "12. PostgreSQL - Log")               menu_postgres      ;;
            "0.  ❌ Keluar"|"──────────────────────────")
                echo -e "${GREEN}Sampai jumpa! 👋${RESET}"
                exit 0
                ;;
            "")
                # Tidak ada pilihan (Ctrl+C / Esc)
                echo -e "${GREEN}Sampai jumpa! 👋${RESET}"
                exit 0
                ;;
            *)
                warn "Pilihan tidak dikenali."
                ;;
        esac

        kembali_ke_menu
    done
}

# ─── Tangkap Sinyal Interrupt ────────────────────────────────
trap 'echo -e "\n${YELLOW}[INTERRUPT]${RESET} Kembali ke menu..."; sleep 0.5' INT

# ─── Jalankan ───────────────────────────────────────────────
main
