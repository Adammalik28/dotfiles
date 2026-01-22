#!/bin/bash

# --- Konfigurasi Warna ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

clear
echo -e "${BLUE}==========================================${NC}"
echo -e "${GREEN}    ADAM'S ARCH LINUX AUTO-INSTALLER      ${NC}"
echo -e "${BLUE}==========================================${NC}"

# 1. PASTIKAN REPO TERBARU
echo -e "${BLUE}[*]${NC} Sinkronisasi database sistem..."
sudo pacman -Syu --noconfirm

# 2. CEK & INSTALASI AUR HELPER (PARU) DENGAN REBUILD
if ! command -v paru &> /dev/null || ! paru --version &> /dev/null; then
    echo -e "${YELLOW}[!]${NC} Paru bermasalah atau tidak ditemukan. Membangun ulang..."
    sudo pacman -S --needed base-devel git --noconfirm
    rm -rf /tmp/paru-bin
    git clone https://aur.archlinux.org/paru-bin.git /tmp/paru-bin
    cd /tmp/paru-bin && makepkg -si --noconfirm && cd -
fi

# 3. INSTALASI DEPENDENSI SISTEM
echo -e "${BLUE}[1/6]${NC} Menginstal paket aplikasi..."
# Gunakan pacman untuk paket resmi (lebih cepat & stabil)
OFFICIAL_PKGS=(
    'hyprland' 'waybar' 'swaync' 'rofi-wayland' 'kitty' 'swww' 'fastfetch' 
    'lsd' 'fzf' 'stow' 'brightnessctl' 'pavucontrol' 'nm-connection-editor'
    'nwg-look' 'qt5ct' 'qt6ct' 'kvantum' 'mousepad' 'thunar' 'gvfs' 'polkit-gnome'
)

# Gunakan paru untuk paket dari AUR (wallust, dll)
AUR_PKGS=('wallust')

echo "Menginstal paket resmi..."
sudo pacman -S --needed --noconfirm "${OFFICIAL_PKGS[@]}"

echo "Menginstal paket AUR..."
paru -S --needed --noconfirm "${AUR_PKGS[@]}"

# 4. INSTALASI OH-MY-ZSH SECARA OTOMATIS
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo -e "${BLUE}[2/6]${NC} Menginstal Oh-My-Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# 5. MENYIAPKAN DIREKTORI DAN MEMBERSIHKAN KONFLIK
echo -e "${BLUE}[3/6]${NC} Menyiapkan folder dan membersihkan file bawaan..."
mkdir -p ~/.config/{hypr,kitty,waybar,rofi,wallust,fastfetch}
mkdir -p ~/{myskrip,data,Pictures/wallpapers}

# Hapus config default agar tidak tabrakan dengan Stow
rm -rf ~/.config/hypr/* ~/.config/waybar/* ~/.config/rofi/* ~/.zshrc

# 6. MENGHUBUNGKAN DOTFILES (STOW)
echo -e "${BLUE}[4/6]${NC} Menghubungkan Dotfiles..."
cd ~/dotfiles
stow zsh -t ~
stow hypr -t ~/.config/hypr
stow kitty -t ~/.config/kitty
stow waybar -t ~/.config/waybar
stow rofi -t ~/.config/rofi
stow wallust -t ~/.config/wallust
stow fastfetch -t ~/.config/fastfetch
stow myskrip -t ~/myskrip
stow data -t ~/data
stow wallpapers -t ~/Pictures/wallpapers

# 7. INSTALASI PLUGIN ZSH
echo -e "${BLUE}[5/6]${NC} Menginstal Plugin Zsh..."
PLUG_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"
[ ! -d "$PLUG_DIR/zsh-syntax-highlighting" ] && git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$PLUG_DIR/zsh-syntax-highlighting"
[ ! -d "$PLUG_DIR/zsh-autosuggestions" ] && git clone https://github.com/zsh-users/zsh-autosuggestions "$PLUG_DIR/zsh-autosuggestions"

# 8. FIX PERMISSIONS
echo -e "${BLUE}[6/6]${NC} Mengatur izin eksekusi skrip..."
chmod +x ~/myskrip/*.sh
chmod +x ~/.config/hypr/scripts/*.sh

echo -e "${BLUE}==========================================${NC}"
echo -e "${GREEN}      INSTALLASI SELESAI SEMPURNA!        ${NC}"
echo -e "${BLUE}==========================================${NC}"
echo -e "Silakan REBOOT laptop kamu sekarang."
