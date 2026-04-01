#!/usr/bin/env bash

DURATION=${1:-60}
INTERVAL=${2:-0.2}

THREADS=$(nproc)

# Detect vendor
VENDOR=$(grep -m1 "vendor_id" /proc/cpuinfo | awk '{print $3}')

if [[ "$VENDOR" == "AuthenticAMD" ]]; then
    PLATFORM="AMD"
elif [[ "$VENDOR" == "GenuineIntel" ]]; then
    PLATFORM="INTEL"
else
    PLATFORM="UNKNOWN"
fi

echo "Detected platform: $PLATFORM"
echo "Threads: $THREADS"
echo "Duration: $DURATION s | Interval: $INTERVAL s"
echo ""

declare -a max_freq
declare -a sum_freq
declare -a samples

for ((i=0; i<THREADS; i++)); do
    max_freq[$i]=0
    sum_freq[$i]=0
    samples[$i]=0
done

END_TIME=$(($(date +%s) + DURATION))

while [ "$(date +%s)" -lt "$END_TIME" ]; do
    for ((i=0; i<THREADS; i++)); do
        path="/sys/devices/system/cpu/cpu$i/cpufreq/scaling_cur_freq"

        if [ -f "$path" ]; then
            f=$(cat "$path")

            if [[ "$f" =~ ^[0-9]+$ ]]; then
                (( f > max_freq[$i] )) && max_freq[$i]=$f
                sum_freq[$i]=$(( sum_freq[$i] + f ))
                samples[$i]=$(( samples[$i] + 1 ))
            fi
        fi
    done
    sleep "$INTERVAL"
done

echo "=== THREAD DATA ==="
printf "%-6s %-12s %-12s %-10s\n" "CPU" "MAX(kHz)" "AVG(kHz)" "SAMPLES"
echo "-----------------------------------------------------------"

for ((i=0; i<THREADS; i++)); do
    if (( samples[$i] > 0 )); then
        avg=$(( sum_freq[$i] / samples[$i] ))
    else
        avg=0
    fi

    printf "%-6d %-12d %-12d %-10d\n" "$i" "${max_freq[$i]}" "$avg" "${samples[$i]}"
done

# ===== GROUP INTO CORES =====
echo ""
echo "=== CORE ANALYSIS ==="

CORES=$((THREADS / 2))

declare -a core_max

for ((c=0; c<CORES; c++)); do
    t1=$((c*2))
    t2=$((c*2+1))

    core_max[$c]=${max_freq[$t1]}
    (( max_freq[$t2] > core_max[$c] )) && core_max[$c]=${max_freq[$t2]}
done

# Print cores sorted by performance
echo "Core ranking (best first):"
for ((c=0; c<CORES; c++)); do
    echo "$c ${core_max[$c]}"
done | sort -k2 -nr

# ===== AMD SPECIFIC =====
if [[ "$PLATFORM" == "AMD" ]]; then
    echo ""
    echo "=== AMD Curve Optimizer Suggestions ==="

    # Rank cores
    mapfile -t ranked < <(
        for ((c=0; c<CORES; c++)); do
            echo "$c ${core_max[$c]}"
        done | sort -k2 -nr
    )

    declare -a curve

    for i in "${!ranked[@]}"; do
        core=$(echo "${ranked[$i]}" | awk '{print $1}')

        if (( i < 2 )); then
            curve[$core]="-5 to -10"
        elif (( i < 6 )); then
            curve[$core]="-10 to -15"
        else
            curve[$core]="-15 to -25"
        fi
    done

    printf "%-6s %-12s %-20s\n" "CORE" "MAX(kHz)" "CURVE"
    echo "----------------------------------------------"

    for ((c=0; c<CORES; c++)); do
        printf "%-6d %-12d %-20s\n" "$c" "${core_max[$c]}" "${curve[$c]}"
    done

else
    echo ""
    echo "Note: Curve Optimizer suggestions are AMD-specific and not applicable."
fi
