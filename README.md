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
