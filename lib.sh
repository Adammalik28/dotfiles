# lib.sh — fungsi bantu bersama untuk backup.sh & install.sh

ok()   { echo -e "\033[32m✅ $*\033[0m"; }
err()  { echo -e "\033[31m❌ $*\033[0m" >&2; }
info() { echo -e "\033[34mℹ  $*\033[0m"; }
warn() { echo -e "\033[33m⚠️  $*\033[0m"; }
step() { echo -e "\n\033[1;35m━━━ $* ━━━\033[0m"; }

# Tanya ya/tidak. Default "y". Lewati jika ASSUME_YES=1.
confirm() {
    [[ "${ASSUME_YES:-0}" == 1 ]] && return 0
    local ans
    read -rp "$(echo -e "\033[33m❓ $1 [Y/n] \033[0m")" ans
    [[ -z "$ans" || "$ans" =~ ^[Yy] ]]
}

# Bangun argumen --exclude untuk rsync dari array EXCLUDES.
rsync_excludes() {
    local p
    for p in "${EXCLUDES[@]}"; do printf -- '--exclude=%s\n' "$p"; done
}

# Baca daftar paket dari file (abaikan baris kosong & komentar).
read_list() {
    [[ -f "$1" ]] && grep -vE '^\s*(#|$)' "$1" || true
}
