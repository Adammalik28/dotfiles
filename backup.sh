#!/usr/bin/env bash
# backup.sh — Simpan kondisi Arch Linux saat ini ke repo dotfiles.
#
# Yang disimpan: daftar paket (pacman/AUR/BlackArch/flatpak/VS Code),
# config di $HOME, config sistem (/etc, tema GRUB & SDDM), service yang aktif,
# dan grup user. Setelah itu commit + push ke GitHub.
#
# Pemakaian:
#   ./backup.sh            backup + commit + push
#   ./backup.sh --no-push  backup + commit saja
#   ./backup.sh --no-git   backup saja (tanpa commit)

set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$REPO/lib.sh"
source "$REPO/dotfiles.conf"

DO_COMMIT=1 DO_PUSH=1
for arg in "$@"; do
    case "$arg" in
        --no-push) DO_PUSH=0 ;;
        --no-git)  DO_COMMIT=0; DO_PUSH=0 ;;
        -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
        *) err "Opsi tidak dikenal: $arg"; exit 1 ;;
    esac
done

mapfile -t EXCL < <(rsync_excludes)

# Salin satu item (file/folder) dari $1 ke $2, mirror isinya.
copy_item() {
    local src="$1" dst="$2"
    if [[ ! -e "$src" ]]; then
        warn "Lewati (tidak ada): $src"
        return
    fi
    mkdir -p "$(dirname "$dst")"
    if [[ -d "$src" && ! -L "$src" ]]; then
        rsync -a --delete "${EXCL[@]}" "$src/" "$dst/"
    else
        rsync -a "$src" "$dst"
    fi || warn "Gagal menyalin: $src"
}

# ── 1. Daftar paket ──────────────────────────────────────────────
step "Daftar paket"
mkdir -p "$REPO/packages"

blackarch_pkgs=""
if pacman -Sl blackarch &>/dev/null; then
    blackarch_pkgs=$(comm -12 <(pacman -Qqen | sort) <(pacman -Slq blackarch | sort))
fi
echo "$blackarch_pkgs" | grep -v '^$' > "$REPO/packages/blackarch.txt"
pacman -Qqen | grep -vxF -f <(echo "${blackarch_pkgs:-__none__}") > "$REPO/packages/pacman.txt"
pacman -Qqem | grep -vE "$AUR_IGNORE_REGEX" > "$REPO/packages/aur.txt"
ok "pacman: $(wc -l < "$REPO/packages/pacman.txt")  AUR: $(wc -l < "$REPO/packages/aur.txt")  BlackArch: $(wc -l < "$REPO/packages/blackarch.txt")"

if command -v flatpak &>/dev/null; then
    flatpak list --app --columns=application > "$REPO/packages/flatpak.txt"
    ok "flatpak: $(wc -l < "$REPO/packages/flatpak.txt")"
fi
if command -v code &>/dev/null; then
    code --list-extensions > "$REPO/packages/vscode.txt" 2>/dev/null
    ok "VS Code extensions: $(wc -l < "$REPO/packages/vscode.txt")"
fi

# ── 2. Service & grup ────────────────────────────────────────────
step "Service & grup"
mkdir -p "$REPO/services"
# Unit template (nama@) dilewati karena butuh instance spesifik.
systemctl list-unit-files --state=enabled --no-legend --no-pager \
    | awk '{print $1}' | grep -v '@' > "$REPO/services/system.txt"
systemctl --user list-unit-files --state=enabled --no-legend --no-pager \
    | awk '{print $1}' | grep -v '@' > "$REPO/services/user.txt"
command -v plymouth-set-default-theme &>/dev/null \
    && plymouth-set-default-theme > "$REPO/services/plymouth.txt"
echo "$HOME" > "$REPO/.source-home"
id -nG "$USER" | tr ' ' '\n' | grep -vx "$USER" > "$REPO/services/groups.txt"
ok "system: $(wc -l < "$REPO/services/system.txt")  user: $(wc -l < "$REPO/services/user.txt")  grup: $(paste -sd' ' "$REPO/services/groups.txt")"

# ── 3. Config $HOME ──────────────────────────────────────────────
step "Config \$HOME"
for item in "${HOME_ITEMS[@]}"; do
    copy_item "$HOME/$item" "$REPO/home/$item"
done
ok "$(du -sh "$REPO/home" | cut -f1) tersimpan di home/"

# ── 4. Config sistem ─────────────────────────────────────────────
step "Config sistem"
for item in "${SYSTEM_ITEMS[@]}"; do
    copy_item "$item" "$REPO/system$item"
done
for item in "${REFERENCE_ITEMS[@]}"; do
    copy_item "$item" "$REPO/reference$item"
done
ok "$(du -sh "$REPO/system" | cut -f1) tersimpan di system/"

# ── 5. Cek keamanan sederhana ────────────────────────────────────
step "Cek kebocoran rahasia"
leaks=$(grep -rIlE '(ghp_|gho_|github_pat_|sk-[A-Za-z0-9]{20}|AIza[0-9A-Za-z_-]{30}|-----BEGIN [A-Z ]*PRIVATE KEY)' \
    "$REPO/home" "$REPO/system" 2>/dev/null || true)
if [[ -n "$leaks" ]]; then
    err "Kemungkinan ada token/kunci rahasia di file berikut:"
    echo "$leaks"
    err "Repo kamu PUBLIC. Hapus rahasianya atau tambahkan ke EXCLUDES, lalu jalankan ulang."
    exit 1
fi
ok "Tidak ditemukan token/kunci rahasia"

# ── 6. Git ───────────────────────────────────────────────────────
(( DO_COMMIT )) || { ok "Backup selesai (tanpa commit)."; exit 0; }

step "Git commit"
cd "$REPO"
git add -A
if git diff --cached --quiet; then
    ok "Tidak ada perubahan sejak backup terakhir."
else
    git commit -q -m "backup: $(date '+%Y-%m-%d %H:%M')" && ok "Commit dibuat"
fi

if (( DO_PUSH )); then
    step "Git push"
    git push && ok "Ter-push ke $(git remote get-url origin)"
fi
