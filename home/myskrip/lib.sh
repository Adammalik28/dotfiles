#!/bin/bash
# ============================================================
#   lib.sh — helper bersama untuk script menu fzf di myskrip/
#
#   Diekstrak dari duplikasi identik di ceklog.sh, pacman_aur_helper.sh,
#   ssh.key.sh, dan ufws.sh. Source file ini, JANGAN dieksekusi langsung.
#
#   Pemakaian:
#     source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
# ============================================================

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

# ─── Pesan berformat ────────────────────────────────────────
info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

# ─── Tunggu input sebelum kembali ke menu ────────────────────
kembali_ke_menu() {
    echo ""
    echo -e "${DIM}──────────────────────────────────────────────${RESET}"
    echo -e "${YELLOW}Tekan ${BOLD}Enter${RESET}${YELLOW} untuk kembali ke menu...${RESET}"
    read -r
}

# ─── Cek apakah perintah tersedia ────────────────────────────
cek_cmd() { command -v "$1" &>/dev/null; }
