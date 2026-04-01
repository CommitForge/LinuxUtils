#!/usr/bin/env bash

set -euo pipefail

DIR=${1:-}
ROUND=${2:-}
PER_ROUND=${3:-12}

if [[ -z "$DIR" || -z "$ROUND" ]]; then
    echo "Usage: $0 <path> <round> [per_round]"
    echo "Example: $0 ./myfolder 2"
    exit 1
fi

if [[ ! -d "$DIR" ]]; then
    echo "Error: '$DIR' is not a directory"
    exit 1
fi

if ! [[ "$ROUND" =~ ^[0-9]+$ ]] || (( ROUND < 1 )); then
    echo "Error: round must be a positive integer"
    exit 1
fi

if ! [[ "$PER_ROUND" =~ ^[0-9]+$ ]] || (( PER_ROUND < 1 )); then
    echo "Error: per_round must be a positive integer"
    exit 1
fi

mapfile -t FILES < <(find "$DIR" -maxdepth 1 -type f -printf '%f\n' | sort)

START_INDEX=$(( (ROUND - 1) * PER_ROUND ))
END_INDEX=$(( START_INDEX + PER_ROUND - 1 ))

if (( START_INDEX >= ${#FILES[@]} )); then
    echo "No files in round $ROUND"
    exit 0
fi

for ((i=START_INDEX; i<=END_INDEX && i<${#FILES[@]}; i++)); do
    FILE_NAME=${FILES[$i]}
    FILE_PATH="$DIR/$FILE_NAME"

    echo
    echo "=============================="
    echo "FILE: $FILE_NAME"
    echo "=============================="
    cat "$FILE_PATH"
done
