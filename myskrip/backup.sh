#!/bin/bash
# backup.sh — Backup otomatis folder penting + myskrip dengan rsync
# Oleh: myskrip collection

# ══════════════════════════════════════════
#  KONFIGURASI — sesuaikan di sini
# ══════════════════════════════════════════
BACKUP_DEST="${BACKUP_DEST:-$HOME/Backup}"   # Ganti ke /run/media/adam/NamaUSB jika mau ke USB
LOG_DIR="$HOME/.local/log/backup"
LOG_FILE="$LOG_DIR/backup_$(date +%Y-%m-%d).log"
NOTIF_TIMEOUT=5000

# Daftar folder yang akan di-backup
SUMBER=(
    "$HOME/myskrip"
    "$HOME/.config/hypr"
    "$HOME/.config/kitty"
    "$HOME/.config/waybar"
    "$HOME/.config/rofi"
    "$HOME/.config/nvim"
    "$HOME/.zshrc"
    "$HOME/.bashrc"
    "$HOME/Dokumen"
    "$HOME/Proyek"
)

# ══════════════════════════════════════════
#  FUNGSI UTAMA
# ══════════════════════════════════════════

notif() {
    notify-send -t "$NOTIF_TIMEOUT" "💾 Backup" "$1"
}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

setup() {
    mkdir -p "$LOG_DIR"
    mkdir -p "$BACKUP_DEST"
}

cek_dest() {
    if [ ! -d "$BACKUP_DEST" ]; then
        notif "❌ Tujuan backup tidak ditemukan: $BACKUP_DEST"
        log "ERROR: Direktori tujuan tidak ada: $BACKUP_DEST"
        exit 1
    fi
    # Cek ruang kosong (minimal 500MB)
    local free_mb
    free_mb=$(df -m "$BACKUP_DEST" | awk 'NR==2{print $4}')
    if [ "$free_mb" -lt 500 ]; then
        notif "⚠️ Ruang disk hampir penuh! Sisa: ${free_mb}MB"
        log "PERINGATAN: Ruang disk sisa ${free_mb}MB"
    fi
}

backup_item() {
    local src="$1"
    local nama
    nama=$(basename "$src")

    if [ ! -e "$src" ]; then
        log "SKIP: $src tidak ditemukan, dilewati."
        return
    fi

    log "Backup: $src → $BACKUP_DEST/"

    rsync -avh \
        --delete \
        --exclude='*.pyc' \
        --exclude='__pycache__/' \
        --exclude='node_modules/' \
        --exclude='.git/' \
        --exclude='*.tmp' \
        --exclude='*.log' \
        "$src" "$BACKUP_DEST/" \
        >> "$LOG_FILE" 2>&1

    if [ $? -eq 0 ]; then
        log "✅ Berhasil: $nama"
    else
        log "❌ Gagal: $nama"
    fi
}

backup_semua() {
    setup
    cek_dest

    log "════════════════════════════════════════"
    log "Mulai backup ke: $BACKUP_DEST"
    log "════════════════════════════════════════"
    notif "🔄 Backup dimulai..."

    local sukses=0
    local gagal=0
    local skip=0

    for item in "${SUMBER[@]}"; do
        if [ -e "$item" ]; then
            backup_item "$item"
            ((sukses++))
        else
            log "SKIP: $item tidak ada"
            ((skip++))
        fi
    done

    local total_size
    total_size=$(du -sh "$BACKUP_DEST" 2>/dev/null | awk '{print $1}')

    log "════════════════════════════════════════"
    log "Backup selesai. Sukses: $sukses | Skip: $skip | Total size: $total_size"
    log "════════════════════════════════════════"

    notif "✅ Backup selesai!\nSukses: $sukses | Skip: $skip\nTotal: $total_size"
}

backup_pilih() {
    # Pilih item dari daftar via fzf
    local pilihan
    pilihan=$(printf '%s\n' "${SUMBER[@]}" \
        | fzf --multi \
              --prompt="Pilih folder/file > " \
              --height=60% \
              --border=rounded \
              --header="TAB=multi-pilih | Enter=backup | Ctrl-C=batal" \
              --color=bg+:#1e1e2e,fg+:#cdd6f4,hl+:#89b4fa,border:#313244,header:#a6e3a1)

    [ -z "$pilihan" ] && exit 0

    setup
    cek_dest
    log "Backup selektif dimulai"

    while IFS= read -r item; do
        backup_item "$item"
    done <<< "$pilihan"

    notif "✅ Backup selektif selesai!"
    log "Backup selektif selesai"
}

lihat_log() {
    if [ -f "$LOG_FILE" ]; then
        less "$LOG_FILE"
    else
        ls "$LOG_DIR"/*.log 2>/dev/null \
            | fzf --prompt="Pilih log > " \
                  --height=40% \
                  --border=rounded \
                  --color=bg+:#1e1e2e,fg+:#cdd6f4,border:#313244 \
            | xargs -r less
    fi
}

ganti_dest() {
    echo "Tujuan backup saat ini: $BACKUP_DEST"
    echo ""
    echo "Mount point tersedia:"
    lsblk -rpo "NAME,SIZE,MOUNTPOINT,LABEL" \
        | awk '$3 != "" && $3 != "/" && $3 !~ /^\/boot/ {print $3, "["$2"]", $4}'
    echo ""
    read -rp "Masukkan path tujuan baru (Enter untuk batal): " dest_baru
    if [ -n "$dest_baru" ]; then
        export BACKUP_DEST="$dest_baru"
        echo "Tujuan diubah ke: $BACKUP_DEST"
        backup_semua
    fi
}

# ══════════════════════════════════════════
#  ENTRY POINT
# ══════════════════════════════════════════
case "$1" in
    -a|--all)       backup_semua ;;
    -p|--pilih)     backup_pilih ;;
    -l|--log)       lihat_log ;;
    -d|--dest)      ganti_dest ;;
    -h|--help)
        echo "Penggunaan: backup.sh [OPSI]"
        echo "  (tanpa opsi)     Menu interaktif"
        echo "  -a, --all        Backup semua item dalam daftar"
        echo "  -p, --pilih      Pilih item yang mau di-backup"
        echo "  -l, --log        Lihat log backup"
        echo "  -d, --dest       Ganti tujuan backup (contoh: USB)"
        echo ""
        echo "Variabel lingkungan:"
        echo "  BACKUP_DEST      Override tujuan backup"
        echo "  Contoh: BACKUP_DEST=/run/media/adam/USB ./backup.sh -a"
        ;;
    *)
        # Menu interaktif
        pilihan=$(printf "🔄  Backup semua\n✅  Backup pilihan\n📋  Lihat log\n💾  Ganti tujuan backup" \
            | fzf --prompt="Backup Manager > " \
                  --height=40% \
                  --border=rounded \
                  --color=bg+:#1e1e2e,fg+:#cdd6f4,hl+:#89b4fa,border:#313244 \
            | awk -F'  ' '{print $2}')
        case "$pilihan" in
            "Backup semua")         backup_semua ;;
            "Backup pilihan")       backup_pilih ;;
            "Lihat log")            lihat_log ;;
            "Ganti tujuan backup")  ganti_dest ;;
        esac
        ;;
esac
