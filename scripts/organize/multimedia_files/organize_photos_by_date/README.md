# Photo Organizer Script

## Description
This Bash script organizes photos by extracting their capture date using `exiftool` and copying them into date-based folders. It ensures that duplicate files are not copied by comparing hashes and prioritizes specific file types.

The script processes image files by extracting the `DateTimeOriginal` metadata. If this metadata is missing, it attempts to find another file with the same base name but a different extension, following the order of extensions specified in the `FILE_TYPES` array (e.g., it will check for a `.jpeg` if the `.nef` is missing metadata). If no date is found from any matching files, the file is skipped and not organized.

If multiple files with the same name exist in the source folder, the script appends a counter to the filename to ensure uniqueness, preventing any file from being overwritten in the target folder.

## Features
- Automatically extracts the `DateTimeOriginal` metadata from images.
- Searches for alternative files with the same base name if metadata is missing.
- Sorts files into `YYYY/MM/DD` structured folders.
- Supports multiple file types (`nef`, `jpeg`, `jpg` by default, customizable).
- Prevents duplicate file copies using SHA1 hashes.
- Uses `rsync` for efficient file transfers.

## Requirements
- `exiftool` (Install via `sudo apt install libimage-exiftool-perl` on Debian/Ubuntu or `brew install exiftool` on macOS)
- `rsync`
- `sha1sum`

## Installation
1. Install required dependencies:
   ```sh
   sudo apt install libimage-exiftool-perl rsync  # Debian/Ubuntu
   brew install exiftool rsync  # macOS
   ```
2. Copy the script to a preferred location.
3. Make the script executable:
   ```sh
   chmod +x organize_photos_by_date.sh
   ```

## Usage
1. Update the script with the correct source and target directories:
   ```sh
   SOURCE_FOLDER="/path/to/source_folder"
   TARGET_FOLDER="/path/to/target_folder"
   ```
2. Run the script:
   ```sh
   ./organize_photos_by_date.sh
   ```
   If there are a lot of files, the script takes some time to execute, since it has to calculate all the hashes.

## Customization
- Modify the `FILE_TYPES` array to add or remove supported file extensions.
   ```sh
   FILE_TYPES=("nef" "jpeg" "jpg")
   ```
- Adjust the `SOURCE_FOLDER` and `TARGET_FOLDER` paths as needed.

## Example Workflow
1. A photo `IMG_1234.NEF` is found in `/photos/raw/`.
2. `exiftool` extracts the date `2024/01/15` from its metadata.
3. If metadata is missing, the script searches for an alternative file like `IMG_1234.JPG` and extracts the date from that file.
4. If no date is found from any matching file, the file is skipped.
5. The script creates the folder `/sorted_photos/2024/01/15/`.
6. The photo is copied to `/sorted_photos/2024/01/15/IMG_1234.NEF`.
7. If a duplicate exists, the script skips copying it.

## Troubleshooting
- If `exiftool` is not found, install it and check if it's in your `PATH`:
  ```sh
  which exiftool
  ```
- Ensure the script has the correct permissions (`chmod +x organize_photos_by_date.sh`).
- Run the script with `bash -x organize_photos_by_date.sh` for debugging.

## Notes
This script was created and used on Linux. Not tested for other systems.
I provide no warranty and take no responsibility for using the script or using the provided instructions in any way.
