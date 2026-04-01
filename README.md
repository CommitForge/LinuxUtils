# LinuxUtils

Collection of Linux utility scripts. Each script has its own folder with a runnable `.sh` file and a dedicated `README.md`.

## Script Layout

```text
scripts/
├── organize/multimedia/organize_photos_by_date/
├── server/hardware/hardware_amdgpu_firmware_update/
├── server/hardware/hardware_cpu_find_best_core/
├── server/security/security_ips_collect_suspicious/
├── system/filesystem/files_cat_by_round/
├── system/filesystem/files_compare_meaningful_diff/
└── system/memory/memory_ramdisk_mount/
```

## Script Index

- `organize/multimedia/organize_photos_by_date`
  - Script: `organize_photos_by_date.sh`
  - Docs: `scripts/organize/multimedia/organize_photos_by_date/README.md`
- `server/hardware/hardware_amdgpu_firmware_update`
  - Script: `hardware_amdgpu_firmware_update.sh`
  - Docs: `scripts/server/hardware/hardware_amdgpu_firmware_update/README.md`
- `server/hardware/hardware_cpu_find_best_core`
  - Script: `hardware_cpu_find_best_core.sh`
  - Docs: `scripts/server/hardware/hardware_cpu_find_best_core/README.md`
- `server/security/security_ips_collect_suspicious`
  - Script: `security_ips_collect_suspicious.sh`
  - Docs: `scripts/server/security/security_ips_collect_suspicious/README.md`
- `system/filesystem/files_cat_by_round`
  - Script: `files_cat_by_round.sh`
  - Docs: `scripts/system/filesystem/files_cat_by_round/README.md`
- `system/filesystem/files_compare_meaningful_diff`
  - Script: `files_compare_meaningful_diff.sh`
  - Docs: `scripts/system/filesystem/files_compare_meaningful_diff/README.md`
- `system/memory/memory_ramdisk_mount`
  - Script: `memory_ramdisk_mount.sh`
  - Docs: `scripts/system/memory/memory_ramdisk_mount/README.md`

## Notes

- Review each script README before running in production.
- Some scripts require root privileges and/or system-specific tools.
