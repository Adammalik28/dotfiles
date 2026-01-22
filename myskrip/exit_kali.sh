#!/bin/bash

MOUNT_POINT="/mnt/kali"

echo "Membersihkan lingkungan chroot (unmounting virtual systems)..."

# Unmount secara terbalik (LIFO) agar tidak error 'busy'
sudo umount -l "$MOUNT_POINT/dev/pts" 2>/dev/null
sudo umount -l "$MOUNT_POINT/dev"     2>/dev/null
sudo umount -l "$MOUNT_POINT/sys"     2>/dev/null
sudo umount -l "$MOUNT_POINT/proc"    2>/dev/null
sudo umount -l "$MOUNT_POINT/run"     2>/dev/null

echo "Selesai! Partisi /mnt/kali tetap aktif untuk akses file."
