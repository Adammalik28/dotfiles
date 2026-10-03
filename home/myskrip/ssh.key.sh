#!/bin/bash
# ============================================================
#   KING'S SSH KEY MANAGER - v1.0
#   Kelola SSH key dengan mudah via menu interaktif fzf
#   Fitur: Generate, List, Add to agent, Copy pubkey,
#          Delete, Backup, dan Info detail key
# ============================================================

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

# ─── Konfigurasi ────────────────────────────────────────────
SSH_DIR="${HOME}/.ssh"
BACKUP_DIR="${HOME}/.ssh/backups"
VERSION="1.0"

header() {
    clear
    echo -e "${MAGENTA}╔══════════════════════════════════════════════╗${RESET}"
    echo -e "${MAGENTA}║${RESET}  ${BOLD}${CYAN}🔑  KING'S SSH KEY MANAGER  v${VERSION}${RESET}          ${MAGENTA}║${RESET}"
    echo -e "${MAGENTA}╚══════════════════════════════════════════════╝${RESET}"
    echo ""
}

# Cek clipboard tool yang tersedia
clipboard_copy() {
    local teks="$1"
    if cek_cmd wl-copy; then
        echo -n "$teks" | wl-copy
        success "Disalin ke clipboard via ${BOLD}wl-copy${RESET}"
    elif cek_cmd xclip; then
        echo -n "$teks" | xclip -selection clipboard
        success "Disalin ke clipboard via ${BOLD}xclip${RESET}"
    elif cek_cmd xsel; then
        echo -n "$teks" | xsel --clipboard --input
        success "Disalin ke clipboard via ${BOLD}xsel${RESET}"
    else
        warn "Tidak ada clipboard tool (wl-copy/xclip/xsel). Menampilkan manual:"
        echo ""
        echo -e "${BOLD}${GREEN}${teks}${RESET}"
    fi
}

# ─── Ambil daftar private key ────────────────────────────────
daftar_private_key() {
    find "${SSH_DIR}" -maxdepth 1 -type f ! -name "*.pub" ! -name "known_hosts*" \
        ! -name "authorized_keys" ! -name "config" ! -name "backups" 2>/dev/null \
        | while read -r f; do
            # Verifikasi ini benar-benar private key
            if head -1 "$f" 2>/dev/null | grep -q "PRIVATE KEY"; then
                echo "$f"
            fi
        done
}

# ─── Menu: Generate Key Baru ─────────────────────────────────
menu_generate() {
    header
    echo -e "${BOLD}${CYAN}── Generate SSH Key Baru ──${RESET}"
    echo ""

    # Pilih tipe key
    local tipe
    tipe=$(echo -e "ed25519 (Rekomendasi - Modern & Aman)\nrsa-4096 (Kompatibilitas Luas)\necdsa (Elliptic Curve)" \
        | fzf --prompt="Tipe Key ❯ " --border=rounded --height=30% \
              --color="prompt:#82aaff,pointer:#ff757f,border:#7c3aed" \
              --reverse) || { warn "Dibatalkan."; return; }

    local key_type
    case "$tipe" in
        ed25519*) key_type="ed25519" ;;
        rsa*)     key_type="rsa"; extra_args="-b 4096" ;;
        ecdsa*)   key_type="ecdsa"; extra_args="-b 521" ;;
    esac

    echo -e "${CYAN}Nama file key${RESET} ${DIM}(default: id_${key_type})${RESET}: \c"
    read -r nama_file
    nama_file="${nama_file:-id_${key_type}}"
    local key_path="${SSH_DIR}/${nama_file}"

    if [[ -f "$key_path" ]]; then
        warn "File ${BOLD}${key_path}${RESET} sudah ada!"
        echo -e "${RED}Timpa? Ini TIDAK BISA dibatalkan! [y/N]:${RESET} \c"
        read -r konfirmasi
        [[ "${konfirmasi,,}" != "y" ]] && { warn "Dibatalkan."; return; }
    fi

    echo -e "${CYAN}Komentar/label key${RESET} ${DIM}(contoh: user@hostname atau nama-project)${RESET}: \c"
    read -r komentar
    komentar="${komentar:-${USER}@$(hostname)}"

    echo ""
    info "Membuat key ${BOLD}${key_type}${RESET}..."
    echo ""

    if [[ "$key_type" == "ed25519" ]]; then
        ssh-keygen -t ed25519 -C "$komentar" -f "$key_path"
    elif [[ "$key_type" == "rsa" ]]; then
        ssh-keygen -t rsa -b 4096 -C "$komentar" -f "$key_path"
    else
        ssh-keygen -t ecdsa -b 521 -C "$komentar" -f "$key_path"
    fi

    if [[ $? -eq 0 ]]; then
        echo ""
        success "Key berhasil dibuat!"
        echo ""
        echo -e "${BOLD}Private key:${RESET} ${key_path}"
        echo -e "${BOLD}Public key: ${RESET} ${key_path}.pub"
        echo ""
        echo -e "${DIM}Public key kamu:${RESET}"
        echo -e "${GREEN}$(cat "${key_path}.pub")${RESET}"
        echo ""

        echo -e "${CYAN}Tambah ke ssh-agent sekarang? [Y/n]:${RESET} \c"
        read -r tambah
        if [[ "${tambah,,}" != "n" ]]; then
            _tambah_ke_agent "$key_path"
        fi
    else
        error "Gagal membuat key."
    fi
}

# ─── Menu: List & Info Key ───────────────────────────────────
menu_list() {
    header
    echo -e "${BOLD}${CYAN}── Daftar SSH Key ──${RESET}"
    echo ""

    local keys
    keys=$(daftar_private_key)

    if [[ -z "$keys" ]]; then
        warn "Tidak ada SSH key di ${SSH_DIR}"
        return
    fi

    # Bangun tampilan dengan info fingerprint
    local display_list=""
    while IFS= read -r key; do
        local nama
        nama=$(basename "$key")
        local fingerprint
        fingerprint=$(ssh-keygen -lf "$key" 2>/dev/null | awk '{print $2, $4}' || echo "N/A")
        local pubkey_ada=""
        [[ -f "${key}.pub" ]] && pubkey_ada="${GREEN}✔ pubkey${RESET}" || pubkey_ada="${RED}✘ no pubkey${RESET}"
        display_list+="${nama}  │  ${fingerprint}  │  ${pubkey_ada}\n"
    done <<< "$keys"

    local pilihan
    pilihan=$(echo -e "$display_list" | fzf \
        --prompt="🔑 Pilih Key ❯ " \
        --border=rounded \
        --height=60% \
        --margin=2%,3% \
        --color="prompt:#82aaff,pointer:#ff757f,border:#7c3aed,bg+:#1e1e2e" \
        --reverse \
        --header="Enter=detail | Ctrl+C=batal" \
        --ansi) || { warn "Dibatalkan."; return; }

    local nama_key
    nama_key=$(echo "$pilihan" | awk '{print $1}')
    local key_path="${SSH_DIR}/${nama_key}"

    if [[ ! -f "$key_path" ]]; then
        error "Key tidak ditemukan."
        return
    fi

    echo ""
    echo -e "${BOLD}${MAGENTA}═══ Detail Key: ${nama_key} ═══${RESET}"
    echo ""
    echo -e "${BOLD}Path:${RESET}        ${key_path}"
    echo -e "${BOLD}Tipe & Size:${RESET} $(ssh-keygen -lf "$key_path" 2>/dev/null | awk '{print $3, $4}' || echo 'N/A')"
    echo -e "${BOLD}Fingerprint:${RESET} $(ssh-keygen -lf "$key_path" 2>/dev/null | awk '{print $2}' || echo 'N/A')"
    echo -e "${BOLD}Dibuat:${RESET}      $(stat -c '%y' "$key_path" 2>/dev/null | cut -d'.' -f1 || echo 'N/A')"

    if [[ -f "${key_path}.pub" ]]; then
        echo ""
        echo -e "${BOLD}Public Key:${RESET}"
        echo -e "${DIM}$(cat "${key_path}.pub")${RESET}"
    fi

    # Cek apakah sudah di agent
    echo ""
    if ssh-add -l 2>/dev/null | grep -q "$(ssh-keygen -lf "$key_path" 2>/dev/null | awk '{print $2}')"; then
        echo -e "${GREEN}✔ Sudah dimuat di ssh-agent${RESET}"
    else
        echo -e "${YELLOW}○ Belum dimuat di ssh-agent${RESET}"
    fi
}

# ─── Helper: Tambah ke Agent ─────────────────────────────────
_tambah_ke_agent() {
    local key_path="$1"

    # Pastikan ssh-agent berjalan
    if [[ -z "${SSH_AUTH_SOCK:-}" ]]; then
        warn "ssh-agent tidak berjalan. Mencoba memulai..."
        eval "$(ssh-agent -s)" > /dev/null
    fi

    if ssh-add "$key_path" 2>/dev/null; then
        success "Key ${BOLD}$(basename "$key_path")${RESET} berhasil ditambahkan ke ssh-agent"
        echo ""
        info "Key aktif di agent:"
        ssh-add -l 2>/dev/null | while read -r line; do
            echo -e "  ${GREEN}→${RESET} $line"
        done
    else
        error "Gagal menambahkan ke ssh-agent."
        warn "Coba jalankan: ${BOLD}eval \$(ssh-agent -s)${RESET} lalu ulangi."
    fi
}

# ─── Menu: Tambah ke ssh-agent ───────────────────────────────
menu_tambah_agent() {
    header
    echo -e "${BOLD}${CYAN}── Tambah Key ke ssh-agent ──${RESET}"
    echo ""

    local keys
    keys=$(daftar_private_key)

    if [[ -z "$keys" ]]; then
        warn "Tidak ada SSH key yang ditemukan."
        return
    fi

    local pilihan
    pilihan=$(echo "$keys" | xargs -I{} basename {} \
        | fzf --prompt="🔑 Pilih Key ❯ " \
              --border=rounded --height=50% \
              --color="prompt:#82aaff,pointer:#ff757f,border:#7c3aed" \
              --reverse \
              --multi \
              --header="Tab=pilih banyak | Enter=tambah ke agent") || { warn "Dibatalkan."; return; }

    echo ""
    while IFS= read -r nama; do
        _tambah_ke_agent "${SSH_DIR}/${nama}"
    done <<< "$pilihan"
}

# ─── Menu: Copy Public Key ───────────────────────────────────
menu_copy_pubkey() {
    header
    echo -e "${BOLD}${CYAN}── Copy Public Key ke Clipboard ──${RESET}"
    echo ""

    local pubkeys
    pubkeys=$(find "${SSH_DIR}" -maxdepth 1 -name "*.pub" -type f 2>/dev/null)

    if [[ -z "$pubkeys" ]]; then
        warn "Tidak ada public key di ${SSH_DIR}"
        return
    fi

    local pilihan
    pilihan=$(echo "$pubkeys" | xargs -I{} basename {} \
        | fzf --prompt="📋 Pilih Public Key ❯ " \
              --border=rounded --height=50% \
              --color="prompt:#82aaff,pointer:#ff757f,border:#7c3aed" \
              --preview="cat ${SSH_DIR}/{}" \
              --preview-window="down:3:wrap" \
              --reverse) || { warn "Dibatalkan."; return; }

    local pubkey_content
    pubkey_content=$(cat "${SSH_DIR}/${pilihan}")

    echo ""
    clipboard_copy "$pubkey_content"
    echo ""
    echo -e "${DIM}Preview:${RESET}"
    echo -e "${GREEN}${pubkey_content}${RESET}"
}

# ─── Menu: Lihat Agent ───────────────────────────────────────
menu_lihat_agent() {
    header
    echo -e "${BOLD}${CYAN}── Key Aktif di ssh-agent ──${RESET}"
    echo ""

    if [[ -z "${SSH_AUTH_SOCK:-}" ]]; then
        warn "ssh-agent tidak berjalan."
        echo -e "Jalankan: ${BOLD}eval \$(ssh-agent -s)${RESET}"
        return
    fi

    local agent_keys
    agent_keys=$(ssh-add -l 2>/dev/null)

    if [[ $? -ne 0 ]] || [[ -z "$agent_keys" ]]; then
        warn "Tidak ada key yang dimuat di ssh-agent."
        return
    fi

    echo -e "${BOLD}Key yang aktif:${RESET}"
    echo ""
    while IFS= read -r line; do
        echo -e "  ${GREEN}🔑${RESET} $line"
    done <<< "$agent_keys"

    echo ""
    echo -e "${CYAN}Hapus semua key dari agent? [y/N]:${RESET} \c"
    read -r hapus
    if [[ "${hapus,,}" == "y" ]]; then
        ssh-add -D 2>/dev/null && success "Semua key dihapus dari agent." || error "Gagal menghapus."
    fi
}

# ─── Menu: Backup Key ────────────────────────────────────────
menu_backup() {
    header
    echo -e "${BOLD}${CYAN}── Backup SSH Keys ──${RESET}"
    echo ""

    mkdir -p "${BACKUP_DIR}"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_path="${BACKUP_DIR}/ssh_backup_${timestamp}.tar.gz"

    info "Membuat backup ke: ${BOLD}${backup_path}${RESET}"
    echo ""

    # Backup dengan permission yang benar
    tar -czf "$backup_path" -C "${HOME}" .ssh/ --exclude='.ssh/backups' 2>/dev/null

    if [[ $? -eq 0 ]]; then
        success "Backup berhasil!"
        echo ""
        echo -e "${BOLD}File:${RESET} ${backup_path}"
        echo -e "${BOLD}Size:${RESET} $(du -h "$backup_path" | cut -f1)"
        echo ""
        warn "Simpan backup ini di tempat yang aman (misal: USB terenkripsi)."
        warn "Jangan pernah upload ke cloud tanpa enkripsi tambahan!"

        # Tampilkan daftar backup
        echo ""
        echo -e "${BOLD}Semua backup:${RESET}"
        ls -lh "${BACKUP_DIR}" 2>/dev/null | tail -n +2 | while read -r line; do
            echo -e "  ${DIM}${line}${RESET}"
        done
    else
        error "Gagal membuat backup."
    fi
}

# ─── Menu: Hapus Key ─────────────────────────────────────────
menu_hapus() {
    header
    echo -e "${BOLD}${RED}── Hapus SSH Key ──${RESET}"
    echo ""
    warn "HATI-HATI: Menghapus key yang masih digunakan bisa memutus akses server!"
    echo ""

    local keys
    keys=$(daftar_private_key)

    if [[ -z "$keys" ]]; then
        warn "Tidak ada SSH key yang ditemukan."
        return
    fi

    local pilihan
    pilihan=$(echo "$keys" | xargs -I{} basename {} \
        | fzf --prompt="🗑️  Pilih Key yang Dihapus ❯ " \
              --border=rounded --height=50% \
              --color="prompt:#ff757f,pointer:#ff0000,border:#7c3aed" \
              --reverse \
              --header="HATI-HATI: Aksi ini permanen!") || { warn "Dibatalkan."; return; }

    local key_path="${SSH_DIR}/${pilihan}"

    echo ""
    echo -e "${RED}Akan dihapus:${RESET}"
    echo -e "  ${BOLD}${key_path}${RESET} (private key)"
    [[ -f "${key_path}.pub" ]] && echo -e "  ${BOLD}${key_path}.pub${RESET} (public key)"

    echo ""
    echo -e "${RED}${BOLD}Yakin? Ketik nama file untuk konfirmasi [${pilihan}]:${RESET} \c"
    read -r konfirmasi

    if [[ "$konfirmasi" == "$pilihan" ]]; then
        rm -f "$key_path" "${key_path}.pub"
        success "Key ${BOLD}${pilihan}${RESET} berhasil dihapus."
    else
        warn "Konfirmasi tidak cocok. Dibatalkan."
    fi
}

# ─── Menu: Config SSH ────────────────────────────────────────
menu_config() {
    header
    echo -e "${BOLD}${CYAN}── SSH Config Editor ──${RESET}"
    echo ""

    local config_file="${SSH_DIR}/config"

    if [[ ! -f "$config_file" ]]; then
        warn "File config belum ada. Membuat baru..."
        cat > "$config_file" << 'EOF'
# SSH Config - King's Setup
# Contoh:
# Host nama-alias
#     HostName 192.168.1.1
#     User username
#     Port 22
#     IdentityFile ~/.ssh/id_ed25519

Host *
    AddKeysToAgent yes
    IdentitiesOnly yes
    ServerAliveInterval 60
    ServerAliveCountMax 3
EOF
        chmod 600 "$config_file"
        success "File config dibuat."
    fi

    echo -e "${DIM}Isi SSH Config saat ini:${RESET}"
    echo ""
    cat -n "$config_file" | while IFS= read -r line; do
        echo -e "${DIM}${line}${RESET}"
    done

    echo ""
    local editor="${EDITOR:-nano}"
    echo -e "${CYAN}Edit dengan ${BOLD}${editor}${RESET}${CYAN}? [Y/n]:${RESET} \c"
    read -r jawab
    if [[ "${jawab,,}" != "n" ]]; then
        "$editor" "$config_file"
    fi
}

# ─── Main Loop ───────────────────────────────────────────────
main() {
    if ! cek_cmd fzf; then
        echo -e "${RED}fzf tidak ditemukan.${RESET} Install: ${BOLD}sudo pacman -S fzf${RESET}"
        exit 1
    fi

    # Buat direktori SSH jika belum ada
    mkdir -p "${SSH_DIR}"
    chmod 700 "${SSH_DIR}"

    local MENU
    MENU=$(cat <<'EOF'
1.  🔑  Generate Key Baru
2.  📋  List & Info Key
3.  🤖  Tambah ke ssh-agent
4.  📎  Copy Public Key ke Clipboard
5.  👁️   Lihat Key Aktif di Agent
6.  💾  Backup Semua Key
7.  ⚙️   Edit SSH Config
8.  🗑️   Hapus Key
──────────────────────────
0.  ❌  Keluar
EOF
)

    while true; do
        header

        # Status agent
        local agent_count=0
        ssh-add -l &>/dev/null && agent_count=$(ssh-add -l 2>/dev/null | wc -l) || true
        echo -e "  ${DIM}ssh-agent: ${GREEN}${agent_count} key aktif${RESET}"
        local key_count
        key_count=$(daftar_private_key | wc -l 2>/dev/null || echo 0)
        echo -e "  ${DIM}Total key: ${CYAN}${key_count} key${RESET}"
        echo ""

        local pilihan
        pilihan=$(echo "$MENU" | fzf \
            --prompt="  SSH Manager ❯ " \
            --border=rounded \
            --margin=3%,5% \
            --color="bg+:#1e1e2e,fg+:#cdd6f4,pointer:#ff757f,prompt:#cba6f7,border:#7c3aed,header:#89b4fa" \
            --reverse \
            --height=75% \
            --no-sort \
            --header="🔑 King's SSH Key Manager | 0=Keluar | Esc=Batal" \
            --bind='esc:abort') || true

        clear

        case "$pilihan" in
            "1.  🔑  Generate Key Baru")              menu_generate      ;;
            "2.  📋  List & Info Key")                menu_list          ;;
            "3.  🤖  Tambah ke ssh-agent")            menu_tambah_agent  ;;
            "4.  📎  Copy Public Key ke Clipboard")   menu_copy_pubkey   ;;
            "5.  👁️   Lihat Key Aktif di Agent")       menu_lihat_agent   ;;
            "6.  💾  Backup Semua Key")               menu_backup        ;;
            "7.  ⚙️   Edit SSH Config")               menu_config        ;;
            "8.  🗑️   Hapus Key")                     menu_hapus         ;;
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
