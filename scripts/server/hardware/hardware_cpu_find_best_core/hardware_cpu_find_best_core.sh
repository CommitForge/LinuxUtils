#!/usr/bin/env bash

DURATION=${1:-30}        # seconds to run (default 30)
INTERVAL=0.2            # sampling interval (seconds)

CORES=$(nproc)
declare -a max_freq

# init
for ((i=0; i<CORES; i++)); do
    max_freq[$i]=0
done

echo "Sampling $CORES threads for $DURATION seconds..."

END_TIME=$(echo "$(date +%s) + $DURATION" | bc)

while [ "$(date +%s)" -lt "$END_TIME" ]; do
    for ((i=0; i<CORES; i++)); do
        f=$(cat /sys/devices/system/cpu/cpu$i/cpufreq/scaling_cur_freq 2>/dev/null)
        if [ -n "$f" ]; then
            if [ "$f" -gt "${max_freq[$i]}" ]; then
                max_freq[$i]=$f
            fi
        fi
    done
    sleep $INTERVAL
done

echo ""
echo "Max observed frequencies (kHz):"

for ((i=0; i<CORES; i++)); do
    echo "$i ${max_freq[$i]}"
done | sort -k2 -nr
