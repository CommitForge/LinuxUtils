# hardware_amdgpu_firmware_update

Backs up current AMDGPU firmware, fetches the latest Linux firmware bundle, copies updated AMDGPU blobs, and refreshes initramfs when available.

## What It Does

1. Creates a timestamped backup of `/lib/firmware/amdgpu`
2. Clones the latest `linux-firmware` repository
3. Copies `amdgpu/*` firmware files into `/lib/firmware/amdgpu`
4. Runs `update-initramfs -u -k all` if available

## Usage

```bash
chmod +x hardware_amdgpu_firmware_update.sh
sudo ./hardware_amdgpu_firmware_update.sh
```

## Notes

- This script modifies system firmware files and should be used carefully.
- A reboot is recommended after completion.
- The backup path is printed during execution.
