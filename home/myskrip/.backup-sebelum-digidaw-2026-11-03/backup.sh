#!/usr/bin/env bash
#
# backup.sh — Automated backup of important folders + myskrip via rsync
#
# Usage:
#   ./backup.sh [OPTION]
#
# Run with -h/--help for full usage.
#
set -euo pipefail
IFS=$'\n\t'

# ══════════════════════════════════════════
#  CONFIGURATION — edit here
# ══════════════════════════════════════════
readonly SCRIPT_NAME="${0##*/}"
readonly VERSION="2.0.0"

BACKUP_DEST="${BACKUP_DEST:-$HOME/Backup}"   # Override e.g. BACKUP_DEST=/run/media/adam/USB
readonly LOG_DIR="$HOME/.local/log/backup"
LOG_FILE_NAME="backup_$(date +%Y-%m-%d).log"
readonly LOG_FILE="$LOG_DIR/$LOG_FILE_NAME"
readonly LOCK_FILE="$LOG_DIR/backup.lock"
readonly NOTIF_TIMEOUT=5000
readonly MIN_FREE_MB=500

# Folders/files to back up
readonly SUMBER=(
    "$HOME/myskrip"
    "$HOME/.config/hypr"
    "$HOME/.config/kitty"
    "$HOME/.config/waybar"
    "$HOME/.config/rofi"
    "$HOME/.config/nvim"
    "$HOME/.config/swaync"
    "$HOME/.zshrc"
    "$HOME/.bashrc"
    "$HOME/Documents"
    "$HOME/Projects"
    "$HOME/catat.txt"
    "$HOME/data"
)

readonly RSYNC_EXCLUDES=(
    --exclude='*.pyc'
    --exclude='__pycache__/'
    --exclude='node_modules/'
    --exclude='.git/'
    --exclude='*.tmp'
    --exclude='*.log'
)

DRY_RUN=0

# ══════════════════════════════════════════
#  LOGGING & NOTIFICATIONS
# ══════════════════════════════════════════

log() {
    # log LEVEL "message"
    local level="$1"; shift
    printf '[%s] [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$*" | tee -a "$LOG_FILE"
}

notif() {
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -t "$NOTIF_TIMEOUT" "💾 Backup" "$1"
    fi
}

die() {
    log "ERROR" "$1"
    notif "❌ $1"
    exit "${2:-1}"
}

# ══════════════════════════════════════════
#  PRE-FLIGHT CHECKS
# ══════════════════════════════════════════

cek_dependensi() {
    local missing=()
    for cmd in rsync df du date; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done
    if [ "${#missing[@]}" -gt 0 ]; then
        die "Perintah wajib tidak ditemukan: ${missing[*]}"
    fi
    # fzf is only required for interactive menus, checked lazily where used.
}

cek_fzf() {
    command -v fzf >/dev/null 2>&1 || die "Fitur ini butuh 'fzf', tapi belum terpasang."
}

ensure_log_dir() {
    mkdir -p "$LOG_DIR"
}

setup() {
    mkdir -p "$BACKUP_DEST"
}

ambil_lock() {
    exec 200>"$LOCK_FILE"
    if ! flock -n 200; then
        die "Proses backup lain sedang berjalan (lock: $LOCK_FILE)."
    fi
}

cek_dest() {
    if [ ! -d "$BACKUP_DEST" ]; then
        die "Direktori tujuan tidak ada: $BACKUP_DEST"
    fi
    local free_mb
    free_mb=$(df -m "$BACKUP_DEST" | awk 'NR==2{print $4}')
    if [ "$free_mb" -lt "$MIN_FREE_MB" ]; then
        log "WARN" "Ruang disk sisa hanya ${free_mb}MB (batas: ${MIN_FREE_MB}MB)"
        notif "⚠️ Ruang disk hampir penuh! Sisa: ${free_mb}MB"
    fi
}

# ══════════════════════════════════════════
#  CORE BACKUP LOGIC
# ══════════════════════════════════════════

# Returns 0 on success, 1 on failure, 2 on skip (source missing).
backup_item() {
    local src="$1" nama
    nama=$(basename -- "$src")

    if [ ! -e "$src" ]; then
        log "SKIP" "$src tidak ditemukan, dilewati."
        return 2
    fi

    log "INFO" "Backup: $src -> $BACKUP_DEST/"

    local rsync_opts=(-avh --delete "${RSYNC_EXCLUDES[@]}")
    [ "$DRY_RUN" -eq 1 ] && rsync_opts+=(--dry-run)

    if rsync "${rsync_opts[@]}" -- "$src" "$BACKUP_DEST/" >> "$LOG_FILE" 2>&1; then
        log "OK" "Berhasil: $nama"
        return 0
    else
        log "FAIL" "Gagal: $nama (lihat $LOG_FILE untuk detail)"
        return 1
    fi
}

jalankan_backup() {
    # jalankan_backup ITEM...
    setup
    ambil_lock
    cek_dest

    log "INFO" "════════════════════════════════════════"
    log "INFO" "Mulai backup ke: $BACKUP_DEST$( [ "$DRY_RUN" -eq 1 ] && echo ' (DRY RUN)' )"
    log "INFO" "════════════════════════════════════════"
    notif "🔄 Backup dimulai..."

    local sukses=0 gagal=0 skip=0 status

    for item in "$@"; do
        set +e
        backup_item "$item"
        status=$?
        set -e
        case "$status" in
            0) sukses=$((sukses + 1)) ;;
            1) gagal=$((gagal + 1)) ;;
            2) skip=$((skip + 1)) ;;
        esac
    done

    local total_size
    total_size=$(du -sh "$BACKUP_DEST" 2>/dev/null | awk '{print $1}')

    log "INFO" "════════════════════════════════════════"
    log "INFO" "Backup selesai. Sukses: $sukses | Gagal: $gagal | Skip: $skip | Total size: $total_size"
    log "INFO" "════════════════════════════════════════"

    if [ "$gagal" -gt 0 ]; then
        notif "⚠️ Backup selesai dengan error!
Sukses: $sukses | Gagal: $gagal | Skip: $skip"
        exit 1
    else
        notif "✅ Backup selesai!
Sukses: $sukses | Skip: $skip
Total: $total_size"
    fi
}

backup_semua() {
    jalankan_backup "${SUMBER[@]}"
}

backup_pilih() {
    cek_fzf
    local pilihan
    pilihan=$(printf '%s\n' "${SUMBER[@]}" \
        | fzf --multi \
              --prompt="Pilih folder/file > " \
              --height=60% \
              --border=rounded \
              --header="TAB=multi-pilih | Enter=backup | Ctrl-C=batal" \
              --color=bg+:#1e1e2e,fg+:#cdd6f4,hl+:#89b4fa,border:#313244,header:#a6e3a1)

    [ -z "$pilihan" ] && exit 0

    mapfile -t items <<< "$pilihan"
    jalankan_backup "${items[@]}"
}

lihat_log() {
    if [ -f "$LOG_FILE" ]; then
        less "$LOG_FILE"
        return
    fi
    cek_fzf
    local pilihan
    pilihan=$(find "$LOG_DIR" -maxdepth 1 -name '*.log' -printf '%f\n' 2>/dev/null \
        | fzf --prompt="Pilih log > " \
              --height=40% \
              --border=rounded \
              --color=bg+:#1e1e2e,fg+:#cdd6f4,border:#313244)
    [ -n "$pilihan" ] && less "$LOG_DIR/$pilihan"
}

ganti_dest() {
    echo "Tujuan backup saat ini: $BACKUP_DEST"
    echo ""
    echo "Mount point tersedia:"
    lsblk -rpo "NAME,SIZE,MOUNTPOINT,LABEL" 2>/dev/null \
        | awk '$3 != "" && $3 != "/" && $3 !~ /^\/boot/ {print $3, "["$2"]", $4}'
    echo ""
    read -rp "Masukkan path tujuan baru (Enter untuk batal): " dest_baru
    if [ -n "$dest_baru" ]; then
        BACKUP_DEST="$dest_baru"
        echo "Tujuan diubah ke: $BACKUP_DEST"
        backup_semua
    fi
}

tampilkan_bantuan() {
    cat <<EOF
$SCRIPT_NAME v$VERSION — Backup otomatis dengan rsync

Penggunaan: $SCRIPT_NAME [OPSI]
  (tanpa opsi)      Menu interaktif
  -a, --all         Backup semua item dalam daftar
  -p, --pilih       Pilih item yang mau di-backup (butuh fzf)
  -l, --log         Lihat log backup (butuh fzf jika log hari ini tidak ada)
  -d, --dest        Ganti tujuan backup (contoh: USB)
  -n, --dry-run     Simulasikan backup tanpa menyalin/menghapus file apa pun
  -v, --version     Tampilkan versi
  -h, --help        Tampilkan bantuan ini

Variabel lingkungan:
  BACKUP_DEST       Override tujuan backup
                    Contoh: BACKUP_DEST=/run/media/adam/USB $SCRIPT_NAME -a

Kode keluar:
  0  Sukses (semua item berhasil atau dilewati)
  1  Ada item yang gagal, atau error konfigurasi
EOF
}

menu_interaktif() {
    cek_fzf
    local pilihan
    pilihan=$(printf '%s\n' \
        "🔄  Backup semua" \
        "✅  Backup pilihan" \
        "📋  Lihat log" \
        "💾  Ganti tujuan backup" \
        | fzf --prompt="Backup Manager > " \
              --height=40% \
              --border=rounded \
              --color=bg+:#1e1e2e,fg+:#cdd6f4,hl+:#89b4fa,border:#313244 \
        | sed -E 's/^[^ ]+  //')

    case "$pilihan" in
        "Backup semua")        backup_semua ;;
        "Backup pilihan")      backup_pilih ;;
        "Lihat log")           lihat_log ;;
        "Ganti tujuan backup") ganti_dest ;;
        "")                    exit 0 ;;
    esac
}

# ══════════════════════════════════════════
#  ENTRY POINT
# ══════════════════════════════════════════

main() {
    ensure_log_dir
    cek_dependensi

    local args=()
    for arg in "$@"; do
        case "$arg" in
            -n|--dry-run) DRY_RUN=1 ;;
            *) args+=("$arg") ;;
        esac
    done
    set -- "${args[@]}"

    case "${1:-}" in
        -a|--all)    backup_semua ;;
        -p|--pilih)  backup_pilih ;;
        -l|--log)    lihat_log ;;
        -d|--dest)   ganti_dest ;;
        -v|--version) echo "$SCRIPT_NAME v$VERSION" ;;
        -h|--help)   tampilkan_bantuan ;;
        "")          menu_interaktif ;;
        *)
            echo "Opsi tidak dikenal: $1" >&2
            tampilkan_bantuan
            exit 1
            ;;
    esac
}

main "$@"