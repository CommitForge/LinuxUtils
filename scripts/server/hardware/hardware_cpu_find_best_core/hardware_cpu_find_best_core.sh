#!/usr/bin/env bash

DURATION=${1:-30}        # total run time (seconds)
INTERVAL=${2:-0.2}       # sampling interval (seconds)

CORES=$(nproc)

declare -a max_freq
declare -a sum_freq
declare -a samples

# init arrays
for ((i=0; i<CORES; i++)); do
    max_freq[$i]=0
    sum_freq[$i]=0
    samples[$i]=0
done

echo "Sampling $CORES threads for $DURATION seconds (interval ${INTERVAL}s)..."

END_TIME=$(($(date +%s) + DURATION))

while [ "$(date +%s)" -lt "$END_TIME" ]; do
    for ((i=0; i<CORES; i++)); do
        path="/sys/devices/system/cpu/cpu$i/cpufreq/scaling_cur_freq"

        if [ -f "$path" ]; then
            f=$(cat "$path")

            if [[ "$f" =~ ^[0-9]+$ ]]; then
                # update max
                if [ "$f" -gt "${max_freq[$i]}" ]; then
                    max_freq[$i]=$f
                fi

                # update sum + samples
                sum_freq[$i]=$(( ${sum_freq[$i]} + f ))
                samples[$i]=$(( ${samples[$i]} + 1 ))
            fi
        fi
    done

    sleep "$INTERVAL"
done

echo ""
printf "%-6s %-12s %-12s %-12s\n" "CPU" "MAX(kHz)" "AVG(kHz)" "SAMPLES"
echo "-------------------------------------------------------------"

for ((i=0; i<CORES; i++)); do
    if [ "${samples[$i]}" -gt 0 ]; then
        avg=$(( ${sum_freq[$i]} / ${samples[$i]} ))
    else
        avg=0
    fi

    printf "%-6d %-12d %-12d %-12d\n" "$i" "${max_freq[$i]}" "$avg" "${samples[$i]}"
done
