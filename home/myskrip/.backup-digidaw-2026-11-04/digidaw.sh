#!/bin/bash
# ============================================================
#   digidaw.sh — hidupkan / matikan / cek status Digidaw + Ollama
#
#   Pemakaian:
#     digidaw.sh                 menu (fzf)
#     digidaw.sh hidup           jalankan Ollama lalu Digidaw
#     digidaw.sh mati            matikan Digidaw (+ HUD & pemutar musiknya) dan Ollama
#     digidaw.sh status          cek semuanya
#
#   Tambahkan --permanen pada hidup/mati untuk juga menyalakan / mematikan
#   autostart saat login & boot (Digidaw autostart + layanan ollama).
#   Ollama adalah layanan sistem, jadi menyalakan/mematikannya butuh sudo.
# ============================================================

source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib.sh"

DIGIDAW_DIR="$HOME/Project/digidaw"
START_SCRIPT="$DIGIDAW_DIR/start_digidaw.sh"
AUTOSTART_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/autostart/digidaw.desktop"
UNIT="digidaw.service"                   # layanan Digidaw sendiri: systemd menghidupkannya lagi bila crash / macet
HUD_PORT=8765
OLLAMA_URL="http://127.0.0.1:11434"
PROC_PATTERN='venv/bin/python .*main\.py'
PLAYER_PATTERN='browser_profile_(firefox|linux)'   # pemutar YouTube milik Digidaw (profil browser terpisah)

# ─── Helper ─────────────────────────────────────────────────
digidaw_pids() { pgrep -f "$PROC_PATTERN"; }
player_pids()  { pgrep -f -- "$PLAYER_PATTERN"; }
ollama_aktif() { systemctl is-active --quiet ollama; }
ollama_siap()  { curl -s --max-time 1 "$OLLAMA_URL/api/version" &>/dev/null; }
hud_siap()     { ss -ltn 2>/dev/null | grep -q ":$HUD_PORT "; }
unit_ada()     { systemctl --user cat "$UNIT" &>/dev/null; }

tunggu() {   # tunggu <detik> <perintah...> : true begitu perintahnya berhasil
    local batas=$(( $1 * 2 )); shift
    for ((i = 0; i < batas; i++)); do "$@" && return 0; sleep 0.5; done
    return 1
}

autostart_aktif() {
    systemctl --user is-enabled --quiet "$UNIT" 2>/dev/null && return 0
    [[ -f "$AUTOSTART_FILE" ]] && ! grep -qiE '^(Hidden=true|X-GNOME-Autostart-enabled=false)' "$AUTOSTART_FILE"
}

set_autostart() {   # set_autostart true|false
    # saat login lewat layanan systemd (dijaga); autostart .desktop lama selalu dimatikan agar tidak jalan dua kali
    if [[ -f "$AUTOSTART_FILE" ]]; then
        sed -i '/^Hidden=/d;/^X-GNOME-Autostart-enabled=/d' "$AUTOSTART_FILE"
        printf 'X-GNOME-Autostart-enabled=false\nHidden=true\n' >> "$AUTOSTART_FILE"
    fi
    if unit_ada; then
        if [[ "$1" == true ]]; then systemctl --user enable --quiet "$UNIT"; else systemctl --user disable --quiet "$UNIT"; fi
    elif [[ "$1" == true ]]; then
        warn "Layanan $UNIT belum terpasang (dipasang Digidaw sendiri saat pertama berjalan)"
    fi
}

# ─── Hidupkan ───────────────────────────────────────────────
hidupkan() {
    local permanen=$1
    echo -e "\n${BOLD}🟢 Menghidupkan Digidaw${RESET}\n"

    if ollama_aktif; then
        success "Ollama sudah berjalan"
    else
        info "Menjalankan Ollama (butuh sudo)..."
        sudo systemctl start ollama || { error "Ollama gagal dijalankan"; }
    fi
    if tunggu 20 ollama_siap; then
        success "Ollama siap di $OLLAMA_URL"
    else
        warn "Ollama belum merespons — Digidaw tetap jalan, semua lewat Gemini"
    fi

    if [[ -n "$(digidaw_pids)" ]]; then
        success "Digidaw sudah berjalan (PID $(digidaw_pids | head -1))"
    else
        info "Menjalankan Digidaw..."
        if unit_ada; then
            systemctl --user start "$UNIT"
        else
            setsid -f "$START_SCRIPT" --background >/dev/null 2>&1
        fi
        if tunggu 40 hud_siap; then
            success "Digidaw berjalan (PID $(digidaw_pids | head -1)) · HUD http://127.0.0.1:$HUD_PORT"
        elif [[ -n "$(digidaw_pids)" ]]; then
            warn "Digidaw berjalan, tapi HUD belum siap. Lihat: $DIGIDAW_DIR/logs/digidaw.log"
        else
            error "Digidaw gagal berjalan. Lihat: $DIGIDAW_DIR/logs/digidaw.log"
            return 1
        fi
    fi

    if [[ "$permanen" == true ]]; then
        set_autostart true && success "Autostart Digidaw saat login: aktif"
        sudo systemctl enable ollama --quiet && success "Ollama saat boot: aktif"
    fi
}

# ─── Matikan ────────────────────────────────────────────────
matikan() {
    local permanen=$1
    echo -e "\n${BOLD}🔴 Mematikan Digidaw${RESET}\n"

    if [[ -n "$(digidaw_pids)" ]]; then
        info "Menghentikan Digidaw..."
        if unit_ada && systemctl --user is-active --quiet "$UNIT"; then
            systemctl --user stop "$UNIT"
        else
            pkill -TERM -f "$PROC_PATTERN"
        fi
        if ! tunggu 8 bash -c "! pgrep -f '$PROC_PATTERN' >/dev/null"; then
            warn "Digidaw tidak mau berhenti, dihentikan paksa"
            pkill -KILL -f "$PROC_PATTERN"
        fi
        success "Digidaw dihentikan"
    else
        success "Digidaw memang tidak berjalan"
    fi

    # jendela HUD (Chrome mode aplikasi) dan pemutar musik Digidaw — browser Anda sendiri tidak disentuh
    if cek_cmd hyprctl && hyprctl clients -j 2>/dev/null | grep -q '"title": "DIGIDAW HUD"'; then
        hyprctl dispatch closewindow 'title:^DIGIDAW HUD$' >/dev/null && success "Jendela HUD ditutup"
    fi
    if [[ -n "$(player_pids)" ]]; then
        pkill -TERM -f -- "$PLAYER_PATTERN"
        tunggu 5 bash -c "! pgrep -f -- '$PLAYER_PATTERN' >/dev/null" || pkill -KILL -f -- "$PLAYER_PATTERN"
        success "Pemutar musik Digidaw ditutup"
    fi

    if ollama_aktif; then
        info "Menghentikan Ollama (butuh sudo)..."
        if sudo systemctl stop ollama; then
            success "Ollama dihentikan (VRAM & RAM model dibebaskan)"
        else
            error "Ollama gagal dihentikan"
        fi
    else
        success "Ollama memang tidak berjalan"
    fi

    if [[ "$permanen" == true ]]; then
        set_autostart false && success "Autostart Digidaw saat login: nonaktif"
        sudo systemctl disable ollama --quiet && success "Ollama saat boot: nonaktif"
    elif autostart_aktif || systemctl is-enabled --quiet ollama 2>/dev/null; then
        echo -e "${DIM}Catatan: setelah login / reboot berikutnya keduanya hidup lagi otomatis."
        echo -e "Pakai '$(basename "$0") mati --permanen' agar tetap mati.${RESET}"
    fi
}

# ─── Status ─────────────────────────────────────────────────
baris() { printf "   %-16s %b\n" "$1" "$2"; }

status() {
    echo -e "\n${BOLD}📊 Status Digidaw${RESET}\n"

    local pid
    pid=$(digidaw_pids | head -1)
    if [[ -n "$pid" ]]; then
        local mem up
        mem=$(ps -o rss= -p "$pid" | awk '{printf "%.0f MB", $1/1024}')
        up=$(ps -o etime= -p "$pid" | xargs)
        baris "Digidaw" "${GREEN}● berjalan${RESET}  PID $pid · RAM $mem · aktif $up"
        if systemctl --user is-active --quiet "$UNIT" 2>/dev/null; then
            baris "Penjaga" "${GREEN}● systemd ($UNIT): hidup lagi otomatis bila crash / macet${RESET}"
        else
            baris "Penjaga" "${YELLOW}○ berjalan tanpa penjaga (dinyalakan di luar systemd)${RESET}"
        fi
    else
        baris "Digidaw" "${RED}○ mati${RESET}"
    fi
    if hud_siap; then
        baris "HUD" "${GREEN}● http://127.0.0.1:$HUD_PORT${RESET}"
    else
        baris "HUD" "${DIM}○ tidak aktif${RESET}"
    fi
    if [[ -n "$(player_pids)" ]]; then
        baris "Pemutar musik" "${GREEN}● terbuka${RESET}"
    else
        baris "Pemutar musik" "${DIM}○ tertutup${RESET}"
    fi

    if ollama_aktif; then
        local models
        models=$(ollama ps 2>/dev/null | awk 'NR>1 {printf "%s (%s %s, %s) ", $1, $3, $4, $5" "$6}')
        baris "Ollama" "${GREEN}● berjalan${RESET}  ${models:+dimuat: $models}"
        [[ -z "$models" ]] && baris "" "${DIM}belum ada model di memori (dimuat saat dipakai)${RESET}"
    else
        baris "Ollama" "${RED}○ mati${RESET}"
    fi
    if cek_cmd nvidia-smi; then
        baris "VRAM GPU" "$(nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader 2>/dev/null | sed 's/, / \/ /')"
    fi

    echo ""
    if autostart_aktif; then
        baris "Autostart" "${GREEN}Digidaw hidup otomatis saat login${RESET}"
    else
        baris "Autostart" "${YELLOW}Digidaw tidak hidup otomatis${RESET}"
    fi
    if systemctl is-enabled --quiet ollama 2>/dev/null; then
        baris "" "${GREEN}Ollama hidup otomatis saat boot${RESET}"
    else
        baris "" "${YELLOW}Ollama tidak hidup otomatis${RESET}"
    fi
    echo ""
}

# ─── Menu & argumen ─────────────────────────────────────────
bantuan() {
    echo "Pemakaian: $(basename "$0") [hidup|mati|status] [--permanen]"
}

menu() {
    local pilih
    if cek_cmd fzf; then
        pilih=$(printf '%s\n' "🟢 Hidupkan" "🔴 Matikan" "📊 Status" "🔴 Matikan permanen (juga saat boot)" \
                "🟢 Hidupkan permanen (juga saat boot)" |
                fzf --height=40% --reverse --prompt="Digidaw > " --header="Pilih aksi")
    else
        select pilih in "🟢 Hidupkan" "🔴 Matikan" "📊 Status"; do break; done
    fi
    case "$pilih" in
        "🟢 Hidupkan")                             hidupkan false ;;
        "🔴 Matikan")                              matikan false ;;
        "📊 Status")                               status ;;
        "🔴 Matikan permanen (juga saat boot)")    matikan true ;;
        "🟢 Hidupkan permanen (juga saat boot)")   hidupkan true ;;
        *) exit 0 ;;
    esac
}

permanen=false
[[ " $* " == *" --permanen "* ]] && permanen=true

case "${1:-}" in
    hidup|on|start|nyala|nyalakan)  hidupkan "$permanen" ;;
    mati|off|stop|matikan)          matikan "$permanen" ;;
    status|cek)                     status ;;
    -h|--help|help)                 bantuan ;;
    "")                             menu ;;
    *)                              bantuan; exit 1 ;;
esac
