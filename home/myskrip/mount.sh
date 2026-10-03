#!/bin/bash
# mount.sh — Mount/Unmount USB & partisi via fzf (modern udisksctl & fallback sudo)
# Oleh: myskrip collection

MOUNT_BASE="/mnt"
NOTIF_TIMEOUT=4000

notif() {
    notify-send -t "$NOTIF_TIMEOUT" "💾 Mount Manager" "$1"
}

pilih_aksi() {
    printf "📂  Mount perangkat\n⏏  Unmount perangkat\n🔍  Lihat yang sedang di-mount" \
        | fzf --prompt="Aksi > " \
              --height=30% \
              --border=rounded \
              --color=bg+:#1e1e2e,fg+:#cdd6f4,hl+:#89b4fa,border:#313244 \
              | awk -F'  ' '{print $2}'
}

lakukan_mount() {
    # Ambil daftar partisi yang belum di-mount
    local perangkat
    perangkat=$(lsblk -rpo "NAME,SIZE,FSTYPE,MOUNTPOINT,LABEL" \
        | awk '$4 == "" && $3 != "" && $1 !~ /^\/dev\/sd[a-z]$/ && $1 !~ /^\/dev\/nvme[0-9]+n[0-9]+$/ {
            label = $5 ? $5 : "no-label"
            printf "%s  [%s]  fs:%s  label:%s\n", $1, $2, $3, label
          }' \
        | fzf --prompt="Pilih partisi > " \
              --height=50% \
              --border=rounded \
              --header="Partisi yang belum di-mount (Esc untuk batal)" \
              --color=bg+:#1e1e2e,fg+:#cdd6f4,hl+:#89b4fa,border:#313244,header:#a6e3a1 \
        | awk '{print $1}')

    [ -z "$perangkat" ] && return

    local mountpoint=""

    # 1. Coba via udisksctl (standar desktop, bebas sudo, permission user)
    if command -v udisksctl &>/dev/null; then
        local out
        out=$(udisksctl mount -b "$perangkat" 2>&1)
        if [ $? -eq 0 ]; then
            mountpoint=$(echo "$out" | sed -n 's/.*Mounted .* at \(.*\)\./\1/p')
            [ -z "$mountpoint" ] && mountpoint=$(lsblk -no MOUNTPOINT "$perangkat" 2>/dev/null)
            notif "✅ $perangkat berhasil di-mount"
            echo "Berhasil mount via udisksctl: $perangkat → $mountpoint"
            buka_file_manager "$mountpoint"
            return 0
        fi
        echo "udisksctl gagal, mencoba fallback sudo mount..."
    fi

    # 2. Fallback: sudo mount tradisional ke /mnt/<label>
    local label devname
    label=$(lsblk -no LABEL "$perangkat" 2>/dev/null | tr ' ' '_')
    devname=$(basename "$perangkat")
    mountpoint="$MOUNT_BASE/${label:-$devname}"

    sudo mkdir -p "$mountpoint"
    if sudo mount "$perangkat" "$mountpoint"; then
        notif "✅ $perangkat berhasil di-mount ke $mountpoint"
        echo "Berhasil mount via sudo: $perangkat → $mountpoint"
        buka_file_manager "$mountpoint"
    else
        notif "❌ Gagal mount $perangkat"
        echo "Gagal mount $perangkat"
    fi
}

buka_file_manager() {
    local target="$1"
    [ -z "$target" ] && return
    if command -v thunar &>/dev/null; then
        thunar "$target" &
    elif command -v nautilus &>/dev/null; then
        nautilus "$target" &
    elif command -v dolphin &>/dev/null; then
        dolphin "$target" &
    fi
}

lakukan_unmount() {
    # Ambil yang sedang di-mount (exclude sistem / dan /boot)
    local target
    target=$(lsblk -rpo "NAME,SIZE,MOUNTPOINT,LABEL" \
        | awk '$3 != "" && $3 != "/" && $3 !~ /^\/boot/ && $3 !~ /^\[/ {
            label = $4 ? $4 : "no-label"
            printf "%s  [%s]  → %s  (%s)\n", $1, $2, $3, label
          }' \
        | fzf --prompt="Pilih untuk unmount > " \
              --height=50% \
              --border=rounded \
              --header="Perangkat yang sedang di-mount (Esc untuk batal)" \
              --color=bg+:#1e1e2e,fg+:#cdd6f4,hl+:#89b4fa,border:#313244,header:#f38ba8 \
        | awk '{print $1}')

    [ -z "$target" ] && return

    local mountpoint
    mountpoint=$(lsblk -no MOUNTPOINT "$target" 2>/dev/null)

    # 1. Coba via udisksctl
    if command -v udisksctl &>/dev/null; then
        if udisksctl unmount -b "$target" &>/dev/null; then
            notif "⏏ $target berhasil di-unmount"
            echo "Berhasil unmount via udisksctl: $target (dari $mountpoint)"
            return 0
        fi
    fi

    # 2. Fallback: sudo umount
    if sudo umount "$target"; then
        notif "⏏ $target berhasil di-unmount"
        echo "Berhasil unmount via sudo: $target (dari $mountpoint)"
        if [[ "$mountpoint" == "$MOUNT_BASE"/* ]]; then
            sudo rmdir "$mountpoint" 2>/dev/null
        fi
    else
        notif "❌ Gagal unmount $target — mungkin masih digunakan"
        echo "Gagal unmount $target"
    fi
}

lihat_mount() {
    echo "=== Perangkat yang sedang di-mount ==="
    lsblk -po "NAME,SIZE,FSTYPE,MOUNTPOINT,LABEL" \
        | awk '$4 != "" {print}' \
        | column -t \
        | less
}

main() {
    local aksi
    aksi=$(pilih_aksi)

    case "$aksi" in
        "Mount perangkat")   lakukan_mount ;;
        "Unmount perangkat") lakukan_unmount ;;
        "Lihat yang sedang di-mount") lihat_mount ;;
        *) exit 0 ;;
    esac
}

case "$1" in
    -m|--mount)   lakukan_mount ;;
    -u|--unmount) lakukan_unmount ;;
    -l|--list)    lihat_mount ;;
    -h|--help)
        echo "Penggunaan: mount.sh [OPSI]"
        echo "  (tanpa opsi)   Menu interaktif"
        echo "  -m, --mount    Langsung ke mount"
        echo "  -u, --unmount  Langsung ke unmount"
        echo "  -l, --list     Lihat semua yang di-mount"
        ;;
    *) main ;;
esac
