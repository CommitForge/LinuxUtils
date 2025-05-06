
---

# 📷 Photo Organizer Script

**Organize photos by capture date using EXIF metadata**

---

## 📄 Description

This Bash script organizes photos by extracting their **capture date** using `exiftool`, then copying them into date-based folders (structured as `YYYY/MM/DD`). It prevents duplicate file copies by comparing file hashes and supports multiple image formats.

When metadata is missing, the script looks for a matching file (same base name, different extension) in the same folder, following a priority order defined in the `FILE_TYPES` array. If no valid date is found, the file is skipped.

The script **does not modify the source folder** and can be run safely multiple times on the same data set.

---

## ✅ Features

* 📅 Organizes photos into `YYYY/MM/DD` folder structure
* 🔍 Extracts `DateTimeOriginal` metadata using `exiftool`
* 🔁 Fallback search for alternate formats if metadata is missing
* 🧠 Duplicate detection via SHA1 hash comparison
* 🚀 Efficient file transfers using `rsync`
* 🛠 Supports customizable file types (`nef`, `jpeg`, `jpg` by default)

---

## 💡 Practical Use Case

> “I had thousands of disorganized photos from my mirrorless camera. This script helped me sort them into folders by the day they were taken. Now everything is tidy and searchable!”

---

## 📦 Requirements

Ensure the following tools are installed:

* [`exiftool`](https://exiftool.org/)
* `rsync`
* `sha1sum` (included in most Unix-like systems)

### Install on Debian/Ubuntu:

```sh
sudo apt install libimage-exiftool-perl rsync
```

### Install on macOS:

```sh
brew install exiftool rsync
```

---

## 🛠 Installation

1. Download or copy the script to a directory of your choice.
2. Make it executable:

```sh
chmod +x organize_photos_by_date.sh
```

---

## 🚀 Usage

1. Open the script and set the correct paths:

   ```sh
   SOURCE_FOLDER="/path/to/source_folder"
   TARGET_FOLDER="/path/to/target_folder"
   ```

2. Run the script:

   ```sh
   ./organize_photos_by_date.sh
   ```

⏳ **Note:** The script may take time with large photo collections due to hash calculations.

---

## 🧩 Customization

* **Add/Remove file types** by modifying the array:

  ```sh
  FILE_TYPES=("nef" "jpeg" "jpg")
  ```

* **Adjust folder paths** for your source and target directories:

  ```sh
  SOURCE_FOLDER="/your/source"
  TARGET_FOLDER="/your/target"
  ```

---

## 🔁 Example Workflow

1. Finds `IMG_1234.NEF` in `/photos/raw/`
2. Extracts date `2024/01/15` using `exiftool`
3. If metadata is missing, checks for `IMG_1234.JPG`
4. Creates folder `/sorted_photos/2024/01/15/`
5. Copies photo to `/sorted_photos/2024/01/15/IMG_1234.NEF`
6. If duplicate is found (same content), it is skipped

---

## 🛠 Troubleshooting

* ❌ **Exiftool not found?**

  ```sh
  which exiftool
  ```

  Make sure it's installed and in your `PATH`.

* ⚠️ **Permission issues?**

  ```sh
  chmod +x organize_photos_by_date.sh
  ```

* 🐞 **Debug mode:**

  ```sh
  bash -x organize_photos_by_date.sh
  ```

---

## ⚠️ Notes

This script was created and tested on **Linux**.
It may require adjustments for other systems (e.g., Windows, BSD).

> **Disclaimer:** Use at your own risk. No warranty or liability for damages.

---

