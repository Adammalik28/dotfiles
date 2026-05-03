#!/bin/bash
# ╔════════════════════════════════════════╗
# ║         atur.sh — Script Launcher      ║
# ║         by Adam | Hyprland Setup       ║
# ╚════════════════════════════════════════╝

SCRIPTS_DIR="$HOME/myskrip"
HISTORY_FILE="$HOME/.atur_history"
LOG_FILE="$HOME/.atur_log"
MAX_HISTORY=20

# ─── Warna ───────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ─── Cek dependensi ──────────────────────
check_deps() {
    local missing=()
    for cmd in fzf bat notify-send; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${YELLOW}Dependensi tidak ditemukan:${RESET} ${missing[*]}"
        echo -e "Install dengan: ${CYAN}sudo pacman -S ${missing[*]}${RESET}"
        echo ""
        if [[ " ${missing[*]} " == *" fzf "* ]]; then
            exit 1
        fi
    fi
}

# ─── Preview command ─────────────────────
get_preview_cmd() {
    if command -v bat &> /dev/null; then
        echo "bat --color=always --style=numbers,header $SCRIPTS_DIR/{}"
    else
        echo "cat $SCRIPTS_DIR/{}"
    fi
}

# ─── Baca & tulis history ─────────────────
get_sorted_scripts() {
    local recent=""
    [ -f "$HISTORY_FILE" ] && recent=$(tac "$HISTORY_FILE" 2>/dev/null | awk '!seen[$0]++' | head -n "$MAX_HISTORY")
    local all
    all=$(ls "$SCRIPTS_DIR" | grep "\.sh$")
    echo -e "$recent\n$all" | awk 'NF && !seen[$0]++'
}

save_history() {
    local script="$1"
    echo "$script" >> "$HISTORY_FILE"
    local tmp
    tmp=$(tail -n "$MAX_HISTORY" "$HISTORY_FILE")
    echo "$tmp" > "$HISTORY_FILE"
}

# ─── Logging ─────────────────────────────
write_log() {
    local script="$1"
    local exit_code="$2"
    local duration="$3"
    local status="OK"
    [ "$exit_code" -ne 0 ] && status="ERR($exit_code)"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$status] $script (${duration}s)" >> "$LOG_FILE"
}

# ─── Notifikasi desktop ───────────────────
send_notif() {
    local script="$1"
    local exit_code="$2"
    local duration="$3"
    if command -v notify-send &> /dev/null; then
        if [ "$exit_code" -eq 0 ]; then
            notify-send -i "dialog-ok" "Skrip Selesai" "$script selesai dalam ${duration}s" -t 4000
        else
            notify-send -i "dialog-error" "Skrip Error" "$script gagal (exit: $exit_code)" -t 6000
        fi
    fi
}

# ─── Konfirmasi eksekusi ──────────────────
confirm_run() {
    local script="$1"
    echo -e "${YELLOW}Akan menjalankan:${RESET} ${BOLD}$script${RESET}"
    read -rp "   Lanjutkan? [Y/n] " confirm
    confirm="${confirm:-Y}"
    [[ "$confirm" =~ ^[Yy]$ ]]
}

# ─── Tampilkan log terakhir ───────────────
show_recent_log() {
    if [ -f "$LOG_FILE" ]; then
        echo -e "\n${CYAN}${BOLD}Riwayat Eksekusi Terakhir:${RESET}"
        tail -n 5 "$LOG_FILE" | while IFS= read -r line; do
            if [[ "$line" == *"[OK]"* ]]; then
                echo -e "  ${GREEN}$line${RESET}"
            else
                echo -e "  ${RED}$line${RESET}"
            fi
        done
        echo ""
    fi
}

# ════════════════════════════════════════════
#  MAIN
# ════════════════════════════════════════════

check_deps
show_recent_log

PREVIEW_CMD=$(get_preview_cmd)
SCRIPTS_LIST=$(get_sorted_scripts)

selected_script=$(echo "$SCRIPTS_LIST" | fzf \
    --height 60% \
    --layout=reverse \
    --border=rounded \
    --prompt="Pilih Skrip: " \
    --pointer=">" \
    --info=inline \
    --header=" Enter=jalankan | Ctrl-C=batal" \
    --preview "$PREVIEW_CMD" \
    --preview-window=right:55%:wrap \
    --color="header:italic,border:#7aa2f7,prompt:#7dcfff,pointer:#f7768e")

if [ -z "$selected_script" ]; then
    echo -e "${YELLOW}Dibatalkan.${RESET}"
    sleep 1
    exit 0
fi

# Konfirmasi
if ! confirm_run "$selected_script"; then
    echo -e "${YELLOW}Dibatalkan.${RESET}"
    sleep 1
    exit 0
fi

# Jalankan skrip & hitung durasi
echo -e "\n${CYAN}Executing:${RESET} ${BOLD}$selected_script${RESET}\n"
echo "─────────────────────────────────────────"

START_TIME=$(date +%s)
bash "$SCRIPTS_DIR/$selected_script"
EXIT_CODE=$?
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo "─────────────────────────────────────────"

# Simpan history & log
save_history "$selected_script"
write_log "$selected_script" "$EXIT_CODE" "$DURATION"
send_notif "$selected_script" "$EXIT_CODE" "$DURATION"

# Tampilkan hasil
echo ""
if [ "$EXIT_CODE" -eq 0 ]; then
    echo -e "${GREEN}${BOLD}Selesai${RESET} — ${selected_script} (${DURATION}s)"
else
    echo -e "${RED}${BOLD}Error${RESET} — exit code: ${EXIT_CODE} (${DURATION}s)"
fi

echo ""
read -rp "Tekan Enter untuk keluar..."
