#!/usr/bin/env bash

set -euo pipefail

ACTION=${1:-create}
MOUNTPOINT=${2:-./ramdisk}
SIZE=${3:-1G}

if [[ $EUID -ne 0 ]]; then
    echo "Error: run as root (for example: sudo $0 $ACTION $MOUNTPOINT $SIZE)"
    exit 1
fi

case "$ACTION" in
    create)
        mkdir -p "$MOUNTPOINT"
        mount -t tmpfs -o "size=$SIZE" tmpfs "$MOUNTPOINT"
        echo "Mounted tmpfs at '$MOUNTPOINT' with size '$SIZE'"
        ;;
    remove|umount)
        umount "$MOUNTPOINT"
        echo "Unmounted '$MOUNTPOINT'"
        ;;
    *)
        echo "Usage: $0 <create|remove|umount> [mountpoint] [size]"
        echo "Example: $0 create ./ramdisk 1G"
        echo "Example: $0 remove ./ramdisk"
        exit 1
        ;;
esac
