#!/usr/bin/env bash

set -euo pipefail

DURATION=${1:-60}
INTERVAL=${2:-0.2}

if ! [[ "$DURATION" =~ ^[0-9]+$ ]] || (( DURATION < 1 )); then
    echo "Error: duration must be a positive integer (seconds)."
    exit 1
fi

if ! [[ "$INTERVAL" =~ ^([0-9]+([.][0-9]+)?|[.][0-9]+)$ ]]; then
    echo "Error: interval must be a positive number (seconds)."
    exit 1
fi

if ! awk "BEGIN { exit !($INTERVAL > 0) }"; then
    echo "Error: interval must be greater than zero."
    exit 1
fi

THREADS=$(nproc)

# Detect vendor + model for profile-specific hints.
VENDOR=$(grep -m1 "vendor_id" /proc/cpuinfo | awk '{print $3}')
MODEL_NAME=$(grep -m1 "model name" /proc/cpuinfo | cut -d: -f2- | sed 's/^ *//')

if [[ "$VENDOR" == "AuthenticAMD" ]]; then
    PLATFORM="AMD"
elif [[ "$VENDOR" == "GenuineIntel" ]]; then
    PLATFORM="INTEL"
else
    PLATFORM="UNKNOWN"
fi

AMD_PROFILE="N/A"
AMD_PROFILE_LABEL="N/A"

if [[ "$PLATFORM" == "AMD" ]]; then
    AMD_PROFILE="AMD_FALLBACK"
    AMD_PROFILE_LABEL="AMD generic fallback profile"

    if [[ "$MODEL_NAME" =~ [Rr]yzen[[:space:]]+[3579][[:space:]]+([0-9]{4,5}) ]]; then
        series="${BASH_REMATCH[1]}"
        generation="${series:0:1}"

        if (( generation >= 9 )); then
            AMD_PROFILE="RYZEN_9000_PLUS"
            AMD_PROFILE_LABEL="Ryzen 9000+"
        elif (( generation >= 7 )); then
            AMD_PROFILE="RYZEN_7000_8000"
            AMD_PROFILE_LABEL="Ryzen 7000/8000"
        elif (( generation == 5 )); then
            AMD_PROFILE="RYZEN_5000"
            AMD_PROFILE_LABEL="Ryzen 5000"
        else
            AMD_PROFILE="AMD_FALLBACK"
            AMD_PROFILE_LABEL="AMD older/other Ryzen fallback profile"
        fi
    elif [[ "$MODEL_NAME" =~ [Tt]hreadripper[[:space:]]+([0-9]{4,5}) ]]; then
        series="${BASH_REMATCH[1]}"
        generation="${series:0:1}"

        if (( generation >= 7 )); then
            AMD_PROFILE="RYZEN_7000_8000"
            AMD_PROFILE_LABEL="Threadripper 7000+ (mapped profile)"
        fi
    fi
fi

echo "Detected platform: $PLATFORM"
echo "Detected CPU model: ${MODEL_NAME:-unknown}"
if [[ "$PLATFORM" == "AMD" ]]; then
    echo "Detected AMD tuning profile: $AMD_PROFILE_LABEL"
elif [[ "$PLATFORM" == "INTEL" ]]; then
    echo "Intel detected: data is valid for ranking cores; AMD-specific tuning hints are skipped."
else
    echo "Platform not confidently detected: data is frequency observation only."
    echo "Suggestion: use core ranking for strong/weak core identification, then tune conservatively via vendor documentation."
fi
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
            f=$(<"$path")

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

# Assumes thread siblings are adjacent pairs: 0/1, 2/3, ...
CORES=$(( (THREADS + 1) / 2 ))

declare -a core_max

for ((c=0; c<CORES; c++)); do
    t1=$((c * 2))
    t2=$((c * 2 + 1))

    core_max[$c]=${max_freq[$t1]:-0}
    if (( t2 < THREADS )) && (( max_freq[$t2] > core_max[$c] )); then
        core_max[$c]=${max_freq[$t2]}
    fi
done

mapfile -t ranked < <(
    for ((c=0; c<CORES; c++)); do
        echo "$c ${core_max[$c]}"
    done | sort -k2 -nr
)

if (( ${#ranked[@]} == 0 )); then
    echo "No core data captured."
else
    read -r _ best_khz <<< "${ranked[0]}"

    printf "%-6s %-6s %-12s %-18s\n" "RANK" "CORE" "MAX(kHz)" "GAP_TO_BEST(MHz)"
    echo "-------------------------------------------------------------"

    for i in "${!ranked[@]}"; do
        read -r core max_khz <<< "${ranked[$i]}"
        gap_mhz=$(( (best_khz - max_khz) / 1000 ))
        printf "%-6d %-6d %-12d %-18d\n" "$((i + 1))" "$core" "$max_khz" "$gap_mhz"
    done
fi

# ===== AMD SPECIFIC =====
if [[ "$PLATFORM" == "AMD" && ${#ranked[@]} -gt 0 ]]; then
    echo ""
    echo "=== AMD Curve/Boost Suggestions ==="
    echo "Profile: $AMD_PROFILE_LABEL"
    echo "Note: FREQ_INC(+MHz) is a per-core target. If your BIOS supports only global boost override, start from the lowest value."

    declare -a curve
    declare -a freq_inc

    for i in "${!ranked[@]}"; do
        read -r core _ <<< "${ranked[$i]}"

        case "$AMD_PROFILE" in
            RYZEN_9000_PLUS)
                if (( i < 2 )); then
                    curve[$core]="-10 to -20"
                    freq_inc[$core]="+125"
                elif (( i < 6 )); then
                    curve[$core]="-15 to -25"
                    freq_inc[$core]="+175"
                else
                    curve[$core]="-20 to -30"
                    freq_inc[$core]="+200"
                fi
                ;;
            RYZEN_7000_8000)
                if (( i < 2 )); then
                    curve[$core]="-10 to -15"
                    freq_inc[$core]="+100"
                elif (( i < 6 )); then
                    curve[$core]="-15 to -25"
                    freq_inc[$core]="+150"
                else
                    curve[$core]="-20 to -30"
                    freq_inc[$core]="+200"
                fi
                ;;
            RYZEN_5000)
                if (( i < 2 )); then
                    curve[$core]="-5 to -10"
                    freq_inc[$core]="+50"
                elif (( i < 6 )); then
                    curve[$core]="-10 to -15"
                    freq_inc[$core]="+100"
                else
                    curve[$core]="-15 to -25"
                    freq_inc[$core]="+150"
                fi
                ;;
            *)
                if (( i < 2 )); then
                    curve[$core]="-5 to -10"
                    freq_inc[$core]="+50"
                elif (( i < 6 )); then
                    curve[$core]="-10 to -15"
                    freq_inc[$core]="+100"
                else
                    curve[$core]="-15 to -20"
                    freq_inc[$core]="+125"
                fi
                ;;
        esac
    done

    printf "%-6s %-6s %-12s %-14s %-14s\n" "RANK" "CORE" "MAX(kHz)" "CURVE" "FREQ_INC(+MHz)"
    echo "------------------------------------------------------------------"

    for i in "${!ranked[@]}"; do
        read -r core max_khz <<< "${ranked[$i]}"
        printf "%-6d %-6d %-12d %-14s %-14s\n" "$((i + 1))" "$core" "$max_khz" "${curve[$core]}" "${freq_inc[$core]}"
    done
elif [[ "$PLATFORM" == "INTEL" ]]; then
    echo ""
    echo "=== INTEL GUIDANCE ==="
    echo "Use CORE ANALYSIS to identify stronger cores first."
    echo "Then tune multipliers/voltage conservatively in BIOS or Intel XTU with stress testing."
else
    echo ""
    echo "=== GENERIC GUIDANCE ==="
    echo "Platform is unknown. Use thread/core ranking for relative strength only."
    echo "Apply manual, conservative tuning from your CPU vendor documentation."
fi

echo ""
echo "DISCLAIMER: Tuning values are heuristic starting points only."
echo "Use at your own risk."
