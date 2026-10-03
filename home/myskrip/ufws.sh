#!/bin/bash
# ============================================================
#   KING'S UFW FIREWALL MANAGER - v1.0
#   Kelola UFW firewall dengan mudah via menu interaktif fzf
#   Fitur: Status, Enable/Disable, Tambah/Hapus rule,
#          Profil aplikasi, Reset, dan Export rules
# ============================================================

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

VERSION="1.0"

header() {
    clear
    echo -e "${RED}╔══════════════════════════════════════════════╗${RESET}"
    echo -e "${RED}║${RESET}  ${BOLD}${YELLOW}🔥  KING'S UFW FIREWALL MANAGER  v${VERSION}${RESET}   ${RED}║${RESET}"
    echo -e "${RED}╚══════════════════════════════════════════════╝${RESET}"
    echo ""
}

# Cek UFW terinstal
cek_ufw() {
    if ! cek_cmd ufw; then
        error "UFW tidak ditemukan!"
        echo -e "Install dengan: ${BOLD}sudo pacman -S ufw${RESET}"
        exit 1
    fi
}

# Jalankan ufw dengan sudo
ufw_run() { sudo ufw "$@"; }

# Ambil status UFW (active/inactive)
status_ufw() {
    sudo ufw status 2>/dev/null | head -1 | awk '{print $2}'
}

# Indikator status berwarna
badge_status() {
    local st
    st=$(status_ufw)
    if [[ "$st" == "active" ]]; then
        echo -e "${GREEN}● AKTIF${RESET}"
    else
        echo -e "${RED}○ NONAKTIF${RESET}"
    fi
}

# ─── Menu: Tampilkan Status Lengkap ─────────────────────────
menu_status() {
    header
    echo -e "${BOLD}${CYAN}── Status UFW Firewall ──${RESET}"
    echo ""

    local status_raw
    status_raw=$(sudo ufw status verbose 2>/dev/null)

    if [[ -z "$status_raw" ]]; then
        error "Tidak bisa membaca status UFW."
        return
    fi

    echo "$status_raw" | while IFS= read -r line; do
        # Warnai baris penting
        if echo "$line" | grep -qi "active"; then
            echo -e "${GREEN}${BOLD}${line}${RESET}"
        elif echo "$line" | grep -qi "inactive"; then
            echo -e "${RED}${BOLD}${line}${RESET}"
        elif echo "$line" | grep -qi "allow\|permit"; then
            echo -e "${GREEN}${line}${RESET}"
        elif echo "$line" | grep -qi "deny\|reject\|drop"; then
            echo -e "${RED}${line}${RESET}"
        elif echo "$line" | grep -qi "limit"; then
            echo -e "${YELLOW}${line}${RESET}"
        else
            echo -e "${DIM}${line}${RESET}"
        fi
    done

    echo ""
    echo -e "${DIM}Default Policy:${RESET}"
    sudo ufw status verbose 2>/dev/null | grep "Default:" | while read -r line; do
        echo -e "  ${CYAN}→${RESET} $line"
    done
}

# ─── Menu: Enable / Disable UFW ──────────────────────────────
menu_toggle() {
    header
    local st
    st=$(status_ufw)

    if [[ "$st" == "active" ]]; then
        echo -e "${BOLD}${YELLOW}UFW saat ini: ${GREEN}AKTIF${RESET}"
        echo ""
        warn "Menonaktifkan firewall akan membuka semua port!"
        echo -e "${CYAN}Nonaktifkan UFW? [y/N]:${RESET} \c"
        read -r jawab
        if [[ "${jawab,,}" == "y" ]]; then
            sudo ufw disable
            success "UFW dinonaktifkan."
        else
            warn "Dibatalkan."
        fi
    else
        echo -e "${BOLD}${YELLOW}UFW saat ini: ${RED}NONAKTIF${RESET}"
        echo ""
        echo -e "${CYAN}Aktifkan UFW? [Y/n]:${RESET} \c"
        read -r jawab
        if [[ "${jawab,,}" != "n" ]]; then
            sudo ufw enable
            success "UFW diaktifkan."
        else
            warn "Dibatalkan."
        fi
    fi
}

# ─── Menu: Tambah Rule Allow ─────────────────────────────────
menu_allow() {
    header
    echo -e "${BOLD}${GREEN}── Tambah Rule ALLOW ──${RESET}"
    echo ""

    # Pilih mode input
    local mode
    mode=$(printf "Port Tunggal (misal: 80, 443, 8080)\nRange Port (misal: 8000:9000)\nPort + Protokol (misal: 22/tcp)\nDari IP Tertentu (misal: 192.168.1.0/24)\nAplikasi Profil (ssh, nginx, apache, dll)\nIP ke Port Tertentu (spesifik)" \
        | fzf --prompt="Mode Rule ❯ " --border=rounded --height=40% \
              --color="prompt:#82aaff,pointer:#c3e88d,border:#1a7a1a" \
              --reverse) || { warn "Dibatalkan."; return; }

    local rule=""

    case "$mode" in
        "Port Tunggal"*)
            echo -e "${CYAN}Masukkan nomor port:${RESET} \c"
            read -r port
            [[ -z "$port" ]] && { warn "Port kosong."; return; }
            rule="$port"
            ;;
        "Range Port"*)
            echo -e "${CYAN}Port awal:${RESET} \c"; read -r p1
            echo -e "${CYAN}Port akhir:${RESET} \c"; read -r p2
            [[ -z "$p1" || -z "$p2" ]] && { warn "Port kosong."; return; }
            rule="${p1}:${p2}"
            ;;
        "Port + Protokol"*)
            echo -e "${CYAN}Port:${RESET} \c"; read -r port
            local proto
            proto=$(echo -e "tcp\nudp" | fzf --prompt="Protokol ❯ " --height=20% --border=rounded) || return
            rule="${port}/${proto}"
            ;;
        "Dari IP Tertentu"*)
            echo -e "${CYAN}IP/CIDR sumber${RESET} ${DIM}(misal: 192.168.1.0/24 atau 10.0.0.5):${RESET} \c"
            read -r ip_src
            [[ -z "$ip_src" ]] && { warn "IP kosong."; return; }
            rule="from ${ip_src}"
            ;;
        "Aplikasi Profil"*)
            local app_list
            app_list=$(sudo ufw app list 2>/dev/null | tail -n +2 | sed 's/^[[:space:]]*//' | grep -v "^$")
            if [[ -z "$app_list" ]]; then
                warn "Tidak ada profil aplikasi tersedia."
                return
            fi
            local app
            app=$(echo "$app_list" | fzf --prompt="Aplikasi ❯ " --border=rounded --height=50% \
                      --color="prompt:#82aaff,pointer:#c3e88d,border:#1a7a1a" \
                      --reverse \
                      --preview="sudo ufw app info {}") || { warn "Dibatalkan."; return; }
            rule="$app"
            ;;
        "IP ke Port Tertentu"*)
            echo -e "${CYAN}IP/CIDR sumber:${RESET} \c"; read -r ip_src
            echo -e "${CYAN}Port tujuan:${RESET} \c"; read -r port
            local proto
            proto=$(echo -e "tcp\nudp\nany" | fzf --prompt="Protokol ❯ " --height=20% --border=rounded) || return
            if [[ "$proto" == "any" ]]; then
                rule="from ${ip_src} to any port ${port}"
            else
                rule="from ${ip_src} to any port ${port} proto ${proto}"
            fi
            ;;
    esac

    if [[ -z "$rule" ]]; then
        warn "Rule kosong. Dibatalkan."
        return
    fi

    echo ""
    echo -e "${GREEN}Rule yang akan ditambahkan:${RESET}"
    echo -e "  ${BOLD}sudo ufw allow ${rule}${RESET}"
    echo ""
    echo -e "${CYAN}Konfirmasi? [Y/n]:${RESET} \c"
    read -r konfirmasi
    if [[ "${konfirmasi,,}" != "n" ]]; then
        # shellcheck disable=SC2086
        sudo ufw allow $rule
        success "Rule ALLOW berhasil ditambahkan."
    else
        warn "Dibatalkan."
    fi
}

# ─── Menu: Tambah Rule Deny/Reject ───────────────────────────
menu_deny() {
    header
    echo -e "${BOLD}${RED}── Tambah Rule DENY/REJECT ──${RESET}"
    echo ""

    # Pilih tipe blokir
    local tipe
    tipe=$(printf "deny (drop tanpa notifikasi - lebih aman)\nreject (kirim pesan error ke pengirim)\nlimit (rate limit - anti brute force)" \
        | fzf --prompt="Tipe Blokir ❯ " --border=rounded --height=25% \
              --color="prompt:#ff757f,pointer:#ff0000,border:#7c0000" \
              --reverse) || { warn "Dibatalkan."; return; }

    local action
    case "$tipe" in
        deny*)   action="deny"   ;;
        reject*) action="reject" ;;
        limit*)  action="limit"  ;;
    esac

    echo -e "${CYAN}Port atau IP yang diblokir:${RESET} \c"
    read -r target
    [[ -z "$target" ]] && { warn "Target kosong."; return; }

    echo ""
    echo -e "${RED}Rule yang akan ditambahkan:${RESET}"
    echo -e "  ${BOLD}sudo ufw ${action} ${target}${RESET}"
    echo ""
    echo -e "${CYAN}Konfirmasi? [Y/n]:${RESET} \c"
    read -r konfirmasi
    if [[ "${konfirmasi,,}" != "n" ]]; then
        # shellcheck disable=SC2086
        sudo ufw "$action" $target
        success "Rule ${action^^} berhasil ditambahkan."
    else
        warn "Dibatalkan."
    fi
}

# ─── Menu: Hapus Rule ────────────────────────────────────────
menu_hapus_rule() {
    header
    echo -e "${BOLD}${RED}── Hapus Rule ──${RESET}"
    echo ""

    # Ambil daftar rule dengan nomor
    local rules_numbered
    rules_numbered=$(sudo ufw status numbered 2>/dev/null | grep "^\[")

    if [[ -z "$rules_numbered" ]]; then
        warn "Tidak ada rule yang bisa dihapus (atau UFW nonaktif)."
        return
    fi

    echo -e "${DIM}Pilih rule yang ingin dihapus (Tab=multi):${RESET}"
    echo ""

    local pilihan
    pilihan=$(echo "$rules_numbered" | fzf \
        --prompt="🗑️  Hapus Rule ❯ " \
        --border=rounded \
        --height=60% \
        --color="prompt:#ff757f,pointer:#ff0000,border:#7c0000,bg+:#2d0000" \
        --reverse \
        --multi \
        --header="Tab=multi-select | Enter=hapus | Ctrl+C=batal") || { warn "Dibatalkan."; return; }

    if [[ -z "$pilihan" ]]; then
        warn "Tidak ada yang dipilih."
        return
    fi

    # Ambil nomor rule, hapus dari terbesar ke terkecil (agar index tidak bergeser)
    local nomor_list
    nomor_list=$(echo "$pilihan" | grep -oP '(?<=\[)\d+(?=\])' | sort -rn)

    echo ""
    echo -e "${RED}Rule yang akan dihapus:${RESET}"
    echo "$pilihan" | while IFS= read -r line; do
        echo -e "  ${BOLD}${line}${RESET}"
    done
    echo ""
    echo -e "${RED}${BOLD}Yakin menghapus? [y/N]:${RESET} \c"
    read -r konfirmasi

    if [[ "${konfirmasi,,}" == "y" ]]; then
        while IFS= read -r nomor; do
            echo "y" | sudo ufw delete "$nomor" 2>/dev/null
            success "Rule #${nomor} dihapus."
        done <<< "$nomor_list"
    else
        warn "Dibatalkan."
    fi
}

# ─── Menu: Default Policy ────────────────────────────────────
menu_default_policy() {
    header
    echo -e "${BOLD}${CYAN}── Atur Default Policy ──${RESET}"
    echo ""

    echo -e "${DIM}Default policy menentukan apa yang terjadi pada koneksi yang tidak cocok dengan rule manapun.${RESET}"
    echo ""

    # Policy incoming
    local incoming
    incoming=$(printf "deny (Rekomendasi: blokir semua masuk)\nallow (izinkan semua masuk - TIDAK AMAN)\nreject (tolak dengan notifikasi)" \
        | fzf --prompt="Default INCOMING ❯ " --border=rounded --height=25% \
              --color="prompt:#82aaff,pointer:#ff757f,border:#3d59a1" \
              --reverse) || { warn "Dibatalkan."; return; }

    local in_policy
    case "$incoming" in
        deny*)   in_policy="deny"   ;;
        allow*)  in_policy="allow"  ;;
        reject*) in_policy="reject" ;;
    esac

    # Policy outgoing
    local outgoing
    outgoing=$(printf "allow (Rekomendasi: izinkan semua keluar)\ndeny (blokir semua keluar)" \
        | fzf --prompt="Default OUTGOING ❯ " --border=rounded --height=20% \
              --color="prompt:#82aaff,pointer:#ff757f,border:#3d59a1" \
              --reverse) || { warn "Dibatalkan."; return; }

    local out_policy
    case "$outgoing" in
        allow*) out_policy="allow" ;;
        deny*)  out_policy="deny"  ;;
    esac

    echo ""
    echo -e "${CYAN}Policy baru:${RESET}"
    echo -e "  Incoming: ${BOLD}${in_policy}${RESET}"
    echo -e "  Outgoing: ${BOLD}${out_policy}${RESET}"
    echo ""
    echo -e "${CYAN}Terapkan? [Y/n]:${RESET} \c"
    read -r konfirmasi
    if [[ "${konfirmasi,,}" != "n" ]]; then
        sudo ufw default "$in_policy" incoming
        sudo ufw default "$out_policy" outgoing
        success "Default policy berhasil diperbarui."
    else
        warn "Dibatalkan."
    fi
}

# ─── Menu: Preset Cepat ──────────────────────────────────────
menu_preset() {
    header
    echo -e "${BOLD}${CYAN}── Preset Rule Cepat ──${RESET}"
    echo ""

    local presets
    presets=$(cat <<'EOF'
🌐 Web Server (80 + 443 TCP)
🔒 SSH Only (22 TCP)
🔒 SSH Custom Port
🐳 Docker Ports (2375, 2376)
🖥️  Desktop Remote (VNC 5900, RDP 3389)
📧 Mail Server (25, 587, 993, 995)
🗄️  Database - MySQL (3306)
🗄️  Database - PostgreSQL (5432)
🏠 Localhost All (127.0.0.1)
🔄 Reset ke Default Aman
EOF
)

    local pilihan
    pilihan=$(echo "$presets" | fzf \
        --prompt="⚡ Preset ❯ " \
        --border=rounded --height=60% \
        --color="prompt:#82aaff,pointer:#c3e88d,border:#1a7a1a" \
        --reverse) || { warn "Dibatalkan."; return; }

    echo ""

    case "$pilihan" in
        "🌐 Web Server"*)
            info "Menambahkan rule Web Server (80 + 443)..."
            sudo ufw allow 80/tcp
            sudo ufw allow 443/tcp
            success "Web server rules ditambahkan."
            ;;
        "🔒 SSH Only"*)
            info "Mengizinkan SSH (port 22)..."
            sudo ufw allow 22/tcp
            success "SSH rule ditambahkan."
            ;;
        "🔒 SSH Custom Port"*)
            echo -e "${CYAN}Port SSH custom:${RESET} \c"
            read -r ssh_port
            [[ -z "$ssh_port" ]] && { warn "Port kosong."; return; }
            sudo ufw allow "${ssh_port}/tcp"
            success "SSH custom port ${ssh_port} ditambahkan."
            ;;
        "🐳 Docker Ports"*)
            info "Menambahkan rule Docker..."
            sudo ufw allow 2375/tcp
            sudo ufw allow 2376/tcp
            warn "Hati-hati: Docker API port sebaiknya hanya dari IP lokal!"
            ;;
        "🖥️  Desktop Remote"*)
            sudo ufw allow 5900/tcp
            sudo ufw allow 3389/tcp
            success "VNC dan RDP rules ditambahkan."
            ;;
        "📧 Mail Server"*)
            for port in 25 587 993 995; do
                sudo ufw allow "${port}/tcp"
            done
            success "Mail server rules ditambahkan."
            ;;
        "🗄️  Database - MySQL"*)
            echo -e "${CYAN}Izinkan dari IP apa? ${DIM}(kosong=semua, rekomendasi: IP tertentu):${RESET} \c"
            read -r db_ip
            if [[ -n "$db_ip" ]]; then
                sudo ufw allow from "$db_ip" to any port 3306 proto tcp
            else
                sudo ufw allow 3306/tcp
                warn "Membuka MySQL ke semua IP — pastikan ada autentikasi kuat!"
            fi
            success "MySQL rule ditambahkan."
            ;;
        "🗄️  Database - PostgreSQL"*)
            echo -e "${CYAN}Izinkan dari IP apa? ${DIM}(kosong=semua):${RESET} \c"
            read -r db_ip
            if [[ -n "$db_ip" ]]; then
                sudo ufw allow from "$db_ip" to any port 5432 proto tcp
            else
                sudo ufw allow 5432/tcp
            fi
            success "PostgreSQL rule ditambahkan."
            ;;
        "🏠 Localhost All"*)
            sudo ufw allow from 127.0.0.1
            success "Localhost diizinkan penuh."
            ;;
        "🔄 Reset ke Default Aman"*)
            warn "Ini akan MENGHAPUS semua rule dan menonaktifkan UFW!"
            echo -e "${RED}${BOLD}Yakin? [y/N]:${RESET} \c"
            read -r konfirmasi
            if [[ "${konfirmasi,,}" == "y" ]]; then
                echo "y" | sudo ufw reset
                sudo ufw default deny incoming
                sudo ufw default allow outgoing
                sudo ufw allow 22/tcp
                sudo ufw enable
                success "UFW direset. Rule default: deny incoming, allow outgoing, allow SSH."
            else
                warn "Dibatalkan."
            fi
            ;;
    esac
}

# ─── Menu: Export Rules ──────────────────────────────────────
menu_export() {
    header
    echo -e "${BOLD}${CYAN}── Export Rules UFW ──${RESET}"
    echo ""

    local export_dir="${HOME}/ufw-exports"
    mkdir -p "$export_dir"
    local filename="${export_dir}/ufw_rules_$(date +%Y%m%d_%H%M%S).txt"

    {
        echo "# UFW Firewall Rules Export"
        echo "# Dibuat: $(date)"
        echo "# Host: $(hostname)"
        echo ""
        echo "=== STATUS ==="
        sudo ufw status verbose 2>/dev/null
        echo ""
        echo "=== RULES BERNOMOR ==="
        sudo ufw status numbered 2>/dev/null
        echo ""
        echo "=== RULES RAW (/etc/ufw/user.rules) ==="
        sudo cat /etc/ufw/user.rules 2>/dev/null || echo "Tidak bisa diakses."
    } > "$filename"

    success "Rules diekspor ke: ${BOLD}${filename}${RESET}"
    echo ""
    echo -e "${DIM}Preview:${RESET}"
    head -20 "$filename" | while IFS= read -r line; do
        echo -e "  ${DIM}${line}${RESET}"
    done
    echo -e "  ${DIM}...${RESET}"
}

# ─── Menu: Logging UFW ───────────────────────────────────────
menu_logging() {
    header
    echo -e "${BOLD}${CYAN}── UFW Logging ──${RESET}"
    echo ""

    local level
    level=$(printf "off (nonaktif)\nlow (hanya drop)\nmedium (drop + invalid)\nhigh (semua) \nfull (sangat detail)" \
        | fzf --prompt="Level Logging ❯ " --border=rounded --height=35% \
              --color="prompt:#82aaff,pointer:#ff757f,border:#3d59a1" \
              --reverse) || { warn "Dibatalkan."; return; }

    local lvl
    lvl=$(echo "$level" | awk '{print $1}')
    sudo ufw logging "$lvl"
    success "Logging UFW diset ke: ${BOLD}${lvl}${RESET}"
    echo ""
    info "Log UFW tersimpan di: ${BOLD}/var/log/ufw.log${RESET}"
    echo ""

    echo -e "${CYAN}Lihat log UFW sekarang? [y/N]:${RESET} \c"
    read -r jawab
    if [[ "${jawab,,}" == "y" ]]; then
        echo ""
        if [[ -f "/var/log/ufw.log" ]]; then
            sudo tail -30 /var/log/ufw.log | while IFS= read -r line; do
                if echo "$line" | grep -qi "block\|deny\|drop"; then
                    echo -e "${RED}${line}${RESET}"
                elif echo "$line" | grep -qi "allow"; then
                    echo -e "${GREEN}${line}${RESET}"
                else
                    echo -e "${DIM}${line}${RESET}"
                fi
            done
        else
            warn "File /var/log/ufw.log tidak ditemukan."
            info "Coba cek di journalctl: ${BOLD}sudo journalctl -f | grep UFW${RESET}"
        fi
    fi
}

# ─── Main Loop ───────────────────────────────────────────────
main() {
    cek_ufw

    if ! cek_cmd fzf; then
        echo -e "${RED}fzf tidak ditemukan.${RESET} Install: ${BOLD}sudo pacman -S fzf${RESET}"
        exit 1
    fi

    local MENU
    MENU=$(cat <<'EOF'
1.  📊  Status & Rules Lengkap
2.  ⚡  Enable / Disable UFW
3.  ✅  Tambah Rule ALLOW
4.  🚫  Tambah Rule DENY / REJECT
5.  🗑️   Hapus Rule
6.  🛡️   Atur Default Policy
7.  ⚡  Preset Rule Cepat
8.  📝  Atur Level Logging
9.  💾  Export Rules ke File
──────────────────────────
0.  ❌  Keluar
EOF
)

    while true; do
        header

        # Badge status
        echo -e "  ${DIM}Status Firewall: $(badge_status)${RESET}"

        # Hitung jumlah rule
        local rule_count=0
        rule_count=$(sudo ufw status numbered 2>/dev/null | grep -c "^\[" || true)
        echo -e "  ${DIM}Total Rules:     ${CYAN}${rule_count} rule aktif${RESET}"
        echo ""

        local pilihan
        pilihan=$(echo "$MENU" | fzf \
            --prompt="  Firewall Manager ❯ " \
            --border=rounded \
            --margin=3%,5% \
            --color="bg+:#2d0a0a,fg+:#ffcccc,pointer:#ff757f,prompt:#ff9e64,border:#7c0000,header:#f7768e" \
            --reverse \
            --height=75% \
            --no-sort \
            --header="🔥 King's UFW Manager | 0=Keluar | Esc=Batal" \
            --bind='esc:abort') || true

        clear

        case "$pilihan" in
            "1.  📊  Status & Rules Lengkap")     menu_status          ;;
            "2.  ⚡  Enable / Disable UFW")        menu_toggle          ;;
            "3.  ✅  Tambah Rule ALLOW")           menu_allow           ;;
            "4.  🚫  Tambah Rule DENY / REJECT")   menu_deny            ;;
            "5.  🗑️   Hapus Rule")                 menu_hapus_rule      ;;
            "6.  🛡️   Atur Default Policy")        menu_default_policy  ;;
            "7.  ⚡  Preset Rule Cepat")           menu_preset          ;;
            "8.  📝  Atur Level Logging")          menu_logging         ;;
            "9.  💾  Export Rules ke File")        menu_export          ;;
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
