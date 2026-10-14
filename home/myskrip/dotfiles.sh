#!/usr/bin/env bash
# dotfiles.sh — Pembungkus untuk backup.sh / install.sh di repo dotfiles.
# Logika sebenarnya ada di repo (daftar item: dotfiles.conf), skrip ini hanya
# jalan pintas supaya bisa dipanggil dari mana saja.

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"

[[ -d "$DOTFILES_DIR/.git" ]] || { echo "Repo dotfiles tidak ditemukan: $DOTFILES_DIR" >&2; exit 1; }
cd "$DOTFILES_DIR" || exit 1

usage() {
    cat <<EOF
Penggunaan: dotfiles.sh [OPSI]
  -b, --backup      Backup + commit + push  (backup.sh)
      --no-push     Backup + commit tanpa push
  -r, --restore     Pulihkan dari repo      (install.sh)
  -s, --status      Status git repo
  -p, --pull        git pull
  (tanpa opsi)      Menu fzf
Env: DOTFILES_DIR (default: ~/dotfiles)
EOF
}

case "${1:-}" in
    -b|--backup)  exec ./backup.sh ;;
    --no-push)    exec ./backup.sh --no-push ;;
    -r|--restore) shift; exec ./install.sh "$@" ;;
    -s|--status)  git status -sb; git log --oneline -5 ;;
    -p|--pull)    git pull --ff-only ;;
    -h|--help)    usage ;;
    "")
        command -v fzf &>/dev/null || { usage; exit 0; }
        pilihan=$(printf '%s\n' "Backup + push" "Backup tanpa push" "Restore (install.sh)" "Status" "Pull" \
            | fzf --prompt="Dotfiles > " --height=40% --reverse) || exit 0
        case "$pilihan" in
            "Backup + push")        ./backup.sh ;;
            "Backup tanpa push")    ./backup.sh --no-push ;;
            "Restore (install.sh)") ./install.sh ;;
            "Status")               git status -sb; git log --oneline -5 ;;
            "Pull")                 git pull --ff-only ;;
        esac ;;
    *) usage; exit 1 ;;
esac
