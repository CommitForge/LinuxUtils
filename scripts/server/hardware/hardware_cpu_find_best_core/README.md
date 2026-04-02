# hardware_cpu_find_best_core

Samples per-thread CPU frequency, ranks physical cores with fluke-resistant math, and prints tuning guidance based on detected platform and CPU family.

## Usage

```bash
chmod +x hardware_cpu_find_best_core.sh
./hardware_cpu_find_best_core.sh [duration_seconds] [interval_seconds]
```

Defaults:

- `duration_seconds`: `60`
- `interval_seconds`: `0.2`

Example:

```bash
./hardware_cpu_find_best_core.sh 90 0.1
```

## Platform Behavior

| Platform | Behavior |
|---|---|
| AMD | Thread/core ranking by sustained score + Curve Optimizer start ranges + global Boost Override guidance |
| Intel | Thread/core sustained ranking + Intel-specific next-step guidance (no AMD CO values) |
| Unknown | Sustained frequency data and ranking + conservative generic guidance |

The script prints:

- Detected platform (`AMD`, `INTEL`, or `UNKNOWN`)
- Detected CPU model string
- Detected AMD tuning profile and AMD family when platform is AMD

## AMD Profile Mapping (Ryzen 5000 Included, Plus Newer)

If AMD is detected, the script maps model families (Ryzen / Threadripper / EPYC) to tuning profiles:

- `5000/6000 class profile`
- `7000/8000 class profile`
- `9000+ class profile`
- `AMD fallback` (when model does not match known Ryzen/Threadripper patterns)

The output now also includes `Profile source` to show how mapping was chosen (for example detected series number).

For AMD, the script prints:

- `CURVE`: starting Curve Optimizer range by rank bucket
- `REL`: reliability level based on spike gap
- `TOPOLOGY`: package/core mapping label for BIOS matching

It also prints a dedicated global fallback block:

- Global Curve Optimizer (`All Cores`) start value and test range
- Global Boost Override (`CPU`) start value, test range, and `+25 MHz` step guidance
- Source-backed ceiling note by family:
  - Ryzen consumer platforms commonly expose up to `+200 MHz`
  - Threadripper can vary by platform (documented `+200` and `+1000` cases)
  - EPYC is platform/vendor-specific

### Rank Buckets

- Top 2 cores
- Next 4 cores
- Remaining cores

## Output Sections

1. `PLATFORM INFO`
- Shows detected platform/model/profile
- Explains what to do when platform is not confidently detected

2. `TELEMETRY SOURCES`
- Prefers `cpuinfo_cur_freq` (hardware-reported) when available
- Falls back to `scaling_cur_freq` when needed

3. `THREAD DATA`
- Per-thread `MAX`, `AVG`, `P95`, `P99`, `MED`, `SPIKE_GAP`, and samples
- `MAX` is reference-only; percentiles are used for fluke resistance

4. `CORE ANALYSIS`
- Groups threads using CPU topology (`physical_package_id` + `core_id`) when available
- Falls back to pair grouping only if topology data is unavailable
- Chooses a representative thread per core by `P95`/`P99`/`AVG`
- Ranks cores by sustained score:
  - `SCORE = 50% * P95 + 30% * P99 + 20% * AVG`
- Prints both `AVG_REF` and `MAX_REF` side by side for comparison
- Adds separate gaps in MHz for score, average, and max (`GAP_SCORE`, `GAP_AVG`, `GAP_MAX`)
- Explicitly warns when peak-only winner differs from sustained winner

5. `AMD TUNING SUGGESTIONS` (AMD only)
- Includes newer-than-Ryzen-5000 profiles
- Keeps Ryzen 5000-class tuning fully supported
- Removes per-core boost-MHz hints (unreliable on many boards)
- Clarifies that Boost Override is commonly global in PBO Advanced
- Adds family-aware Boost Override ceiling guidance (`Ryzen` vs `Threadripper` vs `EPYC`)
- Adds `REL` reliability indicator to avoid acting on spike-prone data
- Adds `GLOBAL FALLBACK SUGGESTIONS` with both global curve and global MHz guidance

6. `MEASUREMENT QUALITY CHECK`
- Flags short run duration and coarse intervals
- Warns when fallback telemetry (`scaling_cur_freq`) was required

7. `INTEL GUIDANCE` or `GENERIC GUIDANCE` (non-AMD)
- Suggests safe next steps based on sustained metrics

## Notes

- Suggestions are heuristic starting points, not guaranteed stable values.
- Always validate with stress tests and monitor temperatures/errors.
- Results vary with thermals, firmware/BIOS behavior, scheduler decisions, and workload.
- `scaling_cur_freq` can be approximate on many systems; use `cpuinfo_cur_freq` when available.
- `+200 MHz` should not be treated as universal across all AMD segments; check board BIOS limits.
- Requires Linux `cpufreq` exposure via `/sys/devices/system/cpu/cpu*/cpufreq/`.

## Source Notes

- ASUS B550/A520 BIOS manual (Ryzen 5000 era AM4) documents Boost Override values up to `200MHz`:  
  `https://dlcdnets.asus.com/pub/ASUS/misc/Manual/PRIME_TUF_GAMING_B550_Series_BIOS_EM_WEB_EN.pdf?model=PRIME+B550-PLUS`
- ASUS X670E BIOS manual (AM5) documents Boost Override values from `25` to `200`:  
  `https://dlcdnets.asus.com/pub/ASUS/mb/Socket%20AM5/ROG%20CROSSHAIR%20X670E%20EXTREME/E20466_ROG_CROSSHAIR_X670E_Series_BIOS_manual_EM_WEB.pdf`
- ASUS sTR5 BIOS manual documents Boost Override values from `25` to `200`:  
  `https://dlcdnets.asus.com/pub/ASUS/mb/SocketsTR5/Pro_WS_WRX90E-SAGE_SE/E22761_AMD_TR5_Series_BIOS_manual_EM_WEB.pdf?model=Pro+WS+TRX50-SAGE+WIFI`
- ASUS WRX80 BIOS manual documents Boost Override values from `25` to `1000`:  
  `https://dlcdnets.asus.com/pub/ASUS/mb/Socket%20sTRX4/PRO_WS_WRX80E-SAGE_SE_WIFI_II/E22244_PRO_WS_WRX80E-SAGE_SE_WIFI_II_BIOS_Manual_EM_V2_WEB.pdf`

## Disclaimer

Use at your own risk.
