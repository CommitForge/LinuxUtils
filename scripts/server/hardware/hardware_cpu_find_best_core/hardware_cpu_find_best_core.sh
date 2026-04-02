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
AMD_FAMILY="N/A"
AMD_FAMILY_LABEL="N/A"

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
    AMD_FAMILY="AMD_UNKNOWN_FAMILY"
    AMD_FAMILY_LABEL="AMD family not confidently detected"

    series=$(echo "$MODEL_NAME" | grep -Eo '[0-9]{4,5}' | head -n1 || true)

    # Order matters: Threadripper model strings usually contain "Ryzen".
    if [[ "$MODEL_NAME" =~ [Tt]hreadripper && -n "$series" ]]; then
        AMD_FAMILY="THREADRIPPER"
        AMD_FAMILY_LABEL="Threadripper family"
        generation="${series:0:1}"
        set_amd_profile_by_generation "$generation" "Threadripper"
        AMD_PROFILE_SOURCE="Detected Threadripper series $series"
    elif [[ "$MODEL_NAME" =~ [Ee][Pp][Yy][Cc] && -n "$series" ]]; then
        AMD_FAMILY="EPYC"
        AMD_FAMILY_LABEL="EPYC family"
        generation="${series:0:1}"
        set_amd_profile_by_generation "$generation" "EPYC"
        AMD_PROFILE_SOURCE="Detected EPYC series $series"
    elif [[ "$MODEL_NAME" =~ [Rr]yzen && -n "$series" ]]; then
        AMD_FAMILY="RYZEN"
        AMD_FAMILY_LABEL="Ryzen consumer family"
        generation="${series:0:1}"
        set_amd_profile_by_generation "$generation" "Ryzen"
        AMD_PROFILE_SOURCE="Detected Ryzen series $series"
    elif [[ "$MODEL_NAME" =~ [Tt]hreadripper ]]; then
        AMD_FAMILY="THREADRIPPER"
        AMD_FAMILY_LABEL="Threadripper family"
    elif [[ "$MODEL_NAME" =~ [Ee][Pp][Yy][Cc] ]]; then
        AMD_FAMILY="EPYC"
        AMD_FAMILY_LABEL="EPYC family"
    elif [[ "$MODEL_NAME" =~ [Rr]yzen ]]; then
        AMD_FAMILY="RYZEN"
        AMD_FAMILY_LABEL="Ryzen consumer family"
    fi
fi

compute_percentiles() {
    local file="$1"
    local count="$2"

    if (( count <= 0 )); then
        echo "0 0 0"
        return
    fi

    sort -n "$file" | awk -v c="$count" '
        BEGIN {
            # Use a (c-1)-based rank so short runs do not collapse P95/P99 to raw max.
            r50 = int((50 * (c - 1)) / 100) + 1
            r95 = int((95 * (c - 1)) / 100) + 1
            r99 = int((99 * (c - 1)) / 100) + 1

            if (r50 < 1) r50 = 1
            if (r95 < 1) r95 = 1
            if (r99 < 1) r99 = 1
        }
        NR == r50 { p50 = $1 }
        NR == r95 { p95 = $1 }
        NR == r99 { p99 = $1 }
        END {
            if (p50 == "") p50 = 0
            if (p95 == "") p95 = 0
            if (p99 == "") p99 = 0
            print p50, p95, p99
        }
    '
}

classify_reliability() {
    local spike_khz="$1"
    if (( spike_khz <= 25000 )); then
        echo "HIGH"
    elif (( spike_khz <= 75000 )); then
        echo "MED"
    else
        echo "LOW"
    fi
}

get_curve_range() {
    local profile="$1"
    local rank_idx="$2" # zero-based

    case "$profile" in
        RYZEN_9000_PLUS)
            if (( rank_idx < 2 )); then
                echo "-10 to -20"
            elif (( rank_idx < 6 )); then
                echo "-15 to -25"
            else
                echo "-20 to -30"
            fi
            ;;
        RYZEN_7000_8000)
            if (( rank_idx < 2 )); then
                echo "-8 to -15"
            elif (( rank_idx < 6 )); then
                echo "-12 to -20"
            else
                echo "-15 to -25"
            fi
            ;;
        RYZEN_5000_6000)
            if (( rank_idx < 2 )); then
                echo "-5 to -10"
            elif (( rank_idx < 6 )); then
                echo "-10 to -15"
            else
                echo "-12 to -20"
            fi
            ;;
        *)
            if (( rank_idx < 2 )); then
                echo "-5 to -10"
            elif (( rank_idx < 6 )); then
                echo "-8 to -12"
            else
                echo "-10 to -15"
            fi
            ;;
    esac
}

echo "Detected platform: $PLATFORM"
echo "Detected CPU model: ${MODEL_NAME:-unknown}"
if [[ "$PLATFORM" == "AMD" ]]; then
    echo "Detected AMD tuning profile: $AMD_PROFILE_LABEL"
    echo "Detected AMD family: $AMD_FAMILY_LABEL"
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
declare -a avg_freq
declare -a p50_freq
declare -a p95_freq
declare -a p99_freq
declare -a spike_gap
declare -a sample_files
declare -a freq_paths
declare -a freq_sources

cpufreq_paths_found=0
hw_freq_paths_found=0

TMP_DIR=$(mktemp -d -t hardware_cpu_find_best_core.XXXXXX)
cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

for ((i=0; i<THREADS; i++)); do
    max_freq[$i]=0
    sum_freq[$i]=0
    samples[$i]=0
    avg_freq[$i]=0
    p50_freq[$i]=0
    p95_freq[$i]=0
    p99_freq[$i]=0
    spike_gap[$i]=0

    sample_files[$i]="$TMP_DIR/cpu${i}.samples"
    : > "${sample_files[$i]}"

    hw_path="/sys/devices/system/cpu/cpu$i/cpufreq/cpuinfo_cur_freq"
    req_path="/sys/devices/system/cpu/cpu$i/cpufreq/scaling_cur_freq"

    if [ -r "$hw_path" ]; then
        freq_paths[$i]="$hw_path"
        freq_sources[$i]="cpuinfo_cur_freq"
        cpufreq_paths_found=$((cpufreq_paths_found + 1))
        hw_freq_paths_found=$((hw_freq_paths_found + 1))
    elif [ -r "$req_path" ]; then
        freq_paths[$i]="$req_path"
        freq_sources[$i]="scaling_cur_freq"
        cpufreq_paths_found=$((cpufreq_paths_found + 1))
    else
        freq_paths[$i]=""
        freq_sources[$i]="none"
    fi
done

if (( cpufreq_paths_found == 0 )); then
    echo "Error: no readable cpufreq scaling files were found for any CPU thread."
    echo "Suggestion: ensure CPU frequency scaling is exposed at /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq."
    echo "Suggestion: if unavailable on this platform, use a vendor-specific telemetry tool and interpret ranking manually."
    exit 1
fi

echo "Telemetry sources:"
echo "- cpuinfo_cur_freq available on $hw_freq_paths_found/$THREADS threads (hardware-reported when exposed)."
echo "- scaling_cur_freq fallback used on $((cpufreq_paths_found - hw_freq_paths_found))/$THREADS threads (request/approx on many systems)."
echo ""

END_TIME=$(($(date +%s) + DURATION))

while [ "$(date +%s)" -lt "$END_TIME" ]; do
    for ((i=0; i<THREADS; i++)); do
        path="${freq_paths[$i]}"

        if [[ -n "$path" ]] && f=$(cat "$path" 2>/dev/null); then
            if [[ "$f" =~ ^[0-9]+$ ]]; then
                (( f > max_freq[$i] )) && max_freq[$i]=$f
                sum_freq[$i]=$(( sum_freq[$i] + f ))
                samples[$i]=$(( samples[$i] + 1 ))
                printf "%s\n" "$f" >> "${sample_files[$i]}"
            fi
        fi
    done
    sleep "$INTERVAL"
done

for ((i=0; i<THREADS; i++)); do
    if (( samples[$i] > 0 )); then
        avg_freq[$i]=$(( sum_freq[$i] / samples[$i] ))
        read -r p50_freq[$i] p95_freq[$i] p99_freq[$i] < <(compute_percentiles "${sample_files[$i]}" "${samples[$i]}")
        spike_gap[$i]=$(( max_freq[$i] - p99_freq[$i] ))
    fi
done

echo "=== THREAD DATA ==="
printf "%-6s %-5s %-12s %-12s %-12s %-12s %-12s %-14s %-10s\n" \
    "CPU" "SRC" "MAX(kHz)" "AVG(kHz)" "P95(kHz)" "P99(kHz)" "MED(kHz)" "SPIKE_GAP(MHz)" "SAMPLES"
echo "------------------------------------------------------------------------------------------------------"

for ((i=0; i<THREADS; i++)); do
    if [[ "${freq_sources[$i]}" == "cpuinfo_cur_freq" ]]; then
        src="HW"
    elif [[ "${freq_sources[$i]}" == "scaling_cur_freq" ]]; then
        src="REQ"
    else
        src="NA"
    fi

    spike_mhz=$(( spike_gap[$i] / 1000 ))
    printf "%-6d %-5s %-12d %-12d %-12d %-12d %-12d %-14d %-10d\n" \
        "$i" "$src" "${max_freq[$i]}" "${avg_freq[$i]}" "${p95_freq[$i]}" "${p99_freq[$i]}" "${p50_freq[$i]}" "$spike_mhz" "${samples[$i]}"
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

declare -a core_rep_thread
declare -a core_max
declare -a core_avg
declare -a core_p95
declare -a core_p99
declare -a core_median
declare -a core_spike
declare -a core_score

for ((c=0; c<CORES; c++)); do
    core_rep_thread[$c]=-1
    core_max[$c]=0
    core_avg[$c]=0
    core_p95[$c]=0
    core_p99[$c]=0
    core_median[$c]=0
    core_spike[$c]=0
    core_score[$c]=0

    best_thread=-1
    for t in ${core_threads[$c]}; do
        if (( samples[$t] == 0 )); then
            continue
        fi

        if (( best_thread < 0 )); then
            best_thread=$t
        elif (( p95_freq[$t] > p95_freq[$best_thread] )); then
            best_thread=$t
        elif (( p95_freq[$t] == p95_freq[$best_thread] && p99_freq[$t] > p99_freq[$best_thread] )); then
            best_thread=$t
        elif (( p95_freq[$t] == p95_freq[$best_thread] && p99_freq[$t] == p99_freq[$best_thread] && avg_freq[$t] > avg_freq[$best_thread] )); then
            best_thread=$t
        fi
    done

    if (( best_thread >= 0 )); then
        core_rep_thread[$c]=$best_thread
        core_max[$c]=${max_freq[$best_thread]}
        core_avg[$c]=${avg_freq[$best_thread]}
        core_p95[$c]=${p95_freq[$best_thread]}
        core_p99[$c]=${p99_freq[$best_thread]}
        core_median[$c]=${p50_freq[$best_thread]}
        core_spike[$c]=${spike_gap[$best_thread]}
        core_score[$c]=$(( (core_p95[$c] * 50 + core_p99[$c] * 30 + core_avg[$c] * 20) / 100 ))
    fi
done

mapfile -t ranked < <(
    for ((c=0; c<CORES; c++)); do
        if (( core_rep_thread[$c] >= 0 )); then
            printf "%d %s %s %d %d %d %d %d %d %d\n" \
                "$c" \
                "${core_label_by_index[$c]}" \
                "${core_key_by_index[$c]}" \
                "${core_score[$c]}" \
                "${core_p95[$c]}" \
                "${core_p99[$c]}" \
                "${core_avg[$c]}" \
                "${core_max[$c]}" \
                "${core_spike[$c]}" \
                "${core_rep_thread[$c]}"
        fi
    done | sort -k4,4nr -k5,5nr -k6,6nr -k7,7nr
)

if (( ${#ranked[@]} == 0 )); then
    echo "No core data captured."
else
    read -r sustained_core _ _ best_score _ _ _ _ _ _ <<< "${ranked[0]}"

    peak_core=$sustained_core
    peak_max=-1
    avg_core=$sustained_core
    best_avg=-1
    for row in "${ranked[@]}"; do
        read -r core _ _ _ _ _ avg_khz max_khz _ _ <<< "$row"
        if (( avg_khz > best_avg )); then
            best_avg=$avg_khz
            avg_core=$core
        fi
        if (( max_khz > peak_max )); then
            peak_max=$max_khz
            peak_core=$core
        fi
    done

    printf "%-6s %-6s %-10s %-12s %-10s %-10s %-12s %-12s %-14s %-14s %-14s %-14s %-5s %-8s\n" \
        "RANK" "CORE" "TOPOLOGY" "SCORE(kHz)" "P95" "P99" "AVG_REF(kHz)" "MAX_REF(kHz)" "GAP_SCORE(MHz)" "GAP_AVG(MHz)" "GAP_MAX(MHz)" "SPIKE_GAP(MHz)" "REL" "REP_THR"
    echo "------------------------------------------------------------------------------------------------------------------------------------------------"

    for i in "${!ranked[@]}"; do
        read -r core core_label _ score p95 p99 avg max_khz spike_khz rep_thread <<< "${ranked[$i]}"
        gap_score_mhz=$(( (best_score - score) / 1000 ))
        gap_avg_mhz=$(( (best_avg - avg) / 1000 ))
        gap_max_mhz=$(( (peak_max - max_khz) / 1000 ))
        spike_mhz=$(( spike_khz / 1000 ))
        reliability=$(classify_reliability "$spike_khz")
        printf "%-6d %-6d %-10s %-12d %-10d %-10d %-12d %-12d %-14d %-14d %-14d %-14d %-5s %-8d\n" \
            "$((i + 1))" "$core" "$core_label" "$score" "$p95" "$p99" "$avg" "$max_khz" "$gap_score_mhz" "$gap_avg_mhz" "$gap_max_mhz" "$spike_mhz" "$reliability" "$rep_thread"
    done

    echo ""
    if (( sustained_core == peak_core )); then
        echo "Best sustained core and max-peak core are the same: CORE $sustained_core."
    else
        echo "Peak-only winner differs (CORE $peak_core has highest raw MAX, CORE $sustained_core has highest sustained SCORE)."
        echo "Using sustained SCORE avoids one-sample spikes deciding the ranking."
    fi
    if (( sustained_core != avg_core )); then
        echo "Highest average core differs from sustained-score winner (CORE $avg_core has highest AVG_REF)."
    fi
fi

# ===== AMD SPECIFIC =====
if [[ "$PLATFORM" == "AMD" && ${#ranked[@]} -gt 0 ]]; then
    echo ""
    echo "=== AMD TUNING SUGGESTIONS (FLUKE-RESISTANT) ==="
    echo "Profile: $AMD_PROFILE_LABEL"
    echo "Family: $AMD_FAMILY_LABEL"
    echo "Ranking math: SCORE = 50%*P95 + 30%*P99 + 20%*AVG (kHz)."
    echo "MAX(kHz) is reference-only, not used for rank."
    echo "Note: Boost Override CPU is usually global in PBO Advanced."
    echo "Note: Core ranking helps mainly for per-core Curve Optimizer ordering."
    echo ""

    printf "%-6s %-6s %-10s %-12s %-14s %-10s %-28s\n" "RANK" "CORE" "TOPOLOGY" "SCORE(kHz)" "CURVE" "REL" "NOTE"
    echo "----------------------------------------------------------------------------------------------------"

    for i in "${!ranked[@]}"; do
        read -r core core_label _ score _ _ _ _ spike_khz _ <<< "${ranked[$i]}"
        curve=$(get_curve_range "$AMD_PROFILE" "$i")
        reliability=$(classify_reliability "$spike_khz")

        if [[ "$reliability" == "LOW" ]]; then
            note="Spike-prone: start at mild end"
        elif [[ "$reliability" == "MED" ]]; then
            note="Use smaller CO step changes"
        else
            note="Normal step progression"
        fi

        printf "%-6d %-6d %-10s %-12d %-14s %-10s %-28s\n" "$((i + 1))" "$core" "$core_label" "$score" "$curve" "$reliability" "$note"
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

    boost_step=25
    if [[ "$AMD_FAMILY" == "RYZEN" ]]; then
        case "$AMD_PROFILE" in
            RYZEN_9000_PLUS|RYZEN_7000_8000)
                global_boost_start="+50"
                global_boost_range="+50 to +125"
                ;;
            RYZEN_5000_6000)
                global_boost_start="+50"
                global_boost_range="+50 to +100"
                ;;
            *)
                global_boost_start="+25"
                global_boost_range="+25 to +75"
                ;;
        esac
        boost_cap_note="Verified consumer-board ceiling is typically +200 MHz when this control is exposed."
        boost_doc_note="Examples: ASUS B550/A520 (AM4) and X670E (AM5) BIOS manuals."
        boost_action_note="If stable and thermals are acceptable, increase gradually; stop at first WHEA/error sign."
    elif [[ "$AMD_FAMILY" == "THREADRIPPER" ]]; then
        global_boost_start="+25"
        global_boost_range="+25 to +100"
        boost_cap_note="Do not assume a universal +200 cap on Threadripper."
        boost_doc_note="Documented board limits include +200 (sTR5) and +1000 (WRX80)."
        boost_action_note="Check your board BIOS maximum first, then tune in +25 MHz steps."
    elif [[ "$AMD_FAMILY" == "EPYC" ]]; then
        global_boost_start="N/A"
        global_boost_range="platform-dependent"
        boost_cap_note="EPYC platforms often expose different or restricted overclock controls."
        boost_doc_note="Use server-vendor BIOS documentation for exact limits."
        boost_action_note="Treat core ranking here as priority guidance only."
    else
        global_boost_start="+25"
        global_boost_range="+25 to +75"
        boost_cap_note="Unknown AMD family: cap is board/firmware dependent."
        boost_doc_note="Use BIOS limits shown on your specific platform."
        boost_action_note="Increase gradually with stability checks at each step."
    fi

    echo "=== GLOBAL FALLBACK SUGGESTIONS (NO PER-CORE CONTROLS) ==="
    echo "Curve Optimizer (All Cores): start ${global_curve_start}, test in ${global_curve_range}"
    if [[ "$global_boost_range" == "platform-dependent" ]]; then
        echo "Boost Override CPU (Global): platform-dependent (check BIOS availability and limits)."
    else
        echo "Boost Override CPU (Global): start ${global_boost_start} MHz, test in ${global_boost_range} MHz"
        echo "Boost Override stepping: increase by +${boost_step} MHz per step with stability checks."
    fi
    echo "$boost_cap_note"
    echo "$boost_doc_note"
    if [[ "$AMD_FAMILY" == "RYZEN" ]]; then
        echo "Ryzen Master reference profile commonly shows +100 MHz as a default AOC value."
    fi
    echo "$boost_action_note"
elif [[ "$PLATFORM" == "INTEL" ]]; then
    echo ""
    echo "=== INTEL GUIDANCE ==="
    echo "Use CORE ANALYSIS SCORE/P95/P99 first, not raw MAX alone."
    echo "Then tune multipliers/voltage conservatively in BIOS or Intel XTU with stress testing."
else
    echo ""
    echo "=== GENERIC GUIDANCE ==="
    echo "Platform is unknown. Use sustained SCORE/P95/P99 ranking for relative strength."
    echo "Apply manual, conservative tuning from your CPU vendor documentation."
fi

echo ""
echo "=== MEASUREMENT QUALITY CHECK ==="
if (( DURATION < 90 )); then
    echo "Suggestion: run for >=90s (preferably 120s) for stronger fluke rejection."
else
    echo "Duration check: OK for baseline fluke filtering."
fi
if awk "BEGIN { exit !($INTERVAL > 0.3) }"; then
    echo "Suggestion: interval <=0.2s captures short boost behavior more reliably."
else
    echo "Interval check: OK for boost sampling."
fi
if (( cpufreq_paths_found > hw_freq_paths_found )); then
    echo "Note: some threads used scaling_cur_freq fallback, which can be less exact than hardware-reported cpuinfo_cur_freq."
fi

echo ""
echo "DISCLAIMER: Tuning values are heuristic starting points only."
echo "Use at your own risk."
