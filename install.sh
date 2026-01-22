#!/bin/bash

# --- Warna untuk Output ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

clear

# --- Hiasan ASCII Art ---
echo -e "${BLUE}"
echo "  █████╗ ██████╗  █████╗ ███╗   ███╗"
echo " ██╔══██╗██╔══██╗██╔══██╗████╗ ████║"
echo " ███████║██║  ██║███████║██╔████╔██║"
echo " ██╔══██║██║  ██║██╔══██║██║╚██╔╝██║"
echo " ██║  ██║██████╔╝██║  ██║██║ ╚═╝ ██║"
echo " ╚═╝  ╚═╝╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝"
echo -e "${GREEN}      ARCH LINUX DOTFILES SETUP${NC}"
echo -e "${BLUE}==========================================${NC}"
echo -e "${YELLOW}User: $USER | Host: $(hostname)${NC}"
echo -e "${BLUE}==========================================${NC}"

# 1. Pastikan GNU Stow terinstall
if ! command -v stow &> /dev/null; then
    echo -e "${YELLOW}[!]${NC} Menginstal GNU Stow..."
    sudo pacman -S --noconfirm stow
fi

# 2. Buat direktori target (Termasuk folder baru)
echo -e "${BLUE}[1/5]${NC} Menyiapkan direktori target..."
mkdir -p ~/.config/{hypr,kitty,waybar,rofi,wallust,fastfetch}
mkdir -p ~/myskrip
mkdir -p ~/data
mkdir -p ~/Pictures/wallpapers

# 3. Menyingkirkan file lama (Menghindari konflik symlink)
echo -e "${BLUE}[2/5]${NC} Membersihkan file lama agar tidak konflik..."
# Menghapus file di dalam folder config tapi tetap mempertahankan foldernya
find ~/.config/hypr -maxdepth 1 -type f -delete 2>/dev/null
find ~/.config/kitty -maxdepth 1 -type f -delete 2>/dev/null
find ~/.config/waybar -maxdepth 1 -type f -delete 2>/dev/null
find ~/.config/rofi -maxdepth 1 -type f -delete 2>/dev/null
find ~/.config/wallust -maxdepth 1 -type f -delete 2>/dev/null
find ~/.config/fastfetch -maxdepth 1 -type f -delete 2>/dev/null
rm -f ~/.zshrc

# 4. Proses Symlink menggunakan GNU Stow
echo -e "${BLUE}[3/5]${NC} Menghubungkan konfigurasi via GNU Stow..."
cd ~/dotfiles

# Gunakan --adopt untuk memaksa jika masih ada file yang tertinggal
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

# 5. Instalasi Plugin Zsh (Jika belum ada)
echo -e "${BLUE}[4/5]${NC} Memeriksa Plugin Zsh..."
ZSH_PLUGINS_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"

if [ ! -d "$ZSH_PLUGINS_DIR/zsh-syntax-highlighting" ]; then
    echo -e "${YELLOW}[!]${NC} Menginstal Zsh Syntax Highlighting..."
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_PLUGINS_DIR/zsh-syntax-highlighting"
fi

if [ ! -d "$ZSH_PLUGINS_DIR/zsh-autosuggestions" ]; then
    echo -e "${YELLOW}[!]${NC} Menginstal Zsh Autosuggestions..."
    git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_PLUGINS_DIR/zsh-autosuggestions"
fi

# Finalisasi
echo -e "${BLUE}[5/5]${NC} Menyelesaikan konfigurasi..."
echo -e "${BLUE}==========================================${NC}"
echo -e "${GREEN}   DONE! SISTEM SIAP DIGUNAKAN, ADAM!     ${NC}"
echo -e "${BLUE}==========================================${NC}"
echo -e "${YELLOW}Tips:${NC}"
echo -e "1. Ketik '${GREEN}perintah${NC}' untuk melihat daftar shortcut kamu."
echo -e "2. Tekan '${GREEN}Super+W${NC}' untuk memilih wallpaper."
echo -e "3. Jalankan '${GREEN}source ~/.zshrc${NC}' jika plugin belum aktif."
echo -e "${BLUE}==========================================${NC}"
