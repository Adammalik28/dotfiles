#!/bin/bash
echo "Memulai instalasi dotfiles untuk: $USER"

# Buat direktori target
mkdir -p ~/.config/hypr ~/.config/kitty ~/.config/waybar ~/.config/rofi ~/.config/wallust ~/myskrip

# Hapus file lama agar tidak konflik
echo "Menyingkirkan file lama..."
find ~/.config/hypr -type f -delete
find ~/.config/kitty -type f -delete
find ~/.config/waybar -type f -delete
find ~/.config/rofi -type f -delete
find ~/.config/wallust -type f -delete
rm -f ~/.zshrc

# Jalankan Stow
cd ~/dotfiles
echo "Menghubungkan konfigurasi..."
stow zsh -t ~
stow hypr -t ~/.config/hypr
stow kitty -t ~/.config/kitty
stow waybar -t ~/.config/waybar
stow rofi -t ~/.config/rofi
stow wallust -t ~/.config/wallust
stow myskrip -t ~/myskrip

echo "Selesai! Semua konfigurasi JaKooLit dan myskrip telah terhubung."
