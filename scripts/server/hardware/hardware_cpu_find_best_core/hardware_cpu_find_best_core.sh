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
AMD_PROFILE_SOURCE="N/A"

set_amd_profile_by_generation() {
    local generation="$1"
    local family_label="$2"

    if (( generation >= 9 )); then
        AMD_PROFILE="RYZEN_9000_PLUS"
        AMD_PROFILE_LABEL="$family_label 9000+ class profile"
    elif (( generation >= 7 )); then
        AMD_PROFILE="RYZEN_7000_8000"
        AMD_PROFILE_LABEL="$family_label 7000/8000 class profile"
    elif (( generation >= 5 )); then
        AMD_PROFILE="RYZEN_5000_6000"
        AMD_PROFILE_LABEL="$family_label 5000/6000 class profile"
    else
        AMD_PROFILE="AMD_FALLBACK"
        AMD_PROFILE_LABEL="$family_label older/other fallback profile"
    fi
}

if [[ "$PLATFORM" == "AMD" ]]; then
    AMD_PROFILE="AMD_FALLBACK"
    AMD_PROFILE_LABEL="AMD generic fallback profile"
    AMD_PROFILE_SOURCE="Generic AMD fallback"

    series=$(echo "$MODEL_NAME" | grep -Eo '[0-9]{4,5}' | head -n1 || true)

    if [[ "$MODEL_NAME" =~ [Rr]yzen && -n "$series" ]]; then
        generation="${series:0:1}"
        set_amd_profile_by_generation "$generation" "Ryzen"
        AMD_PROFILE_SOURCE="Detected Ryzen series $series"
    elif [[ "$MODEL_NAME" =~ [Tt]hreadripper && -n "$series" ]]; then
        generation="${series:0:1}"
        set_amd_profile_by_generation "$generation" "Threadripper"
        AMD_PROFILE_SOURCE="Detected Threadripper series $series"
    elif [[ "$MODEL_NAME" =~ [Ee][Pp][Yy][Cc] && -n "$series" ]]; then
        generation="${series:0:1}"
        set_amd_profile_by_generation "$generation" "EPYC"
        AMD_PROFILE_SOURCE="Detected EPYC series $series"
    fi
fi

echo "Detected platform: $PLATFORM"
echo "Detected CPU model: ${MODEL_NAME:-unknown}"
if [[ "$PLATFORM" == "AMD" ]]; then
    echo "Detected AMD tuning profile: $AMD_PROFILE_LABEL"
    echo "Profile source: $AMD_PROFILE_SOURCE"
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

cpufreq_paths_found=0
for ((i=0; i<THREADS; i++)); do
    max_freq[$i]=0
    sum_freq[$i]=0
    samples[$i]=0

    if [ -f "/sys/devices/system/cpu/cpu$i/cpufreq/scaling_cur_freq" ]; then
        cpufreq_paths_found=$((cpufreq_paths_found + 1))
    fi
done

if (( cpufreq_paths_found == 0 )); then
    echo "Error: no readable cpufreq scaling files were found for any CPU thread."
    echo "Suggestion: ensure CPU frequency scaling is exposed at /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq."
    echo "Suggestion: if unavailable on this platform, use a vendor-specific telemetry tool and interpret ranking manually."
    exit 1
fi

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

declare -A core_index_by_key=()
declare -a core_key_by_index=()
declare -a core_label_by_index=()
declare -a core_threads=()
declare -a core_max=()

for ((i=0; i<THREADS; i++)); do
    pkg_path="/sys/devices/system/cpu/cpu$i/topology/physical_package_id"
    core_path="/sys/devices/system/cpu/cpu$i/topology/core_id"

    if [ -r "$pkg_path" ] && [ -r "$core_path" ]; then
        package_id=$(<"$pkg_path")
        core_id=$(<"$core_path")
    else
        package_id=""
        core_id=""
    fi

    if [[ "$package_id" =~ ^[0-9]+$ && "$core_id" =~ ^[0-9]+$ ]]; then
        key="pkg${package_id}:core${core_id}"
        label="P${package_id}C${core_id}"
    else
        pair_id=$((i / 2))
        key="pair${pair_id}"
        label="PAIR${pair_id}"
    fi

    if [[ -n "${core_index_by_key[$key]+x}" ]]; then
        index=${core_index_by_key[$key]}
    else
        index=${#core_key_by_index[@]}
        core_index_by_key[$key]=$index
        core_key_by_index[$index]="$key"
        core_label_by_index[$index]="$label"
        core_threads[$index]=""
        core_max[$index]=0
    fi

    if [[ -n "${core_threads[$index]}" ]]; then
        core_threads[$index]+=" $i"
    else
        core_threads[$index]="$i"
    fi
done

CORES=${#core_key_by_index[@]}

for ((c=0; c<CORES; c++)); do
    core_max[$c]=0
    for t in ${core_threads[$c]}; do
        (( max_freq[$t] > core_max[$c] )) && core_max[$c]=${max_freq[$t]}
    done
done

mapfile -t ranked < <(
    for ((c=0; c<CORES; c++)); do
        printf "%d %s %s %d\n" "$c" "${core_label_by_index[$c]}" "${core_key_by_index[$c]}" "${core_max[$c]}"
    done | sort -k4 -nr
)

if (( ${#ranked[@]} == 0 )); then
    echo "No core data captured."
else
    read -r _ _ _ best_khz <<< "${ranked[0]}"

    printf "%-6s %-6s %-10s %-12s %-18s\n" "RANK" "CORE" "TOPOLOGY" "MAX(kHz)" "GAP_TO_BEST(MHz)"
    echo "-----------------------------------------------------------------------"

    for i in "${!ranked[@]}"; do
        read -r core core_label _ max_khz <<< "${ranked[$i]}"
        gap_mhz=$(( (best_khz - max_khz) / 1000 ))
        printf "%-6d %-6d %-10s %-12d %-18d\n" "$((i + 1))" "$core" "$core_label" "$max_khz" "$gap_mhz"
    done
fi

# ===== AMD SPECIFIC =====
if [[ "$PLATFORM" == "AMD" && ${#ranked[@]} -gt 0 ]]; then
    echo ""
    echo "=== AMD Curve/Boost Suggestions ==="
    echo "Profile: $AMD_PROFILE_LABEL"
    echo "Note: Boost Override CPU is usually global in PBO Advanced."
    echo "Note: Per-core table below is priority guidance."

    declare -a curve
    declare -a freq_inc
    min_freq_inc=999999
    max_freq_inc=0

    for i in "${!ranked[@]}"; do
        read -r core _ _ _ <<< "${ranked[$i]}"

        case "$AMD_PROFILE" in
            RYZEN_9000_PLUS)
                if (( i < 2 )); then
                    curve[$core]="-10 to -20"
                    freq_inc[$core]="+200"
                elif (( i < 6 )); then
                    curve[$core]="-15 to -25"
                    freq_inc[$core]="+150"
                else
                    curve[$core]="-20 to -30"
                    freq_inc[$core]="+100"
                fi
                ;;
            RYZEN_7000_8000)
                if (( i < 2 )); then
                    curve[$core]="-10 to -15"
                    freq_inc[$core]="+150"
                elif (( i < 6 )); then
                    curve[$core]="-15 to -25"
                    freq_inc[$core]="+100"
                else
                    curve[$core]="-20 to -30"
                    freq_inc[$core]="+50"
                fi
                ;;
            RYZEN_5000_6000)
                if (( i < 2 )); then
                    curve[$core]="-5 to -10"
                    freq_inc[$core]="+100"
                elif (( i < 6 )); then
                    curve[$core]="-10 to -15"
                    freq_inc[$core]="+50"
                else
                    curve[$core]="-15 to -25"
                    freq_inc[$core]="+25"
                fi
                ;;
            *)
                if (( i < 2 )); then
                    curve[$core]="-5 to -10"
                    freq_inc[$core]="+50"
                elif (( i < 6 )); then
                    curve[$core]="-10 to -15"
                    freq_inc[$core]="+25"
                else
                    curve[$core]="-15 to -20"
                    freq_inc[$core]="+0"
                fi
                ;;
        esac

        freq_inc_num=${freq_inc[$core]#+}
        if (( freq_inc_num < min_freq_inc )); then
            min_freq_inc=$freq_inc_num
        fi
        if (( freq_inc_num > max_freq_inc )); then
            max_freq_inc=$freq_inc_num
        fi
    done

    printf "%-6s %-6s %-10s %-12s %-14s %-14s\n" "RANK" "CORE" "TOPOLOGY" "MAX(kHz)" "CURVE" "FREQ_INC(+MHz)"
    echo "----------------------------------------------------------------------------"

    for i in "${!ranked[@]}"; do
        read -r core core_label _ max_khz <<< "${ranked[$i]}"
        printf "%-6d %-6d %-10s %-12d %-14s %-14s\n" "$((i + 1))" "$core" "$core_label" "$max_khz" "${curve[$core]}" "${freq_inc[$core]}"
    done

    echo ""
    case "$AMD_PROFILE" in
        RYZEN_9000_PLUS)
            global_curve_start="-10"
            global_curve_range="-10 to -15"
            ;;
        RYZEN_7000_8000)
            global_curve_start="-10"
            global_curve_range="-10 to -15"
            ;;
        RYZEN_5000_6000)
            global_curve_start="-5"
            global_curve_range="-5 to -10"
            ;;
        *)
            global_curve_start="-5"
            global_curve_range="-5 to -10"
            ;;
    esac

    if (( min_freq_inc >= max_freq_inc )); then
        global_freq_start="+${min_freq_inc}"
        global_freq_range="+${min_freq_inc}"
    else
        global_freq_mid=$(( min_freq_inc + 25 ))
        if (( global_freq_mid > max_freq_inc )); then
            global_freq_mid=$max_freq_inc
        fi
        global_freq_start="+${min_freq_inc}"
        global_freq_range="+${min_freq_inc} to +${global_freq_mid}"
    fi

    echo "=== GLOBAL FALLBACK SUGGESTIONS (NO PER-CORE CONTROLS) ==="
    echo "Curve Optimizer (All Cores): start ${global_curve_start}, test in ${global_curve_range}"
    echo "Boost Override CPU (Global): start ${global_freq_start} MHz, test in ${global_freq_range} MHz"
    echo "If stable and thermals are acceptable, increase gradually in small steps."
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
