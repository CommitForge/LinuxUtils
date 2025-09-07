# LinuxUtils

Utility files. Read individual README.md for chosen utility.

```.
.
├── README.md
└── scripts
    ├── organize
    │   └── multimedia
    │       └── organize_photos_by_date
    │           ├── organize_photos_by_date.sh
    │           └── README.md
    └── server
        └── security
            └── security_ips_collect_suspicious
                ├── README.md
                └── security_ips_collect_suspicious.sh

8 directories, 5 files

```
TODO:
compare 2 folders. make "meaningful" output:
```
diff -qr /home home/ | awk '/^Files/ {print $2, $4}'
```
Linux OS oneliner: create a 1gb ram disk in current folder:
```
# do
sudo mkdir -p ./ramdisk && sudo mount -t tmpfs -o size=1G tmpfs ./ramdisk
# undo
sudo umount ./ramdisk
```
Linux OS amdgpu firmware update:
```
# Backup old firmware
sudo cp -r /lib/firmware/amdgpu /lib/firmware/amdgpu.bak.$(date +%Y%m%d)

# Get latest firmware (shallow clone)
git clone --depth=1 https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git

# Copy new AMD GPU firmware
sudo cp linux-firmware/amdgpu/* /lib/firmware/amdgpu/

# Update initramfs
sudo update-initramfs -u -k all

# Reboot
#sudo reboot
```
