#!/usr/bin/env bash

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "Error: run as root (for example: sudo $0)"
    exit 1
fi

SOURCE_DIR="/lib/firmware/amdgpu"
BACKUP_DIR="/lib/firmware/amdgpu.bak.$(date +%Y%m%d_%H%M%S)"
WORK_DIR=$(mktemp -d)
FIRMWARE_REPO="$WORK_DIR/linux-firmware"

cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

if [[ ! -d "$SOURCE_DIR" ]]; then
    echo "Error: '$SOURCE_DIR' does not exist"
    exit 1
fi

echo "Backing up current firmware to: $BACKUP_DIR"
cp -a "$SOURCE_DIR" "$BACKUP_DIR"

echo "Cloning latest linux-firmware repository..."
git clone --depth=1 https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git "$FIRMWARE_REPO"

echo "Copying AMDGPU firmware files..."
cp "$FIRMWARE_REPO/amdgpu"/* "$SOURCE_DIR/"

if command -v update-initramfs >/dev/null 2>&1; then
    echo "Updating initramfs..."
    update-initramfs -u -k all
else
    echo "Warning: update-initramfs command not found. Update initramfs manually for your distro."
fi

echo "Done. Reboot is recommended."
