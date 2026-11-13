#!/bin/bash
# ============================================================
#   digidaw.sh — satu tombol untuk Digidaw
#
#   Pemakaian:
#     digidaw.sh                 Digidaw mati: langsung dihidupkan
#                                Digidaw hidup: pilih matikan total / mulai ulang / status
#     digidaw.sh hidup           hidupkan Ollama lalu Digidaw
#     digidaw.sh mati            matikan total: Digidaw, HUD, Agenda, pemutar musik, dan Ollama.
#                                Tetap mati, juga sesudah login / reboot, sampai skrip ini dijalankan lagi
#     digidaw.sh restart         mulai ulang Digidaw saja
#     digidaw.sh status          cek semuanya
#     digidaw.sh autostart on    hidup otomatis saat login (off: tidak)
#
#   Hidup lagi mengembalikan autostart seperti sebelum dimatikan.
#   Ollama adalah layanan sistem, jadi menyalakan/mematikannya butuh sudo. Tanpa sudo
#   (bukan dari terminal) modelnya tetap dilepas dari VRAM.
#   Versi lama: .backup-digidaw-2026-11-04/digidaw.sh
# ============================================================

source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib.sh"

DIGIDAW_DIR="$HOME/Project/digidaw"
START_SCRIPT="$DIGIDAW_DIR/start_digidaw.sh"
LOG_FILE="$DIGIDAW_DIR/logs/digidaw.log"
AUTOSTART_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/autostart/digidaw.desktop"
STATE_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/digidaw/sebelum-mati-total"   # autostart sebelum dimatikan, untuk dikembalikan
UNIT="digidaw.service"                   # layanan Digidaw sendiri: systemd menghidupkannya lagi bila crash / macet
HUD_PORT=8765
OLLAMA_URL="http://127.0.0.1:11434"
PROC_PATTERN='venv/bin/python .*main\.py'
PLAYER_PATTERN='browser_profile_(firefox|linux)'   # pemutar YouTube milik Digidaw (profil browser terpisah)
READY_PATTERN='Whisper .* berjalan|frasa tertangkap'   # di log: pendengaran sudah siap

# ─── Helper ─────────────────────────────────────────────────
digidaw_pids() { pgrep -f "$PROC_PATTERN"; }
player_pids()  { pgrep -f -- "$PLAYER_PATTERN"; }
ollama_aktif() { systemctl is-active --quiet ollama; }
ollama_siap()  { curl -s --max-time 1 "$OLLAMA_URL/api/version" &>/dev/null; }
hud_siap()     { ss -ltn 2>/dev/null | grep -q ":$HUD_PORT "; }
unit_ada()     { systemctl --user cat "$UNIT" &>/dev/null; }
di_terminal()  { [[ -t 0 && -t 1 ]]; }
bisa_sudo()    { sudo -n true 2>/dev/null || di_terminal; }   # tanpa terminal, sudo tidak bisa menanyakan sandi

tunggu() {   # tunggu <detik> <perintah...> : true begitu perintahnya berhasil
    local batas=$(( $1 * 2 )); shift
    for ((i = 0; i < batas; i++)); do "$@" && return 0; sleep 0.5; done
    return 1
}

kabari() {   # dijalankan tanpa terminal (mis. dari keybind): hasilnya tetap terlihat
    di_terminal || notify-send -a Digidaw "Digidaw" "$1" 2>/dev/null
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

# ─── Keadaan sebelum mati total ─────────────────────────────
ingat_keadaan() {
    [[ -f "$STATE_FILE" ]] && return 0      # sudah mati total: keadaan aslinya jangan tertimpa
    mkdir -p "$(dirname "$STATE_FILE")"
    {
        autostart_aktif && echo "autostart=1"
        systemctl is-enabled --quiet ollama 2>/dev/null && echo "ollama=1"
    } > "$STATE_FILE"
}

kembalikan_keadaan() {
    [[ -f "$STATE_FILE" ]] || return 0
    if grep -q '^autostart=1' "$STATE_FILE"; then
        set_autostart true && success "Hidup otomatis saat login: aktif lagi"
    fi
    if grep -q '^ollama=1' "$STATE_FILE" && ! systemctl is-enabled --quiet ollama 2>/dev/null; then
        if bisa_sudo; then
            sudo systemctl enable --quiet ollama && success "Ollama saat boot: aktif lagi"
        else
            warn "Ollama saat boot belum diaktifkan lagi (butuh sudo). Jalankan: sudo systemctl enable ollama"
        fi
    fi
    rm -f "$STATE_FILE"
}

# ─── Hidupkan ───────────────────────────────────────────────
hidupkan() {
    echo -e "\n${BOLD}🟢 Menghidupkan Digidaw${RESET}\n"
    kembalikan_keadaan

    if ollama_aktif; then
        success "Ollama sudah berjalan"
    elif bisa_sudo; then
        info "Menjalankan Ollama (butuh sudo)..."
        sudo systemctl start ollama || error "Ollama gagal dijalankan"
    else
        warn "Ollama mati dan butuh sudo: jalankan skrip ini dari terminal untuk otak lokalnya"
    fi
    if ollama_aktif; then
        if tunggu 20 ollama_siap; then
            success "Ollama siap di $OLLAMA_URL"
        else
            warn "Ollama belum merespons — Digidaw tetap jalan, semua lewat Gemini"
        fi
    fi

    if [[ -n "$(digidaw_pids)" ]]; then
        success "Digidaw sudah berjalan (PID $(digidaw_pids | head -1))"
        kabari "Digidaw sudah berjalan."
        return 0
    fi
    info "Menjalankan Digidaw..."
    local dari=0
    [[ -f "$LOG_FILE" ]] && dari=$(wc -l < "$LOG_FILE")
    if unit_ada; then
        systemctl --user reset-failed "$UNIT" 2>/dev/null
        systemctl --user start "$UNIT"
    else
        setsid -f "$START_SCRIPT" --background >/dev/null 2>&1
    fi
    if ! tunggu 40 hud_siap; then
        if [[ -n "$(digidaw_pids)" ]]; then
            warn "Digidaw berjalan, tapi HUD belum siap. Lihat: $LOG_FILE"
            kabari "Digidaw berjalan, tapi belum siap."
            return 0
        fi
        error "Digidaw gagal berjalan. Lihat: $LOG_FILE"
        kabari "Digidaw gagal berjalan."
        return 1
    fi
    success "Digidaw berjalan (PID $(digidaw_pids | head -1)) · HUD http://127.0.0.1:$HUD_PORT"
    if tunggu 30 bash -c "tail -n +$((dari + 1)) '$LOG_FILE' 2>/dev/null | grep -qE '$READY_PATTERN'"; then
        success "Digidaw siap dipanggil. Ucapkan \"buka sistem\" untuk membuka HUD."
        kabari "Digidaw siap dipanggil."
    else
        warn "Pendengarannya masih dimuat, tunggu sebentar sebelum memanggil."
        kabari "Digidaw hidup, pendengarannya masih dimuat."
    fi
}

# ─── Matikan total ──────────────────────────────────────────
ingatkan_yang_berhenti() {
    # alarm yang tidak akan berbunyi selama Digidaw mati: lebih baik tahu sekarang daripada kesiangan
    local file="$DIGIDAW_DIR/alarms.json" isi=""
    if [[ -f "$file" ]] && cek_cmd python3; then
        isi=$(python3 - "$file" <<'PY' 2>/dev/null
import datetime, json, sys, time
try:
    items = json.load(open(sys.argv[1]))
except (OSError, ValueError):
    items = []
hari = ["Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu", "Minggu"]
coming = sorted((i for i in items if i.get("due", 0) > time.time()), key=lambda i: i["due"])
for item in coming[:4]:
    when = datetime.datetime.fromtimestamp(item["due"])
    print(f"   {hari[when.weekday()]} {when:%H.%M}  {item.get('label') or item.get('kind', 'alarm')}")
PY
)
    fi
    if [[ -n "$isi" ]]; then
        warn "Selama Digidaw mati, ini tidak akan berbunyi:"
        echo "$isi"
    fi
    echo -e "${DIM}Pengingat agenda dan kuliah juga berhenti sampai Digidaw dihidupkan lagi.${RESET}\n"
}

matikan() {
    echo -e "\n${BOLD}🔴 Mematikan Digidaw total${RESET}\n"
    ingatkan_yang_berhenti

    # autostart dulu: apa pun yang terjadi sesudah ini, Digidaw tidak hidup sendiri lagi
    ingat_keadaan
    if autostart_aktif; then
        set_autostart false && success "Hidup otomatis saat login: dimatikan sampai skrip ini dijalankan lagi"
    fi

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
    unit_ada && systemctl --user reset-failed "$UNIT" 2>/dev/null

    # jendela HUD & Agenda (Chrome mode aplikasi) dan pemutar musik Digidaw — browser Anda sendiri tidak disentuh
    if cek_cmd hyprctl; then
        local judul
        for judul in "DIGIDAW HUD" "Agenda Digidaw"; do
            if hyprctl clients -j 2>/dev/null | grep -q "\"title\": \"$judul\""; then
                hyprctl dispatch "hl.dsp.window.close({window='title:^($judul)\$'})" >/dev/null && success "Jendela $judul ditutup"
            fi
        done
    fi
    if [[ -n "$(player_pids)" ]]; then
        pkill -TERM -f -- "$PLAYER_PATTERN"
        tunggu 5 bash -c "! pgrep -f -- '$PLAYER_PATTERN' >/dev/null" || pkill -KILL -f -- "$PLAYER_PATTERN"
        success "Pemutar musik Digidaw ditutup"
    fi

    if ollama_aktif; then
        # VRAM & RAM model dibebaskan dulu: tidak butuh sandi
        local model
        for model in $(ollama ps 2>/dev/null | awk 'NR>1 {print $1}'); do
            ollama stop "$model" 2>/dev/null
        done
        if bisa_sudo; then
            info "Menghentikan Ollama (butuh sudo)..."
            if sudo systemctl stop ollama; then
                success "Ollama dihentikan"
                systemctl is-enabled --quiet ollama 2>/dev/null && sudo systemctl disable --quiet ollama \
                    && success "Ollama saat boot: dimatikan sampai skrip ini dijalankan lagi"
            else
                warn "Ollama gagal dihentikan, tapi modelnya sudah dilepas dari VRAM"
            fi
        else
            warn "Model Ollama dilepas dari VRAM. Layanannya tetap jalan (butuh sudo); jalankan dari terminal untuk mematikannya."
        fi
    else
        success "Ollama memang tidak berjalan"
    fi

    echo ""
    if [[ -z "$(digidaw_pids)" ]] && ! hud_siap; then
        success "${BOLD}Digidaw mati total.${RESET} Untuk menghidupkannya lagi, jalankan skrip ini."
        cek_cmd nvidia-smi && baris "VRAM GPU" "$(nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader 2>/dev/null | sed 's/, / \/ /')"
        kabari "Digidaw mati total."
    else
        error "Ada yang masih berjalan. Lihat: $(basename "$0") status"
        kabari "Digidaw belum mati sepenuhnya."
        return 1
    fi
}

mulai_ulang() {
    if [[ -z "$(digidaw_pids)" ]]; then
        hidupkan
        return
    fi
    echo -e "\n${BOLD}🔁 Memulai ulang Digidaw${RESET}\n"
    local dari=0
    [[ -f "$LOG_FILE" ]] && dari=$(wc -l < "$LOG_FILE")
    systemctl --user restart "$UNIT"
    if tunggu 40 bash -c "tail -n +$((dari + 1)) '$LOG_FILE' 2>/dev/null | grep -qE '$READY_PATTERN'"; then
        success "Digidaw siap dipanggil"
    else
        warn "Digidaw belum siap. Lihat: $LOG_FILE"
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
    elif [[ -f "$STATE_FILE" ]]; then
        baris "Digidaw" "${RED}○ mati total${RESET} (hidup lagi kalau skrip ini dijalankan)"
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

atur_autostart() {
    case "${1:-}" in
        on|aktif|hidup)  set_autostart true  && success "Digidaw hidup otomatis saat login" ;;
        off|mati)        set_autostart false && success "Digidaw tidak hidup otomatis saat login" ;;
        *)               bantuan; return 1 ;;
    esac
}

# ─── Menu & argumen ─────────────────────────────────────────
bantuan() {
    echo "Pemakaian: $(basename "$0") [hidup|mati|restart|status|autostart on|autostart off]"
    echo "Tanpa argumen: kalau mati langsung dihidupkan, kalau hidup muncul pilihan."
}

menu_saat_hidup() {
    local pilih auto_label="⏻ Hidup otomatis saat login: tidak (aktifkan)"
    autostart_aktif && auto_label="⏻ Hidup otomatis saat login: ya (matikan)"
    if ! di_terminal; then
        status
        kabari "Digidaw sedang hidup. Jalankan dari terminal untuk mematikannya, atau: digidaw.sh mati"
        return 0
    fi
    if cek_cmd fzf; then
        pilih=$(printf '%s\n' "🔴 Matikan total" "🔁 Mulai ulang" "📊 Status" "$auto_label" |
                fzf --height=40% --reverse --prompt="Digidaw > " --header="Digidaw sedang hidup. Pilih aksi")
    else
        select pilih in "🔴 Matikan total" "🔁 Mulai ulang" "📊 Status" "$auto_label"; do break; done
    fi
    case "$pilih" in
        "🔴 Matikan total")  matikan ;;
        "🔁 Mulai ulang")    mulai_ulang ;;
        "📊 Status")         status ;;
        "$auto_label")       if autostart_aktif; then atur_autostart off; else atur_autostart on; fi ;;
        *) exit 0 ;;
    esac
}

case "${1:-}" in
    hidup|on|start|nyala|nyalakan)
        hidupkan
        if [[ " $* " == *" --permanen "* ]]; then
            set_autostart true && success "Hidup otomatis saat login: aktif"
        fi
        ;;
    mati|off|stop|matikan)          matikan ;;
    restart|ulang|mulai-ulang)      mulai_ulang ;;
    status|cek)                     status ;;
    autostart)                      atur_autostart "${2:-}" ;;
    -h|--help|help)                 bantuan ;;
    "")
        if [[ -n "$(digidaw_pids)" ]]; then menu_saat_hidup; else hidupkan; fi
        ;;
    *)                              bantuan; exit 1 ;;
esac
