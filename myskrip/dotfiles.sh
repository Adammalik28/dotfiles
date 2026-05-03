#!/bin/bash
# dotfiles.sh — Sync, backup, dan restore dotfiles + myskrip ke Git
# Oleh: myskrip collection

# ══════════════════════════════════════════
#  KONFIGURASI — sesuaikan di sini
# ══════════════════════════════════════════
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
NOTIF_TIMEOUT=5000

# File/folder yang akan dikelola (sumber → nama di repo)
declare -A DOTFILES_MAP=(
    ["$HOME/.zshrc"]="zshrc"
    ["$HOME/.bashrc"]="bashrc"
    ["$HOME/.config/hypr"]="config/hypr"
    ["$HOME/.config/kitty"]="config/kitty"
    ["$HOME/.config/waybar"]="config/waybar"
    ["$HOME/.config/rofi"]="config/rofi"
    ["$HOME/.config/nvim"]="config/nvim"
    ["$HOME/.config/starship.toml"]="config/starship.toml"
    ["$HOME/myskrip"]="myskrip"
)

# ══════════════════════════════════════════
#  FUNGSI UTILITAS
# ══════════════════════════════════════════

notif() {
    notify-send -t "$NOTIF_TIMEOUT" "📁 Dotfiles" "$1"
}

warna_ok()   { echo -e "\033[32m✅ $1\033[0m"; }
warna_err()  { echo -e "\033[31m❌ $1\033[0m"; }
warna_info() { echo -e "\033[34mℹ  $1\033[0m"; }
warna_warn() { echo -e "\033[33m⚠️  $1\033[0m"; }

cek_git() {
    if ! command -v git &>/dev/null; then
        warna_err "git tidak terinstall. Install dengan: sudo pacman -S git"
        exit 1
    fi

    # Cek identitas git — wajib ada sebelum bisa commit
    local git_name git_email
    git_name=$(git config --global user.name 2>/dev/null)
    git_email=$(git config --global user.email 2>/dev/null)

    if [ -z "$git_name" ] || [ -z "$git_email" ]; then
        warna_err "Identitas Git belum di-set!"
        echo ""
        echo "Jalankan perintah berikut terlebih dahulu:"
        echo ""
        echo "  git config --global user.name  \"Nama Kamu\""
        echo "  git config --global user.email \"email@kamu.com\""
        echo ""
        exit 1
    fi
}

cek_repo() {
    if [ ! -d "$DOTFILES_DIR/.git" ]; then
        warna_err "Repo dotfiles tidak ditemukan di: $DOTFILES_DIR"
        warna_info "Jalankan './dotfiles.sh --init' untuk membuat repo baru"
        exit 1
    fi
}

# ══════════════════════════════════════════
#  FUNGSI UTAMA
# ══════════════════════════════════════════

init_repo() {
    cek_git
    echo ""
    warna_info "Inisialisasi repo dotfiles di: $DOTFILES_DIR"
    echo ""

    mkdir -p "$DOTFILES_DIR"
    cd "$DOTFILES_DIR" || exit 1

    if [ ! -d ".git" ]; then
        git init
        warna_ok "Git repo diinisialisasi"
    else
        warna_warn "Repo sudah ada, melanjutkan..."
    fi

    # Buat README
    cat > README.md << 'EOF'
# Dotfiles — adam@arch

Koleksi konfigurasi dan skrip Arch Linux + Hyprland.

## Restore

```bash
./dotfiles.sh --restore
```

## Skrip tersedia

Ada di folder `myskrip/` — lihat masing-masing file untuk dokumentasi.
EOF

    # Buat .gitignore
    cat > .gitignore << 'EOF'
*.log
*.tmp
.DS_Store
__pycache__/
*.pyc
node_modules/
.env
EOF

    git add .
    git commit -m "init: setup repo dotfiles" 2>/dev/null || true

    warna_ok "Repo siap di $DOTFILES_DIR"
    echo ""
    read -rp "Masukkan URL remote Git (kosongkan jika belum): " remote_url
    if [ -n "$remote_url" ]; then
        git remote add origin "$remote_url"
        warna_ok "Remote ditambahkan: $remote_url"
    fi
}

backup_dotfiles() {
    cek_git
    cek_repo
    cd "$DOTFILES_DIR" || exit 1

    warna_info "Menyalin dotfiles ke repo..."
    echo ""

    local ada_perubahan=0

    for src in "${!DOTFILES_MAP[@]}"; do
        local dest="${DOTFILES_MAP[$src]}"
        local dest_path="$DOTFILES_DIR/$dest"

        if [ ! -e "$src" ]; then
            warna_warn "Skip (tidak ada): $src"
            continue
        fi

        local dest_dir
        dest_dir=$(dirname "$dest_path")
        mkdir -p "$dest_dir"

        if [ -d "$src" ]; then
            rsync -ah --delete \
                --exclude='.git/' \
                --exclude='*.pyc' \
                --exclude='__pycache__/' \
                "$src/" "$dest_path/"
        else
            cp "$src" "$dest_path"
        fi

        warna_ok "Disalin: $(basename "$src")"
        ada_perubahan=1
    done

    echo ""

    if [ "$ada_perubahan" -eq 0 ]; then
        warna_warn "Tidak ada file yang disalin."
        return
    fi

    # Git commit
    git add -A

    local status
    status=$(git status --short)

    if [ -z "$status" ]; then
        warna_info "Tidak ada perubahan dari backup sebelumnya."
        return
    fi

    echo "Perubahan:"
    git status --short
    echo ""

    read -rp "Pesan commit (Enter = pakai otomatis): " commit_msg
    commit_msg="${commit_msg:-backup: $(date '+%Y-%m-%d %H:%M')}"

    if git commit -m "$commit_msg"; then
        warna_ok "Committed: $commit_msg"
        notif "✅ Dotfiles berhasil di-backup"
    else
        warna_err "Commit gagal! Cek pesan error di atas."
        return 1
    fi

    # Tanya push
    if git remote get-url origin &>/dev/null; then
        read -rp "Push ke remote? [y/N]: " push_confirm
        if [[ "$push_confirm" =~ ^[Yy]$ ]]; then
            git push origin "$(git branch --show-current)" && warna_ok "Pushed ke remote!"
        fi
    fi
}

restore_dotfiles() {
    cek_git
    cek_repo

    warna_warn "Ini akan MENIMPA file konfigurasi yang ada!"
    read -rp "Lanjutkan restore? [y/N]: " konfirmasi
    [[ ! "$konfirmasi" =~ ^[Yy]$ ]] && { echo "Dibatalkan."; exit 0; }

    warna_info "Memulai restore dari: $DOTFILES_DIR"
    echo ""

    for src in "${!DOTFILES_MAP[@]}"; do
        local dest="${DOTFILES_MAP[$src]}"
        local src_in_repo="$DOTFILES_DIR/$dest"

        if [ ! -e "$src_in_repo" ]; then
            warna_warn "Skip (tidak ada di repo): $dest"
            continue
        fi

        # Backup dulu yang lama
        if [ -e "$src" ]; then
            mv "$src" "${src}.bak.$(date +%s)"
            warna_warn "Backup lama → ${src}.bak.*"
        fi

        local src_dir
        src_dir=$(dirname "$src")
        mkdir -p "$src_dir"

        if [ -d "$src_in_repo" ]; then
            rsync -ah "$src_in_repo/" "$src/"
        else
            cp "$src_in_repo" "$src"
        fi

        warna_ok "Restored: $src"
    done

    echo ""
    notif "✅ Dotfiles berhasil di-restore!"
    warna_ok "Restore selesai. File lama ada di *.bak.*"
}

lihat_status() {
    cek_git
    cek_repo
    cd "$DOTFILES_DIR" || exit 1

    echo ""
    warna_info "=== Status Repo Dotfiles ==="
    echo "Lokasi: $DOTFILES_DIR"
    echo "Branch: $(git branch --show-current 2>/dev/null)"
    echo ""

    if git remote get-url origin &>/dev/null; then
        echo "Remote: $(git remote get-url origin)"
    else
        echo "Remote: (belum ada)"
    fi

    echo ""
    git log --oneline -10 2>/dev/null || echo "(Belum ada commit)"
    echo ""
    git status --short 2>/dev/null
}

push_remote() {
    cek_git
    cek_repo
    cd "$DOTFILES_DIR" || exit 1

    if ! git remote get-url origin &>/dev/null; then
        warna_err "Belum ada remote. Set dulu:"
        echo "  cd $DOTFILES_DIR && git remote add origin <URL>"
        exit 1
    fi

    warna_info "Push ke remote..."
    git push origin "$(git branch --show-current)" \
        && warna_ok "Push berhasil!" \
        && notif "✅ Dotfiles berhasil di-push ke remote"
}

pull_remote() {
    cek_git
    cek_repo
    cd "$DOTFILES_DIR" || exit 1

    warna_info "Pull dari remote..."
    git pull origin "$(git branch --show-current)" \
        && warna_ok "Pull berhasil!"
}

# ══════════════════════════════════════════
#  ENTRY POINT
# ══════════════════════════════════════════
case "$1" in
    --init)    init_repo ;;
    --backup|-b)  backup_dotfiles ;;
    --restore|-r) restore_dotfiles ;;
    --status|-s)  lihat_status ;;
    --push)    push_remote ;;
    --pull)    pull_remote ;;
    --help|-h)
        echo "Penggunaan: dotfiles.sh [OPSI]"
        echo ""
        echo "  --init          Inisialisasi repo dotfiles baru"
        echo "  -b, --backup    Salin dotfiles ke repo dan commit"
        echo "  -r, --restore   Restore dotfiles dari repo"
        echo "  -s, --status    Lihat status repo dan log"
        echo "  --push          Push ke remote Git"
        echo "  --pull          Pull dari remote Git"
        echo ""
        echo "Variabel lingkungan:"
        echo "  DOTFILES_DIR    Override lokasi repo (default: ~/dotfiles)"
        ;;
    *)
        # Menu interaktif
        pilihan=$(printf "📦  Backup dotfiles ke repo\n🔄  Restore dari repo\n📊  Lihat status & log\n☁️  Push ke remote\n⬇️  Pull dari remote\n🚀  Init repo baru" \
            | fzf --prompt="Dotfiles Manager > " \
                  --height=50% \
                  --border=rounded \
                  --color=bg+:#1e1e2e,fg+:#cdd6f4,hl+:#89b4fa,border:#313244 \
            | awk -F'  ' '{print $2}')
        case "$pilihan" in
            "Backup dotfiles ke repo") backup_dotfiles ;;
            "Restore dari repo")       restore_dotfiles ;;
            "Lihat status & log")      lihat_status ;;
            "Push ke remote")          push_remote ;;
            "Pull dari remote")        pull_remote ;;
            "Init repo baru")          init_repo ;;
        esac
        ;;
esac
