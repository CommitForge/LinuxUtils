#!/bin/bash

# START PARAMETERS ------------------------------------------------------------
SOURCE_FOLDER="/path/to/source_folder"
TARGET_FOLDER="/path/to/target_folder"

# Define the desired file extensions in priority order
FILE_TYPES=("nef" "jpeg" "jpg")

# Files larger than this are cached
LARGE_FILE_KB=102400   # 100 MB

HASH_CACHE="$TARGET_FOLDER/.hash_cache"
# END PARAMETERS --------------------------------------------------------------

# Check if exiftool is installed
if ! command -v exiftool &> /dev/null; then
    echo "Error: exiftool is not installed. Please install it to use this script."
    exit 1
fi

# Load cached hashes
declare -A hash_cache

if [[ -f "$HASH_CACHE" ]]; then
    while read -r hash path; do
        hash_cache["$path"]="$hash"
    done < "$HASH_CACHE"
fi

# Function to get hash with cache support
get_hash() {
    local file="$1"
    local size_kb=$(( $(stat -c%s "$file") / 1024 ))

    # Use cached hash for large files
    if (( size_kb > LARGE_FILE_KB )) && [[ -n "${hash_cache[$file]}" ]]; then
        echo "${hash_cache[$file]}"
        return
    fi

    local hash
    hash=$(sha1sum "$file" | awk '{print $1}')

    # Cache large-file hashes
    if (( size_kb > LARGE_FILE_KB )); then
        hash_cache["$file"]="$hash"
        echo "$hash $file" >> "$HASH_CACHE"
    fi

    echo "$hash"
}

# Function to get the DateTimeOriginal for a given file using exiftool
get_date_taken() {
    local file="$1"
    exiftool -d "%Y/%m/%d" -DateTimeOriginal -s -s -s "$file" 2>/dev/null
}

# Precompute hashes for all files in the target directory
declare -A target_hashes

while IFS= read -r -d '' target_file; do
    hash=$(get_hash "$target_file")
    target_hashes["$hash"]="$target_file"
done < <(find "$TARGET_FOLDER" -type f ! -name ".hash_cache" -print0)

# Process files in the source folder
find "$SOURCE_FOLDER" -type f \
\( -iname "*.${FILE_TYPES[0]}" \
$(for ext in "${FILE_TYPES[@]:1}"; do echo -o -iname "*.$ext"; done) \
\) -print0 |

while IFS= read -r -d '' FILE; do

    BASENAME=$(basename "$FILE" | sed -r "s/\.[^.]+$//")
    FILE_EXT="${FILE##*.}"

    # Attempt to get capture date
    DATE_TAKEN=$(get_date_taken "$FILE")
    echo "Date found for $FILE: $DATE_TAKEN"

    # Search alternative extensions if needed
    if [[ -z "$DATE_TAKEN" ]]; then
        for ext in "${FILE_TYPES[@]}"; do
            ALT_FILE=$(find "$SOURCE_FOLDER" \
                -type f \
                -iname "$BASENAME.$ext" \
                ! -path "$FILE" \
                -print0 |
                while IFS= read -r -d '' alt_file; do
                    echo "$alt_file"
                    break
                done)

            if [[ -n "$ALT_FILE" && "$ext" != "$FILE_EXT" ]]; then
                DATE_TAKEN=$(get_date_taken "$ALT_FILE")
                echo "Found alternative file: $ALT_FILE with date: $DATE_TAKEN"

                [[ -n "$DATE_TAKEN" ]] && break
            fi
        done
    fi

    # If a date is found, create target folder
    if [[ -n "$DATE_TAKEN" ]]; then

        TARGET_PATH="$TARGET_FOLDER/$DATE_TAKEN"
        mkdir -p "$TARGET_PATH"

        # Get source hash
        SOURCE_HASH=$(get_hash "$FILE")

        # Duplicate check
        if [[ -n "${target_hashes[$SOURCE_HASH]}" ]]; then
            echo "File $FILE matches existing file ${target_hashes[$SOURCE_HASH]} by hash; skipping copy."
            continue
        fi

        # Ensure unique filename
        TARGET_FILE="$TARGET_PATH/$(basename "$FILE")"

        COUNTER=1
        while [[ -e "$TARGET_FILE" ]]; do
            TARGET_FILE="$TARGET_PATH/$(basename "${FILE%.*}")_$COUNTER.${FILE##*.}"
            ((COUNTER++))
        done

        # Copy file
        rsync -a --ignore-existing "$FILE" "$TARGET_FILE"
        echo "Copied $FILE to $TARGET_FILE"

        # Add to in-memory hash table
        target_hashes["$SOURCE_HASH"]="$TARGET_FILE"

    else
        echo "No date found for $FILE or any alternative files; skipping."
    fi

done
