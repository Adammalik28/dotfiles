#!/usr/bin/env bash
#
# hypr-config-picker.sh (semua_config.sh)
# Pilih file config Hyprland (dotfiles JaKooLit) via fzf, buka dengan mousepad.
#

set -uo pipefail
# CATATAN: "set -e" SENGAJA tidak dipakai di sini.
# fzf keluar dengan exit code 130 saat user tekan Esc/Ctrl-C — itu perilaku
# NORMAL (bukan error), bukan tanda script gagal. Kalau "set -e" tetap aktif,
# exit code itu akan langsung mematikan script sebelum sempat kita tangani
# dengan baik, dan akan tercatat sebagai ERR(130) di atur.sh padahal user
# cuma membatalkan pilihan.

HYPR_DIR="$HOME/.config/hypr"
CONFIGS_DIR="$HYPR_DIR/configs"
USERCONFIGS_DIR="$HYPR_DIR/UserConfigs"
EDITOR_CMD="mousepad"

# Pastikan mousepad terpasang
if ! command -v "$EDITOR_CMD" >/dev/null 2>&1; then
    echo "Error: '$EDITOR_CMD' tidak ditemukan. Install dulu dengan: sudo pacman -S mousepad"
    exit 1
fi

# Pastikan fzf terpasang
if ! command -v fzf >/dev/null 2>&1; then
    echo "Error: 'fzf' tidak ditemukan. Install dulu dengan: sudo pacman -S fzf"
    exit 1
fi

# Daftar file: "Label|path"
declare -a ITEMS=(
    "hyprland.conf (main)|$HYPR_DIR/hyprland.conf"
    "Keybinds.conf (default)|$CONFIGS_DIR/Keybinds.conf"
    "Startup_Apps.conf (default)|$CONFIGS_DIR/Startup_Apps.conf"
    "Startup_Apps.conf (user)|$USERCONFIGS_DIR/Startup_Apps.conf"
    "ENVariables.conf (default)|$CONFIGS_DIR/ENVariables.conf"
    "ENVariables.conf (user)|$USERCONFIGS_DIR/ENVariables.conf"
    "Laptops.conf (default)|$CONFIGS_DIR/Laptops.conf"
    "WindowRules.conf (default)|$CONFIGS_DIR/WindowRules.conf"
    "WindowRules.conf (user)|$USERCONFIGS_DIR/WindowRules.conf"
    "SystemSettings.conf (default)|$CONFIGS_DIR/SystemSettings.conf"
    "UserDecorations.conf (user)|$USERCONFIGS_DIR/UserDecorations.conf"
    "UserAnimations.conf (user)|$USERCONFIGS_DIR/UserAnimations.conf"
    "UserKeybinds.conf (user)|$USERCONFIGS_DIR/UserKeybinds.conf"
    "UserSettings.conf (user)|$USERCONFIGS_DIR/UserSettings.conf"
    "01-UserDefaults.conf (user)|$USERCONFIGS_DIR/01-UserDefaults.conf"
    "monitors.conf|$HYPR_DIR/monitors.conf"
    "workspaces.conf|$HYPR_DIR/workspaces.conf"
)

# Bangun daftar untuk fzf, hanya tampilkan yang filenya benar-benar ada
build_menu() {
    for item in "${ITEMS[@]}"; do
        label="${item%%|*}"
        path="${item##*|}"
        if [[ -f "$path" ]]; then
            printf "%s\t%s\n" "$label" "$path"
        fi
    done
}

# ─── Menu "mau apa setelah dibatalkan?" ───
# Dipanggil saat user tekan Esc/Ctrl-C di daftar config.
# Return via variabel global NEXT_ACTION: "retry" atau "exit"
ask_next_action() {
    local choice
    choice=$(printf "Pilih config lagi\nKembali ke menu skrip (keluar)\n" | fzf \
        --prompt="Dibatalkan, mau apa? > " \
        --header="Enter: pilih | Esc: keluar langsung" \
        --height=25% \
        --border \
        --reverse)

    if [[ "$choice" == "Pilih config lagi" ]]; then
        NEXT_ACTION="retry"
    else
        # Termasuk kalau di menu ini pun user tekan Esc lagi -> anggap keluar
        NEXT_ACTION="exit"
    fi
}

# ─── Loop utama ────────────────────────────
while true; do
    # Pola "if cmd; then ... else ...; fi" ini PENTING:
    # dengan menaruh pipeline di kondisi if, exit code non-zero dari fzf
    # (mis. 130 saat Esc) tidak akan mengaktifkan "set -e" / mematikan
    # script secara paksa. Ini yang jadi akar masalah error kemarin.
    if selection=$(build_menu | fzf \
        --delimiter='\t' \
        --with-nth=1 \
        --prompt="Pilih config Hyprland > " \
        --header="Enter: buka di mousepad | Esc: batal" \
        --height=60% \
        --border \
        --reverse); then
        fzf_status=0
    else
        fzf_status=$?
    fi

    # Kosong = user batal (Esc/Ctrl-C) ATAU tidak ada yang match
    if [[ -z "${selection:-}" ]]; then
        echo "Dibatalkan."
        ask_next_action
        if [[ "$NEXT_ACTION" == "retry" ]]; then
            continue   # kembali ke atas loop, tampilkan daftar config lagi
        else
            echo "Kembali ke menu skrip."
            exit 0     # keluar bersih (exit 0), tidak akan tercatat sebagai ERR di atur.sh
        fi
    fi

    # Ambil path dari kolom kedua, lalu buka
    config_path=$(echo "$selection" | awk -F'\t' '{print $2}')
    echo "Membuka: $config_path"
    "$EDITOR_CMD" "$config_path" &
    disown
    break
done