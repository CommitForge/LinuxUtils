#!/bin/bash

# START PARAMETERS ------------------------------------------------------------
# Set the source and target directories
SOURCE_FOLDER="/path/to/source_folder"   # Replace with your source folder path
TARGET_FOLDER="/path/to/target_folder"   # Replace with your target folder path

# Define the desired file extensions in priority order
FILE_TYPES=("nef" "jpeg" "jpg")          # Add other extensions as needed
# END PARAMETERS --------------------------------------------------------------

# Check if exiftool is installed
if ! command -v exiftool &> /dev/null; then
    echo "Error: exiftool is not installed. Please install it to use this script."
    exit 1
fi

# Function to get the DateTimeOriginal for a given file using exiftool
get_date_taken() {
    local file="$1"
    exiftool -d "%Y/%m/%d" -DateTimeOriginal -s -s -s "$file" 2>/dev/null
}

# Precompute hashes for all files in the target directory
declare -A target_hashes
while IFS= read -r -d '' target_file; do
    hash=$(sha1sum "$target_file" | awk '{print $1}')
    target_hashes["$hash"]="$target_file"
done < <(find "$TARGET_FOLDER" -type f -print0)

# Process files in the source folder
find "$SOURCE_FOLDER" -type f \( -iname "*.${FILE_TYPES[0]}" $(for ext in "${FILE_TYPES[@]:1}"; do echo -o -iname "*.$ext"; done) \) -print0 | while IFS= read -r -d '' FILE; do
    BASENAME=$(basename "$FILE" | sed -r "s/\.[^.]+$//")   # Extract the file name without extension
    FILE_EXT="${FILE##*.}"                                  # Get the current file extension

    # Attempt to get the capture date for the current file
    DATE_TAKEN=$(get_date_taken "$FILE")
    echo "Date found for $FILE: $DATE_TAKEN"
    
    # If no date is found, search for alternative files with the same base name
    if [[ -z "$DATE_TAKEN" ]]; then
        for ext in "${FILE_TYPES[@]}"; do
            ALT_FILE=$(find "$SOURCE_FOLDER" -type f -iname "$BASENAME.$ext" ! -path "$FILE" -print0 | while IFS= read -r -d '' alt_file; do echo "$alt_file"; break; done)
            if [[ -n "$ALT_FILE" && "$ext" != "$FILE_EXT" ]]; then
                DATE_TAKEN=$(get_date_taken "$ALT_FILE")
                echo "Found alternative file: $ALT_FILE with date: $DATE_TAKEN"
                [[ -n "$DATE_TAKEN" ]] && break  # Stop searching if a date is found
            fi
        done
    fi

    # If a date is found, create the corresponding folder structure
    if [[ -n "$DATE_TAKEN" ]]; then
        TARGET_PATH="$TARGET_FOLDER/$DATE_TAKEN"  # Define the target path based on the date
        mkdir -p "$TARGET_PATH"                    # Create target directory if it doesn't exist

        # Compute the hash of the source file
        SOURCE_HASH=$(sha1sum "$FILE" | awk '{print $1}')

        # Check if the file hash exists in the target directory
        if [[ -n "${target_hashes[$SOURCE_HASH]}" ]]; then
            echo "File $FILE matches existing file ${target_hashes[$SOURCE_HASH]} by hash; skipping copy."
            continue
        fi

        # Ensure a unique name in the target folder
        TARGET_FILE="$TARGET_PATH/$(basename "$FILE")"
        COUNTER=1
        while [[ -e "$TARGET_FILE" ]]; do
            TARGET_FILE="$TARGET_PATH/$(basename "${FILE%.*}")_$COUNTER.${FILE##*.}"
            ((COUNTER++))
        done

        # Copy the file
        rsync -a --ignore-existing "$FILE" "$TARGET_FILE"
        echo "Copied $FILE to $TARGET_FILE"

        # Add the new file's hash to the lookup table
        target_hashes["$SOURCE_HASH"]="$TARGET_FILE"
    else
        echo "No date found for $FILE or any alternative files; skipping."
    fi
done

