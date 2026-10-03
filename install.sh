#!/usr/bin/env bash
# install.sh — Pulihkan setup Arch Linux + Hyprland dari repo dotfiles ini.
#
# Jalankan di Arch yang BARU di-install (sudah ada user dengan sudo + internet):
#   sudo pacman -S --needed git
#   git clone https://github.com/Adammalik28/dotfiles.git ~/dotfiles
#   cd ~/dotfiles && ./install.sh
#
# Pemakaian:
#   ./install.sh                 jalankan semua langkah
#   ./install.sh -y              semua langkah tanpa konfirmasi
#   ./install.sh configs system  hanya langkah tertentu
#
# Langkah (urut): repos yay packages shell configs system services finish

set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$REPO/lib.sh"
source "$REPO/dotfiles.conf"

ALL_STEPS=(repos yay packages shell configs system services finish)
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$HOME/.dotfiles-backup/$STAMP"
FAILED_LOG="$HOME/dotfiles-gagal-$STAMP.txt"
ASSUME_YES=0
STEPS=()

for arg in "$@"; do
    case "$arg" in
        -y|--yes) ASSUME_YES=1 ;;
        -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
        *)
            if [[ " ${ALL_STEPS[*]} " == *" $arg "* ]]; then STEPS+=("$arg")
            else err "Langkah tidak dikenal: $arg (pilihan: ${ALL_STEPS[*]})"; exit 1; fi ;;
    esac
done
(( ${#STEPS[@]} )) || STEPS=("${ALL_STEPS[@]}")
export ASSUME_YES

log_failed() { echo "$1" >> "$FAILED_LOG"; warn "Gagal: $1"; }

# Install daftar paket sekaligus; kalau gagal (mis. 1 paket sudah tidak ada),
# ulangi satu per satu supaya paket lain tetap terpasang.
install_list() {
    local label="$1"; shift
    local -a cmd=("$1"); shift
    local -a pkgs=("$@")
    (( ${#pkgs[@]} )) || return 0
    info "Memasang ${#pkgs[@]} paket $label..."
    if "${cmd[@]}" "${pkgs[@]}"; then
        ok "Paket $label terpasang"
        return
    fi
    warn "Install sekaligus gagal, mencoba satu per satu..."
    local p
    for p in "${pkgs[@]}"; do
        "${cmd[@]}" "$p" || log_failed "$label: $p"
    done
}
pacman_install() { sudo pacman -S --needed --noconfirm "$@"; }
yay_install() {
    yay -S --needed --noconfirm --answerdiff None --answerclean None --removemake "$@"
}
flatpak_install() { flatpak install -y --noninteractive flathub "$@"; }

# ═════════════════════════════════════════════════════════════════
step_preflight() {
    step "Pemeriksaan awal"
    [[ $EUID -eq 0 ]] && { err "Jangan jalankan sebagai root. Pakai user biasa (sudo akan diminta)."; exit 1; }
    [[ -f /etc/arch-release ]] || { err "Skrip ini hanya untuk Arch Linux."; exit 1; }
    ping -c1 -W3 archlinux.org &>/dev/null || { err "Tidak ada koneksi internet."; exit 1; }

    local src_home; src_home="$(cat "$REPO/.source-home" 2>/dev/null || echo "$HOME")"
    if [[ "$src_home" != "$HOME" ]]; then
        warn "Backup dibuat dari $src_home, tapi HOME sekarang $HOME."
        warn "Path di config akan otomatis diganti saat langkah 'configs'."
    fi

    info "Meminta akses sudo (sekali saja)..."
    sudo -v || exit 1
    # Jaga sudo tetap aktif selama skrip berjalan.
    while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done 2>/dev/null &
    ok "Siap"
}

step_repos() {
    step "Repo pacman (multilib, BlackArch)"
    if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
        sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
        ok "multilib diaktifkan"
    fi
    sudo pacman -Syu --needed --noconfirm base-devel git rsync curl

    if [[ -s "$REPO/packages/blackarch.txt" ]] && ! pacman -Sl blackarch &>/dev/null; then
        info "Memasang repo BlackArch (strap.sh resmi dari blackarch.org)..."
        local tmp; tmp="$(mktemp -d)"
        curl -fsSL https://blackarch.org/strap.sh -o "$tmp/strap.sh" \
            && sudo bash "$tmp/strap.sh" \
            && ok "Repo BlackArch aktif" \
            || log_failed "repo: blackarch strap.sh"
        rm -rf "$tmp"
    fi

    # pacman.conf tersimpan (Color, ParallelDownloads, ILoveCandy, dll).
    # Dipasang setelah BlackArch siap, karena pacman.conf merujuk mirrorlist-nya.
    if [[ -f "$REPO/system/etc/pacman.conf" ]]; then
        if grep -q '^\[blackarch\]' "$REPO/system/etc/pacman.conf" && ! [[ -f /etc/pacman.d/blackarch-mirrorlist ]]; then
            warn "pacman.conf tersimpan butuh BlackArch, tapi repo belum siap. Dilewati."
        else
            sudo cp /etc/pacman.conf "/etc/pacman.conf.pre-dotfiles-$STAMP"
            sudo install -m644 "$REPO/system/etc/pacman.conf" /etc/pacman.conf
            sudo pacman -Sy
            ok "pacman.conf dipulihkan"
        fi
    fi
}

step_yay() {
    step "AUR helper (yay)"
    if command -v yay &>/dev/null; then ok "yay sudah ada"; return; fi
    local tmp; tmp="$(mktemp -d)"
    git clone --depth=1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin" \
        && (cd "$tmp/yay-bin" && makepkg -si --noconfirm) \
        && ok "yay terpasang" \
        || { err "Gagal memasang yay"; rm -rf "$tmp"; exit 1; }
    rm -rf "$tmp"
}

step_packages() {
    step "Paket"
    local -a list

    mapfile -t list < <(read_list "$REPO/packages/pacman.txt")
    install_list "pacman" pacman_install "${list[@]}"

    if pacman -Sl blackarch &>/dev/null; then
        mapfile -t list < <(read_list "$REPO/packages/blackarch.txt")
        install_list "BlackArch" pacman_install "${list[@]}"
    fi

    mapfile -t list < <(read_list "$REPO/packages/aur.txt")
    list+=("${EXTRA_AUR[@]}")
    install_list "AUR" yay_install "${list[@]}"

    mapfile -t list < <(read_list "$REPO/packages/flatpak.txt")
    if (( ${#list[@]} )) && command -v flatpak &>/dev/null; then
        flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
        install_list "flatpak" flatpak_install "${list[@]}"
    fi

    mapfile -t list < <(read_list "$REPO/packages/vscode.txt")
    if (( ${#list[@]} )) && command -v code &>/dev/null; then
        local ext
        for ext in "${list[@]}"; do
            code --install-extension "$ext" --force &>/dev/null || log_failed "vscode: $ext"
        done
        ok "Ekstensi VS Code dipasang"
    fi
}

step_shell() {
    step "Zsh + Oh My Zsh"
    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c \
            "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
            || log_failed "shell: oh-my-zsh"
    fi
    local custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"
    local -A plugins=(
        [zsh-autosuggestions]=https://github.com/zsh-users/zsh-autosuggestions
        [zsh-syntax-highlighting]=https://github.com/zsh-users/zsh-syntax-highlighting
    )
    local name
    for name in "${!plugins[@]}"; do
        [[ -d "$custom/$name" ]] || git clone --depth=1 "${plugins[$name]}" "$custom/$name" \
            || log_failed "shell: plugin $name"
    done
    if [[ "$(getent passwd "$USER" | cut -d: -f7)" != "$(command -v zsh)" ]]; then
        sudo chsh -s "$(command -v zsh)" "$USER" && ok "Shell default → zsh"
    fi
    ok "Zsh siap"
}

step_configs() {
    step "Config \$HOME"
    [[ -d "$REPO/home" ]] || { warn "Folder home/ kosong. Jalankan backup.sh dulu di laptop lama."; return; }

    # Cadangkan file yang akan ditimpa.
    local item
    for item in "${HOME_ITEMS[@]}"; do
        if [[ -e "$REPO/home/$item" && -e "$HOME/$item" ]]; then
            mkdir -p "$BACKUP_DIR/home/$(dirname "$item")"
            cp -a "$HOME/$item" "$BACKUP_DIR/home/$item"
        fi
    done
    [[ -d "$BACKUP_DIR" ]] && info "Config lama dicadangkan ke $BACKUP_DIR"

    rsync -a "$REPO/home/" "$HOME/"

    # Ganti path home lama kalau username berbeda.
    local src_home; src_home="$(cat "$REPO/.source-home" 2>/dev/null || echo "$HOME")"
    if [[ "$src_home" != "$HOME" ]]; then
        for item in "${HOME_ITEMS[@]}"; do
            [[ -e "$HOME/$item" ]] || continue
            grep -rIlF "$src_home" "$HOME/$item" 2>/dev/null \
                | xargs -r sed -i "s|$src_home|$HOME|g"
        done
        ok "Path $src_home → $HOME diganti"
    fi

    fc-cache -f &>/dev/null
    ok "Config dipulihkan"
}

step_system() {
    step "Config sistem (/etc, GRUB, SDDM, mkinitcpio)"
    [[ -d "$REPO/system" ]] || { warn "Folder system/ kosong."; return; }
    warn "Langkah ini menimpa file sistem: ${SYSTEM_ITEMS[*]}"
    warn "Beberapa (modprobe nvidia, nbfc, acer-wmi) khusus Acer Nitro AN515-58."
    confirm "Lanjutkan pulihkan config sistem?" || { info "Dilewati"; return; }

    local item src
    for item in "${SYSTEM_ITEMS[@]}"; do
        src="$REPO/system$item"
        [[ -e "$src" ]] || continue
        if [[ -e "$item" ]]; then
            sudo mkdir -p "$BACKUP_DIR/system$(dirname "$item")"
            sudo cp -a "$item" "$BACKUP_DIR/system$item"
        fi
        sudo mkdir -p "$(dirname "$item")"
        if [[ -d "$src" ]]; then
            sudo rsync -a --chown=root:root "$src/" "$item/"
        else
            sudo rsync -a --chown=root:root "$src" "$item"
        fi || log_failed "system: $item"
    done
    ok "File sistem disalin (cadangan lama: $BACKUP_DIR/system)"

    local theme; theme="$(cat "$REPO/services/plymouth.txt" 2>/dev/null)"
    if [[ -n "$theme" ]] && command -v plymouth-set-default-theme &>/dev/null; then
        sudo plymouth-set-default-theme "$theme" && ok "Tema Plymouth → $theme"
    fi

    info "Membuat ulang initramfs..."
    sudo mkinitcpio -P || log_failed "system: mkinitcpio -P"

    if command -v grub-mkconfig &>/dev/null && [[ -d /boot/grub ]]; then
        info "Membuat ulang konfigurasi GRUB..."
        sudo grub-mkconfig -o /boot/grub/grub.cfg || log_failed "system: grub-mkconfig"
    fi

    if [[ -f "$REPO/reference/etc/fstab" ]]; then
        info "fstab lama ada di reference/etc/fstab — tambahkan mount NTFS manual (UUID disk berbeda)."
    fi
}

step_services() {
    step "Service & grup"
    local unit
    while read -r unit; do
        [[ -z "$unit" ]] && continue
        if systemctl cat "$unit" &>/dev/null; then
            sudo systemctl enable "$unit" &>/dev/null || log_failed "service: $unit"
        else
            warn "Unit tidak ada (paket belum terpasang?): $unit"
        fi
    done < "$REPO/services/system.txt"
    ok "Service sistem diaktifkan"

    while read -r unit; do
        [[ -z "$unit" ]] && continue
        systemctl --user enable "$unit" &>/dev/null || log_failed "user service: $unit"
    done < "$REPO/services/user.txt"
    ok "Service user diaktifkan"

    local g
    while read -r g; do
        [[ -z "$g" ]] && continue
        if getent group "$g" &>/dev/null; then
            sudo usermod -aG "$g" "$USER"
        else
            warn "Grup tidak ada: $g"
        fi
    done < "$REPO/services/groups.txt"
    ok "User $USER ditambahkan ke grup: $(paste -sd' ' "$REPO/services/groups.txt")"
}

step_finish() {
    step "Selesai"
    command -v xdg-user-dirs-update &>/dev/null && xdg-user-dirs-update
    if [[ -s "$FAILED_LOG" ]]; then
        warn "Ada yang gagal, lihat: $FAILED_LOG"
        cat "$FAILED_LOG"
    else
        ok "Semua langkah berhasil"
    fi
    echo
    info "Langkah manual yang tersisa:"
    echo "  • Pulihkan kunci SSH/GPG dari backup pribadi (tidak disimpan di repo publik)"
    echo "  • Login ulang: gh auth login, browser, Discord, dll"
    echo "  • Tambahkan mount NTFS ke /etc/fstab (lihat reference/etc/fstab)"
    echo
    confirm "Reboot sekarang?" && sudo reboot
}

# ═════════════════════════════════════════════════════════════════
echo -e "\033[1;36m"
cat <<'EOF'
  ┌─────────────────────────────────────────┐
  │  Dotfiles Restore — Arch + Hyprland     │
  └─────────────────────────────────────────┘
EOF
echo -e "\033[0m"
info "Langkah: ${STEPS[*]}"
confirm "Mulai?" || exit 0

step_preflight
for s in "${STEPS[@]}"; do "step_$s"; done
