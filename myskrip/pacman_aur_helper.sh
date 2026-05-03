#!/bin/bash
# ============================================================
#   KING'S PACMAN & AUR WRAPPER - v1.0
#   Kelola paket Arch Linux dengan mudah via fzf interaktif
#   Fitur: Update, Install, Remove, Cari, Info, Orphan,
#          Cache clean, Deteksi otomatis yay/paru/pacman
# ============================================================

set -uo pipefail

# ─── Warna ──────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

VERSION="1.0"

# ─── Utilitas ───────────────────────────────────────────────
info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

header() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════╗${RESET}"
    echo -e "${BLUE}║${RESET}  ${BOLD}${GREEN}📦  KING'S PACMAN & AUR WRAPPER  v${VERSION}${RESET}   ${BLUE}║${RESET}"
    echo -e "${BLUE}╚══════════════════════════════════════════════╝${RESET}"
    echo ""
}

kembali_ke_menu() {
    echo ""
    echo -e "${DIM}──────────────────────────────────────────────${RESET}"
    echo -e "${YELLOW}Tekan ${BOLD}Enter${RESET}${YELLOW} untuk kembali ke menu...${RESET}"
    read -r
}

cek_cmd() { command -v "$1" &>/dev/null; }

# ─── Deteksi AUR Helper ──────────────────────────────────────
deteksi_helper() {
    if cek_cmd paru; then
        AUR_HELPER="paru"
        AUR_BADGE="${MAGENTA}[paru]${RESET}"
    elif cek_cmd yay; then
        AUR_HELPER="yay"
        AUR_BADGE="${CYAN}[yay]${RESET}"
    else
        AUR_HELPER="pacman"
        AUR_BADGE="${BLUE}[pacman only]${RESET}"
    fi
}

# Jalankan perintah paket (AUR atau pacman)
pkg() {
    if [[ "$AUR_HELPER" == "pacman" ]]; then
        sudo pacman "$@"
    else
        "$AUR_HELPER" "$@"
    fi
}

# ─── Menu: Update Sistem ─────────────────────────────────────
menu_update() {
    header
    echo -e "${BOLD}${GREEN}── Update Sistem ──${RESET}"
    echo ""

    local mode
    mode=$(printf "Full Update (pacman + AUR)\nPacman Only (repo resmi saja)\nCek Update Tersedia (tanpa install)\nUpdate Database Saja (-Sy)" \
        | fzf --prompt="Mode Update ❯ " --border=rounded --height=30% \
              --color="prompt:#82aaff,pointer:#c3e88d,border:#1a7a1a" \
              --reverse) || { warn "Dibatalkan."; return; }

    echo ""

    case "$mode" in
        "Full Update"*)
            info "Menjalankan full system update via ${BOLD}${AUR_HELPER}${RESET}..."
            echo ""
            pkg -Syu
            ;;
        "Pacman Only"*)
            info "Update via pacman saja..."
            echo ""
            sudo pacman -Syu
            ;;
        "Cek Update"*)
            info "Mengecek paket yang tersedia untuk update..."
            echo ""
            if [[ "$AUR_HELPER" != "pacman" ]]; then
                "$AUR_HELPER" -Qu 2>/dev/null | while IFS= read -r line; do
                    echo -e "  ${YELLOW}→${RESET} $line"
                done || warn "Semua paket sudah up-to-date."
            else
                sudo pacman -Qu 2>/dev/null | while IFS= read -r line; do
                    echo -e "  ${YELLOW}→${RESET} $line"
                done || warn "Semua paket sudah up-to-date."
            fi
            ;;
        "Update Database"*)
            info "Memperbarui database paket..."
            echo ""
            sudo pacman -Sy
            ;;
    esac

    echo ""
    success "Selesai."
}

# ─── Menu: Install Paket ─────────────────────────────────────
menu_install() {
    header
    echo -e "${BOLD}${GREEN}── Install Paket ──${RESET}"
    echo ""

    echo -e "${CYAN}Cari paket${RESET} ${DIM}(ketik nama atau keyword):${RESET} \c"
    read -r query

    if [[ -z "$query" ]]; then
        warn "Query kosong. Dibatalkan."
        return
    fi

    info "Mencari '${BOLD}${query}${RESET}'..."
    echo ""

    # Ambil hasil pencarian
    local hasil
    if [[ "$AUR_HELPER" == "pacman" ]]; then
        hasil=$(sudo pacman -Ss "$query" 2>/dev/null \
            | paste - - \
            | awk '{print $1, "-", $2, "|", substr($0, index($0,$3))}' \
            | head -50)
    elif [[ "$AUR_HELPER" == "paru" ]]; then
        hasil=$(paru -Ss "$query" 2>/dev/null \
            | paste - - \
            | awk '{print $1, "-", $2, "|", substr($0, index($0,$3))}' \
            | head -80)
    else
        hasil=$(yay -Ss "$query" 2>/dev/null \
            | paste - - \
            | awk '{print $1, "-", $2, "|", substr($0, index($0,$3))}' \
            | head -80)
    fi

    if [[ -z "$hasil" ]]; then
        warn "Tidak ada paket yang ditemukan untuk: '${query}'"
        return
    fi

    # Preview info paket saat di-hover
    local pilihan
    pilihan=$(echo "$hasil" | fzf \
        --prompt="📦 Pilih Paket ❯ " \
        --border=rounded \
        --height=80% \
        --margin=1%,2% \
        --color="prompt:#82aaff,pointer:#c3e88d,border:#1a7a1a,bg+:#0d1117" \
        --reverse \
        --multi \
        --preview='
            PKG=$(echo {} | awk "{print \$1}" | cut -d"/" -f2)
            if pacman -Si "$PKG" &>/dev/null; then
                pacman -Si "$PKG" 2>/dev/null
            else
                echo "Paket AUR: $PKG"
                echo "──────────────"
                pacman -Qi "$PKG" 2>/dev/null || echo "(Belum terinstal)"
            fi
        ' \
        --preview-window="right:45%:wrap" \
        --header="Tab=multi-select | Enter=install | Ctrl+C=batal") || { warn "Dibatalkan."; return; }

    if [[ -z "$pilihan" ]]; then
        warn "Tidak ada yang dipilih."
        return
    fi

    # Ekstrak nama paket (kolom pertama, buang repo/ prefix)
    local paket_list
    paket_list=$(echo "$pilihan" | awk '{print $1}' | sed 's|.*/||' | tr '\n' ' ')

    echo ""
    echo -e "${GREEN}Paket yang akan diinstall:${RESET}"
    echo "$pilihan" | awk '{print $1}' | while IFS= read -r p; do
        echo -e "  ${BOLD}→ ${p}${RESET}"
    done

    echo ""
    echo -e "${CYAN}Konfirmasi install? [Y/n]:${RESET} \c"
    read -r konfirmasi
    if [[ "${konfirmasi,,}" != "n" ]]; then
        # shellcheck disable=SC2086
        pkg -S $paket_list
        echo ""
        success "Instalasi selesai."
    else
        warn "Dibatalkan."
    fi
}

# ─── Menu: Remove Paket ──────────────────────────────────────
menu_remove() {
    header
    echo -e "${BOLD}${RED}── Hapus Paket ──${RESET}"
    echo ""

    local mode
    mode=$(printf "Hapus paket saja (-R)\nHapus + dependensi tak terpakai (-Rs)\nHapus + config + dependensi (-Rns)" \
        | fzf --prompt="Mode Hapus ❯ " --border=rounded --height=25% \
              --color="prompt:#ff757f,pointer:#ff0000,border:#7c0000" \
              --reverse) || { warn "Dibatalkan."; return; }

    local flag
    case "$mode" in
        *"-R)"*)   flag="-R"   ;;
        *"-Rs)"*)  flag="-Rs"  ;;
        *"-Rns)"*) flag="-Rns" ;;
    esac

    # Daftar paket terinstal
    local paket_list
    paket_list=$(pacman -Qq 2>/dev/null)

    if [[ -z "$paket_list" ]]; then
        warn "Tidak ada paket yang terinstal?"
        return
    fi

    local pilihan
    pilihan=$(echo "$paket_list" | fzf \
        --prompt="🗑️  Pilih Paket ❯ " \
        --border=rounded \
        --height=80% \
        --margin=1%,2% \
        --color="prompt:#ff757f,pointer:#ff0000,border:#7c0000,bg+:#2d0000" \
        --reverse \
        --multi \
        --preview='pacman -Qi {} 2>/dev/null || echo "Info tidak tersedia"' \
        --preview-window="right:45%:wrap" \
        --header="Tab=multi-select | Enter=hapus | Ctrl+C=batal") || { warn "Dibatalkan."; return; }

    if [[ -z "$pilihan" ]]; then
        warn "Tidak ada yang dipilih."
        return
    fi

    local paket_hapus
    paket_hapus=$(echo "$pilihan" | tr '\n' ' ')

    echo ""
    echo -e "${RED}Paket yang akan dihapus (${flag}):${RESET}"
    echo "$pilihan" | while IFS= read -r p; do
        echo -e "  ${BOLD}→ ${p}${RESET}"
    done

    echo ""
    echo -e "${RED}${BOLD}Konfirmasi hapus? [y/N]:${RESET} \c"
    read -r konfirmasi
    if [[ "${konfirmasi,,}" == "y" ]]; then
        # shellcheck disable=SC2086
        sudo pacman $flag $paket_hapus
        echo ""
        success "Penghapusan selesai."
    else
        warn "Dibatalkan."
    fi
}

# ─── Menu: Info Paket ────────────────────────────────────────
menu_info() {
    header
    echo -e "${BOLD}${CYAN}── Info Paket ──${RESET}"
    echo ""

    local mode
    mode=$(printf "Paket terinstal\nCari di repo/AUR" \
        | fzf --prompt="Sumber ❯ " --border=rounded --height=20% \
              --color="prompt:#82aaff,pointer:#ff757f,border:#3d59a1" \
              --reverse) || { warn "Dibatalkan."; return; }

    local pilihan
    if [[ "$mode" == "Paket terinstal" ]]; then
        pilihan=$(pacman -Qq 2>/dev/null | fzf \
            --prompt="📦 Pilih Paket ❯ " \
            --border=rounded --height=80% \
            --color="prompt:#82aaff,pointer:#ff757f,border:#3d59a1" \
            --preview='pacman -Qi {}' \
            --preview-window="right:50%:wrap" \
            --reverse) || { warn "Dibatalkan."; return; }

        echo ""
        echo -e "${BOLD}${CYAN}═══ Info: ${pilihan} ═══${RESET}"
        echo ""
        pacman -Qi "$pilihan" 2>/dev/null
        echo ""

        # Tampilkan file yang dimiliki paket
        echo -e "${BOLD}File yang diinstal:${RESET}"
        pacman -Ql "$pilihan" 2>/dev/null | head -20 | while IFS= read -r line; do
            echo -e "  ${DIM}${line}${RESET}"
        done
        local total
        total=$(pacman -Ql "$pilihan" 2>/dev/null | wc -l)
        echo -e "  ${DIM}... total ${total} file${RESET}"
    else
        echo -e "${CYAN}Nama paket:${RESET} \c"
        read -r nama
        [[ -z "$nama" ]] && { warn "Kosong."; return; }
        echo ""
        pkg -Si "$nama" 2>/dev/null || pkg -Qi "$nama" 2>/dev/null || error "Paket tidak ditemukan."
    fi
}

# ─── Menu: Orphan & Cleanup ──────────────────────────────────
menu_orphan() {
    header
    echo -e "${BOLD}${YELLOW}── Orphan & Cleanup ──${RESET}"
    echo ""

    local aksi
    aksi=$(printf "Lihat & Hapus Orphan Packages\nBersihkan Cache Pacman\nBersihkan Cache AUR\nHapus Cache Semua Kecuali 2 Versi\nLihat Paket Eksplisit (Manual Install)" \
        | fzf --prompt="Aksi ❯ " --border=rounded --height=35% \
              --color="prompt:#f7c948,pointer:#ff9e64,border:#7a6500" \
              --reverse) || { warn "Dibatalkan."; return; }

    echo ""

    case "$aksi" in
        "Lihat & Hapus Orphan"*)
            local orphans
            orphans=$(pacman -Qtdq 2>/dev/null)

            if [[ -z "$orphans" ]]; then
                success "Tidak ada orphan package! Sistem bersih."
                return
            fi

            echo -e "${YELLOW}Orphan packages ditemukan:${RESET}"
            echo ""
            echo "$orphans" | while IFS= read -r p; do
                echo -e "  ${YELLOW}→${RESET} $p $(pacman -Qi "$p" 2>/dev/null | grep 'Installed Size' | awk '{print $4, $5}')"
            done

            echo ""
            echo -e "${CYAN}Hapus semua orphan? [y/N]:${RESET} \c"
            read -r konfirmasi
            if [[ "${konfirmasi,,}" == "y" ]]; then
                # shellcheck disable=SC2046
                sudo pacman -Rns $(pacman -Qtdq)
                success "Orphan packages dihapus."
            else
                warn "Dibatalkan."
            fi
            ;;

        "Bersihkan Cache Pacman"*)
            info "Cache pacman saat ini:"
            du -sh /var/cache/pacman/pkg/ 2>/dev/null
            echo ""
            echo -e "${CYAN}Bersihkan cache? (simpan 1 versi per paket) [Y/n]:${RESET} \c"
            read -r konfirmasi
            [[ "${konfirmasi,,}" == "n" ]] && { warn "Dibatalkan."; return; }
            sudo pacman -Sc
            success "Cache pacman dibersihkan."
            ;;

        "Bersihkan Cache AUR"*)
            if [[ "$AUR_HELPER" == "pacman" ]]; then
                warn "Tidak ada AUR helper terdeteksi."
                return
            fi
            local cache_dir="${HOME}/.cache/${AUR_HELPER}"
            if [[ -d "$cache_dir" ]]; then
                info "Cache AUR: $(du -sh "$cache_dir" 2>/dev/null | cut -f1)"
                echo ""
                echo -e "${CYAN}Hapus cache AUR? [y/N]:${RESET} \c"
                read -r konfirmasi
                if [[ "${konfirmasi,,}" == "y" ]]; then
                    rm -rf "$cache_dir"
                    success "Cache AUR dihapus."
                fi
            else
                warn "Tidak ada cache AUR ditemukan."
            fi
            ;;

        "Hapus Cache Semua Kecuali 2"*)
            info "Menyimpan 2 versi terakhir per paket, menghapus sisanya..."
            sudo paccache -rk2
            success "Selesai."
            ;;

        "Lihat Paket Eksplisit"*)
            info "Paket yang diinstall secara eksplisit (bukan dependensi):"
            echo ""
            pacman -Qe 2>/dev/null | while IFS= read -r line; do
                echo -e "  ${GREEN}→${RESET} $line"
            done
            ;;
    esac
}

# ─── Menu: Downgrade Paket ───────────────────────────────────
menu_downgrade() {
    header
    echo -e "${BOLD}${YELLOW}── Downgrade Paket dari Cache ──${RESET}"
    echo ""

    local cache_dir="/var/cache/pacman/pkg"

    if [[ ! -d "$cache_dir" ]]; then
        error "Direktori cache tidak ditemukan."
        return
    fi

    local pilihan
    pilihan=$(ls "$cache_dir"/*.pkg.tar.zst 2>/dev/null | xargs -I{} basename {} | \
        fzf --prompt="📦 Pilih Versi ❯ " \
            --border=rounded --height=70% \
            --color="prompt:#f7c948,pointer:#ff9e64,border:#7a6500" \
            --reverse \
            --header="Pilih file paket dari cache untuk downgrade") || { warn "Dibatalkan."; return; }

    echo ""
    echo -e "${YELLOW}Akan menginstall:${RESET} ${BOLD}${pilihan}${RESET}"
    echo -e "${CYAN}Konfirmasi? [Y/n]:${RESET} \c"
    read -r konfirmasi
    if [[ "${konfirmasi,,}" != "n" ]]; then
        sudo pacman -U "${cache_dir}/${pilihan}"
        success "Downgrade selesai."
    else
        warn "Dibatalkan."
    fi
}

# ─── Menu: Cari File di Paket ────────────────────────────────
menu_owns() {
    header
    echo -e "${BOLD}${CYAN}── Cari Paket Pemilik File ──${RESET}"
    echo ""

    echo -e "${CYAN}Masukkan path file${RESET} ${DIM}(contoh: /usr/bin/nvim):${RESET} \c"
    read -r filepath

    if [[ -z "$filepath" ]]; then
        warn "Path kosong."
        return
    fi

    echo ""
    info "Mencari pemilik: ${BOLD}${filepath}${RESET}"
    echo ""
    pacman -Qo "$filepath" 2>/dev/null || error "File tidak dimiliki oleh paket manapun."
}

# ─── Menu: Statistik Sistem ──────────────────────────────────
menu_statistik() {
    header
    echo -e "${BOLD}${CYAN}── Statistik Paket ──${RESET}"
    echo ""

    local total total_eksplisit total_dep total_aur total_cache cache_size

    total=$(pacman -Q 2>/dev/null | wc -l)
    total_eksplisit=$(pacman -Qe 2>/dev/null | wc -l)
    total_dep=$(pacman -Qd 2>/dev/null | wc -l)
    total_aur=$(pacman -Qm 2>/dev/null | wc -l)
    total_cache=$(ls /var/cache/pacman/pkg/*.pkg.tar.* 2>/dev/null | wc -l)
    cache_size=$(du -sh /var/cache/pacman/pkg/ 2>/dev/null | cut -f1)

    echo -e "  ${BOLD}Total paket terinstal:${RESET}   ${GREEN}${total}${RESET}"
    echo -e "  ${BOLD}Eksplisit (manual):${RESET}      ${CYAN}${total_eksplisit}${RESET}"
    echo -e "  ${BOLD}Dependensi:${RESET}              ${DIM}${total_dep}${RESET}"
    echo -e "  ${BOLD}Dari AUR:${RESET}                ${MAGENTA}${total_aur}${RESET}"
    echo ""
    echo -e "  ${BOLD}Cache (jumlah file):${RESET}     ${YELLOW}${total_cache}${RESET}"
    echo -e "  ${BOLD}Cache (ukuran):${RESET}          ${YELLOW}${cache_size}${RESET}"
    echo ""

    # 10 paket terbesar
    echo -e "${BOLD}10 Paket Terbesar:${RESET}"
    echo ""
    pacman -Qi $(pacman -Qq) 2>/dev/null \
        | awk '/^Name/{name=$3} /^Installed Size/{size=$4" "$5; print size, name}' \
        | sort -rh \
        | head -10 \
        | while read -r size name; do
            echo -e "  ${YELLOW}${size}${RESET}\t${name}"
        done
}

# ─── Main Loop ───────────────────────────────────────────────
main() {
    if ! cek_cmd fzf; then
        echo -e "${RED}fzf tidak ditemukan.${RESET} Install: ${BOLD}sudo pacman -S fzf${RESET}"
        exit 1
    fi

    if ! cek_cmd pacman; then
        error "pacman tidak ditemukan. Skrip ini hanya untuk Arch Linux."
        exit 1
    fi

    deteksi_helper

    local MENU
    MENU=$(cat <<'EOF'
1.  🔄  Update Sistem
2.  📥  Install Paket
3.  🗑️   Hapus Paket
4.  🔍  Info Paket
5.  🧹  Orphan & Cleanup
6.  ⬇️   Downgrade dari Cache
7.  🔎  Cari Pemilik File
8.  📊  Statistik Paket
──────────────────────────
0.  ❌  Keluar
EOF
)

    while true; do
        header

        echo -e "  ${DIM}AUR Helper: $(echo -e $AUR_BADGE)${RESET}"
        local total
        total=$(pacman -Q 2>/dev/null | wc -l)
        echo -e "  ${DIM}Paket terinstal: ${CYAN}${total}${RESET}"
        echo ""

        local pilihan
        pilihan=$(echo "$MENU" | fzf \
            --prompt="  Package Manager ❯ " \
            --border=rounded \
            --margin=3%,5% \
            --color="bg+:#0d1117,fg+:#c9d1d9,pointer:#c3e88d,prompt:#58a6ff,border:#1f6feb,header:#79c0ff" \
            --reverse \
            --height=75% \
            --no-sort \
            --header="📦 King's Pacman Wrapper | AUR: ${AUR_HELPER} | 0=Keluar" \
            --bind='esc:abort') || true

        clear

        case "$pilihan" in
            "1.  🔄  Update Sistem")          menu_update      ;;
            "2.  📥  Install Paket")          menu_install     ;;
            "3.  🗑️   Hapus Paket")            menu_remove      ;;
            "4.  🔍  Info Paket")             menu_info        ;;
            "5.  🧹  Orphan & Cleanup")       menu_orphan      ;;
            "6.  ⬇️   Downgrade dari Cache")   menu_downgrade   ;;
            "7.  🔎  Cari Pemilik File")       menu_owns        ;;
            "8.  📊  Statistik Paket")        menu_statistik   ;;
            "0.  ❌  Keluar"|"──────────────────────────"|"")
                echo -e "${GREEN}Sampai jumpa! 👋${RESET}"
                exit 0
                ;;
        esac

        kembali_ke_menu
    done
}

trap 'echo -e "\n${YELLOW}[INTERRUPT]${RESET} Kembali ke menu..."; sleep 0.4' INT

main
