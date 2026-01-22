#!/bin/bash

# --- Warna untuk Output ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}==========================================${NC}"
echo -e "${GREEN}   Adam's Arch Linux Dotfiles Installer   ${NC}"
echo -e "${BLUE}==========================================${NC}"

# 1. Pastikan GNU Stow terinstall
if ! command -v stow &> /dev/null; then
    echo -e "${BLUE}[1/4]${NC} Menginstal GNU Stow..."
    sudo pacman -S --noconfirm stow
else
    echo -e "${BLUE}[1/4]${NC} GNU Stow sudah terpasang."
fi

# 2. Buat direktori yang diperlukan
echo -e "${BLUE}[2/4]${NC} Menyiapkan folder direktori..."
mkdir -p ~/.config/hypr
mkdir -p ~/.config/kitty
mkdir -p ~/myskrip

# 3. Membersihkan file lama (agar tidak konflik saat stow)
# Stow akan gagal jika file asli masih ada, jadi kita hapus/backup dulu
echo -e "${BLUE}[3/4]${NC} Membersihkan konfigurasi lama (backup ke .bak)..."
[ -f ~/.zshrc ] && mv ~/.zshrc ~/.zshrc.bak
[ -d ~/.config/hypr ] && mv ~/.config/hypr ~/.config/hypr.bak
[ -d ~/.config/kitty ] && mv ~/.config/kitty ~/.config/kitty.bak

# 4. Eksekusi GNU Stow
echo -e "${BLUE}[4/4]${NC} Menghubungkan Dotfiles menggunakan Stow..."
cd ~/dotfiles

# Menghubungkan Zsh (target ke HOME)
stow zsh -t ~

# Menghubungkan Kitty & Hyprland (target ke .config)
# Pastikan folder di ~/dotfiles bernama 'kitty' dan 'hypr'
stow kitty -t ~/.config/kitty
stow hypr -t ~/.config/hypr

# Menghubungkan Folder Skrip Pribadi
stow myskrip -t ~/myskrip

echo -e "${BLUE}==========================================${NC}"
echo -e "${GREEN}      INSTALASI SELESAI, ADAM!           ${NC}"
echo -e "${BLUE}==========================================${NC}"
echo "Silakan restart terminal atau ketik: source ~/.zshrc"
