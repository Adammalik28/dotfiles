#!/bin/bash
# ╔════════════════════════════════════════╗
# ║         atur.sh — Script Launcher      ║
# ║         by Adam | Hyprland Setup       ║
# ╚════════════════════════════════════════╝

SCRIPTS_DIR="$HOME/myskrip"
HISTORY_FILE="$HOME/.atur_history"
LOG_FILE="$HOME/.atur_log"
MAX_HISTORY=20
MAX_LOG_LINES=200   # Batas maksimal baris log sebelum dipangkas

export SCRIPTS_DIR

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
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done

    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${YELLOW}Dependensi tidak ditemukan:${RESET} ${missing[*]}"
        echo -e "Install dengan: ${CYAN}sudo pacman -S ${missing[*]}${RESET}"
        echo ""
        # fzf wajib ada, yang lain opsional
        if [[ " ${missing[*]} " == *" fzf "* ]]; then
            exit 1
        fi
    fi
}

# ─── Validasi direktori script ───────────
check_scripts_dir() {
    if [ ! -d "$SCRIPTS_DIR" ]; then
        echo -e "${RED}✖ Direktori script tidak ditemukan: ${BOLD}$SCRIPTS_DIR${RESET}"
        echo -e "  Buat dengan: ${CYAN}mkdir -p $SCRIPTS_DIR${RESET}"
        exit 1
    fi

    # Cek apakah ada minimal 1 file .sh
    local count
    count=$(find "$SCRIPTS_DIR" -maxdepth 1 -name "*.sh" 2>/dev/null | wc -l)
    if [ "$count" -eq 0 ]; then
        echo -e "${YELLOW}⚠ Tidak ada file .sh di $SCRIPTS_DIR${RESET}"
        exit 0
    fi
}

# ─── Preview command ─────────────────────
# Catatan: pakai variabel environment ($SCRIPTS_DIR sudah di-export di atas)
# bukan string interpolation, supaya path dengan spasi/karakter aneh tetap
# aman terlepas dari versi fzf yang dipakai.
get_preview_cmd() {
    # PENTING: {} TIDAK boleh dibungkus kutip tambahan di sini.
    # fzf versi modern sudah otomatis membungkus hasil substitusi {}
    # dengan kutip sendiri (mis. jadi 'nama file.sh'). Kalau kita bungkus
    # lagi dengan "...{}...", hasilnya kutip ganda yang bentrok dan bikin
    # path jadi rusak (contoh: /home/adam/myskrip/'cekjadwal.sh').
    # Cukup kutip $SCRIPTS_DIR saja, shell akan menggabungkan otomatis
    # ("$SCRIPTS_DIR"/{} -> "/path/ke/dir"/'file.sh' -> valid).
    if command -v bat &>/dev/null; then
        echo 'bat --color=always --style=numbers,header -- "$SCRIPTS_DIR"/{}'
    else
        echo 'cat -- "$SCRIPTS_DIR"/{}'
    fi
}

# ─── Baca & tulis history ─────────────────
get_sorted_scripts() {
    local recent=""

    if [ -f "$HISTORY_FILE" ]; then
        # Ambil history terbalik (terbaru dulu), deduplikasi,
        # lalu FILTER: hanya tampilkan yang filenya masih ada di SCRIPTS_DIR dan bukan internal
        recent=$(
            tac "$HISTORY_FILE" 2>/dev/null \
            | awk '!seen[$0]++' \
            | head -n "$MAX_HISTORY" \
            | while IFS= read -r s; do
                [ -f "$SCRIPTS_DIR/$s" ] && [[ "$s" != "atur.sh" && "$s" != "lib.sh" ]] && echo "$s"
              done
        )
    fi

    # Semua file .sh yang runnable di SCRIPTS_DIR, sorted abjad (exclude atur.sh dan lib.sh)
    local all
    all=$(find "$SCRIPTS_DIR" -maxdepth 1 -name "*.sh" ! -name "atur.sh" ! -name "lib.sh" -printf "%f\n" 2>/dev/null | sort)

    # Gabung: recent di atas (prioritas), semua di bawah, deduplikasi
    { echo "$recent"; echo "$all"; } | awk 'NF && !seen[$0]++'
}

save_history() {
    local script="$1"

    # Append dulu
    echo "$script" >> "$HISTORY_FILE"

    # Truncate dengan tmpfile agar atomic — tidak ada resiko file kosong jika proses terganggu
    local tmp
    tmp=$(mktemp) || return
    tail -n "$MAX_HISTORY" "$HISTORY_FILE" > "$tmp" && mv "$tmp" "$HISTORY_FILE"
}

# ─── Logging ─────────────────────────────
write_log() {
    local script="$1"
    local exit_code="$2"
    local duration="$3"
    local status="OK"
    [ "$exit_code" -ne 0 ] && status="ERR($exit_code)"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$status] $script (${duration}s)" >> "$LOG_FILE"

    # Rotasi log: pangkas ke MAX_LOG_LINES baris terakhir secara atomic,
    # supaya file log tidak tumbuh tanpa batas selamanya.
    local tmp
    tmp=$(mktemp) || return
    tail -n "$MAX_LOG_LINES" "$LOG_FILE" > "$tmp" && mv "$tmp" "$LOG_FILE"
}

# ─── Notifikasi desktop ───────────────────
send_notif() {
    local script="$1"
    local exit_code="$2"
    local duration="$3"
    command -v notify-send &>/dev/null || return

    if [ "$exit_code" -eq 0 ]; then
        notify-send -i "dialog-ok"    "Skrip Selesai" "$script selesai dalam ${duration}s" -t 4000
    else
        notify-send -i "dialog-error" "Skrip Error"   "$script gagal (exit: $exit_code)"   -t 6000
    fi
}

# ─── Konfirmasi eksekusi ──────────────────
confirm_run() {
    local script="$1"
    echo -e "${YELLOW}Akan menjalankan:${RESET} ${BOLD}$script${RESET}"

    # Jika terminal non-interactive (piped), langsung tolak — jangan auto-run
    if [ ! -t 0 ]; then
        echo -e "${RED}✖ Terminal non-interactive, eksekusi dibatalkan.${RESET}"
        return 1
    fi

    read -rp "   Lanjutkan? [Y/n] " confirm
    confirm="${confirm:-Y}"
    [[ "$confirm" =~ ^[Yy]$ ]]
}

# ─── Jalankan script dengan cara yang tepat ──
run_script() {
    local script_path="$1"

    # Jika file executable dan punya shebang, jalankan langsung
    # agar Python/Perl/script lain bekerja dengan interpreter yang benar
    if [ -x "$script_path" ]; then
        "$script_path"
    else
        # Fallback: jalankan dengan bash
        bash "$script_path"
    fi
}

# ─── Tampilkan log terakhir ───────────────
show_recent_log() {
    [ -f "$LOG_FILE" ] || return

    echo -e "\n${CYAN}${BOLD}Riwayat Eksekusi Terakhir:${RESET}"
    tail -n 5 "$LOG_FILE" | while IFS= read -r line; do
        if [[ "$line" == *"[OK]"* ]]; then
            echo -e "  ${GREEN}$line${RESET}"
        else
            echo -e "  ${RED}$line${RESET}"
        fi
    done
    echo ""
}

# ─── Info script yang dipilih ────────────
show_script_info() {
    local script="$1"
    local script_path="$SCRIPTS_DIR/$script"

    # Ambil baris komentar pertama setelah shebang sebagai deskripsi singkat.
    # Skip juga baris yang hanya berisi karakter dekorasi banner
    # (═ ─ ╔ ╗ ╚ ╝ ║ dll) supaya tidak salah ambil dari header ASCII-art.
    local desc
    desc=$(grep -m1 -E "^#[^!═─━┌┐└┘├┤┬┴┼║╔╗╚╝╠╣╦╩╬╭╮╯╰]" "$script_path" 2>/dev/null | sed 's/^#\s*//')

    local size
    size=$(du -h "$script_path" 2>/dev/null | cut -f1)

    local modified
    modified=$(date -r "$script_path" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "N/A")

    local exec_label
    [ -x "$script_path" ] && exec_label="${GREEN}executable${RESET}" || exec_label="${YELLOW}non-executable${RESET}"

    echo -e "  ${CYAN}File     :${RESET} $script ($size)"
    echo -e "  ${CYAN}Modified :${RESET} $modified"
    echo -e "  ${CYAN}Mode     :${RESET} $exec_label"
    [ -n "$desc" ] && echo -e "  ${CYAN}Info     :${RESET} $desc"
    echo ""
}

# ════════════════════════════════════════════
#  MAIN
# ════════════════════════════════════════════

check_deps
check_scripts_dir
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

# Validasi file masih ada (bisa saja dihapus saat fzf terbuka)
SCRIPT_PATH="$SCRIPTS_DIR/$selected_script"
if [ ! -f "$SCRIPT_PATH" ]; then
    echo -e "${RED}✖ File tidak ditemukan: $SCRIPT_PATH${RESET}"
    exit 1
fi

# Tampilkan info singkat script
show_script_info "$selected_script"

# Konfirmasi
if ! confirm_run "$selected_script"; then
    echo -e "${YELLOW}Dibatalkan.${RESET}"
    sleep 1
    exit 0
fi

# Jalankan script & ukur durasi pakai SECONDS builtin (lebih akurat dari date +%s)
echo -e "\n${CYAN}Executing:${RESET} ${BOLD}$selected_script${RESET}\n"
echo "─────────────────────────────────────────"

SECONDS=0
run_script "$SCRIPT_PATH"
EXIT_CODE=$?
DURATION=$SECONDS

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