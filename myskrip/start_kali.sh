#!/bin/bash

MOUNT_POINT="/mnt/kali"

# 1. Cek apakah partisi sudah ter-mount (karena fstab)
if ! mountpoint -q "$MOUNT_POINT"; then
    echo "Mounting Kali Linux partition..."
    sudo mount "$MOUNT_POINT"
fi

echo "Mempersiapkan virtual file systems untuk chroot..."
# Gunakan loop agar lebih rapi dan efisien
for dir in /proc /sys /dev /dev/pts /run; do
    # Cek agar tidak terjadi double bind-mount
    if ! mountpoint -q "$MOUNT_POINT$dir"; then
        sudo mount --bind "$dir" "$MOUNT_POINT$dir"
    fi
done

# Copy resolv.conf agar internet di dalam chroot jalan lancar
sudo cp /etc/resolv.conf "$MOUNT_POINT/etc/resolv.conf"

echo "Masuk ke Kali Linux chroot (User: adam)..."
# Perbaikan perintah chroot: langsung jalankan zsh sebagai user adam
sudo chroot "$MOUNT_POINT" /usr/bin/zsh -c "su - adam"

echo "Anda telah keluar dari Kali Linux."
