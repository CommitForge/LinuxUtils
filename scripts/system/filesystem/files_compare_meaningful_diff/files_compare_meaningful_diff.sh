#!/usr/bin/env bash

set -euo pipefail

DIR1=${1:-}
DIR2=${2:-}

if [[ -z "$DIR1" || -z "$DIR2" ]]; then
    echo "Usage: $0 <folder_a> <folder_b>"
    exit 1
fi

if [[ ! -d "$DIR1" ]]; then
    echo "Error: '$DIR1' is not a directory"
    exit 1
fi

if [[ ! -d "$DIR2" ]]; then
    echo "Error: '$DIR2' is not a directory"
    exit 1
fi

diff -qr "$DIR1" "$DIR2" | awk '
/^Files / {
    print "DIFF: " $2 " <> " $4
    next
}
/^Only in / {
    sub(/^Only in /, "")
    split($0, parts, ": ")
    print "ONLY: " parts[1] "/" parts[2]
}
'
