#!/bin/bash

echo "==> Mounting Windows partitions..."

mount_partition () {
    DEVICE="$1"
    MOUNTPOINT="$2"
    OPTIONS="$3"

    # cek: device sudah mounted di mana?
    EXISTING_MP=$(findmnt -n -o TARGET --source "$DEVICE")

    if [ -n "$EXISTING_MP" ]; then
        echo "[SKIP] $DEVICE already mounted at $EXISTING_MP"
        return
    fi

    sudo mkdir -p "$MOUNTPOINT"

    if sudo mount -t ntfs-3g "$DEVICE" "$MOUNTPOINT" $OPTIONS 2>/tmp/mount_error.log; then
        echo "[ OK ] Mounted $DEVICE -> $MOUNTPOINT"
    else
        echo "[FAIL] Failed to mount $DEVICE -> $MOUNTPOINT"
        cat /tmp/mount_error.log
    fi
}

mount_partition /dev/sda1       /mnt/windows/sda1     "-o uid=1000,gid=1000,rw"
mount_partition /dev/nvme0n1p3  /mnt/windows/acer    "-o uid=1000,gid=1000,rw"
mount_partition /dev/nvme1n1p1  /mnt/windows/data    "-o uid=1000,gid=1000,rw"
mount_partition /dev/nvme0n1p7  /mnt/windows/recovery "-o ro"

echo "==> Mount process finished."
