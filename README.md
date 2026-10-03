# Dotfiles — adam@arch

Setup lengkap Arch Linux + Hyprland (Acer Nitro AN515-58), bisa dipulihkan dengan satu perintah.

## Laptop baru / rusak → pulihkan semuanya

1. Install Arch dasar (mis. `archinstall`): buat user dengan sudo, pasang NetworkManager & GRUB.
2. Login sebagai user tersebut, lalu:

```bash
sudo pacman -S --needed git
git clone https://github.com/Adammalik28/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

Skrip akan berjalan berurutan:

| Langkah    | Isi |
|------------|-----|
| `repos`    | aktifkan multilib, pasang repo BlackArch, pulihkan `pacman.conf` |
| `yay`      | pasang AUR helper yay |
| `packages` | semua paket pacman, BlackArch, AUR, flatpak, ekstensi VS Code |
| `shell`    | Oh My Zsh + plugin, shell default → zsh |
| `configs`  | semua config di `~` (Hyprland, Waybar, Rofi, Kitty, wallpaper, myskrip, …) |
| `system`   | GRUB + tema bsol, SDDM + tema, mkinitcpio/Plymouth, modprobe, nbfc (minta konfirmasi) |
| `services` | aktifkan service (sddm, NetworkManager, docker, libvirtd, …) + grup user |
| `finish`   | ringkasan yang gagal + tawaran reboot |

Untuk menjalankan langkah tertentu saja: `./install.sh configs system`. Supaya tanpa konfirmasi: `./install.sh -y`.

File yang ditimpa dicadangkan dulu ke `~/.dotfiles-backup/<waktu>/`. Paket yang gagal dicatat di `~/dotfiles-gagal-<waktu>.txt`.

## Simpan perubahan (jalankan rutin di laptop yang sekarang)

```bash
~/dotfiles/backup.sh            # backup + commit + push
~/dotfiles/backup.sh --no-push  # tanpa push
~/dotfiles/backup.sh --no-git   # hanya salin file
```

Daftar file dan folder yang di-backup ada di `dotfiles.conf`. Tambah atau hapus item di sana.

## Struktur

```
install.sh        pemulihan
backup.sh         simpan kondisi sekarang ke repo
dotfiles.conf     daftar item yang dikelola
packages/         pacman.txt, aur.txt, blackarch.txt, flatpak.txt, vscode.txt
services/         service system/user, grup, tema plymouth
home/             cermin dari ~
system/           cermin dari / (etc, boot/grub/themes, sddm theme)
reference/        disimpan tapi tidak di-restore otomatis (fstab)
```

## Tidak disimpan (sengaja)

- Kunci SSH/GPG, token `gh`, sesi browser: repo ini **publik**. Simpan di backup terenkripsi terpisah.
- `~/.icons` (600 MB+): Bibata & Flat-Remix dipasang ulang lewat AUR.
- Data aplikasi (Code, Discord, Brave, Steam, Docker/VM images) dan isi folder pribadi.
