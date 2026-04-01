# memory_ramdisk_mount

Creates or removes a RAM disk using `tmpfs`.

## Usage

```bash
chmod +x memory_ramdisk_mount.sh
sudo ./memory_ramdisk_mount.sh <create|remove|umount> [mountpoint] [size]
```

- `mountpoint`: optional, default `./ramdisk`
- `size`: optional, used for `create`, default `1G`

## Examples

```bash
sudo ./memory_ramdisk_mount.sh create ./ramdisk 1G
sudo ./memory_ramdisk_mount.sh remove ./ramdisk
```

## Notes

- Data in a RAM disk is lost after reboot.
- Use this only when temporary, volatile storage is acceptable.
