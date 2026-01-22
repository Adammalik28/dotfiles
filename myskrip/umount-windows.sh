#!/bin/bash

echo "==> Unmounting Windows partitions..."

umount_partition () {
    DEVICE="$1"

    MP=$(findmnt -n -o TARGET --source "$DEVICE")

    if [ -z "$MP" ]; then
        echo "[SKIP] $DEVICE is not mounted"
        return
    fi

    if sudo umount "$MP" 2>/tmp/umount_error.log; then
        echo "[ OK ] Unmounted $DEVICE from $MP"
    else
        echo "[FAIL] Failed to unmount $DEVICE from $MP"
        cat /tmp/umount_error.log
    fi
}

umount_partition /dev/nvme0n1p7
umount_partition /dev/nvme1n1p1
umount_partition /dev/nvme0n1p3
umount_partition /dev/sda1

echo "==> Unmount process finished."
