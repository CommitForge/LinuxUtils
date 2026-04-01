# hardware_cpu_find_best_core

Samples per-thread CPU frequency, ranks physical cores by observed peak clock, and prints tuning guidance based on detected platform and CPU family.

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
| AMD | Thread/core ranking + Curve Optimizer ranges + `FREQ_INC(+MHz)` suggestions |
| Intel | Thread/core ranking + Intel-specific next-step guidance (no AMD CO values) |
| Unknown | Frequency data and ranking only + conservative generic guidance |

The script prints:

- Detected platform (`AMD`, `INTEL`, or `UNKNOWN`)
- Detected CPU model string
- Detected AMD tuning profile when platform is AMD

## AMD Profile Mapping (Ryzen 5000 Included, Plus Newer)

If AMD is detected, the script maps model families (Ryzen / Threadripper / EPYC) to tuning profiles:

- `5000/6000 class profile`
- `7000/8000 class profile`
- `9000+ class profile`
- `AMD fallback` (when model does not match known Ryzen/Threadripper patterns)

The output now also includes `Profile source` to show how mapping was chosen (for example detected series number).

For each core rank bucket, the script prints:

- `CURVE`: starting Curve Optimizer range
- `FREQ_INC(+MHz)`: per-core priority hint (higher for stronger cores)
- `Global Boost Override starting hint`: lowest per-core value, for BIOSes that only expose one global override

### Rank Buckets

- Top 2 cores
- Next 4 cores
- Remaining cores

## Output Sections

1. `PLATFORM INFO`
- Shows detected platform/model/profile
- Explains what to do when platform is not confidently detected

2. `THREAD DATA`
- Per-thread max and average observed frequency
- Number of samples per thread

3. `CORE ANALYSIS`
- Groups threads using CPU topology (`physical_package_id` + `core_id`) when available
- Falls back to pair grouping only if topology data is unavailable
- Uses highest observed frequency per core
- Prints best-to-worst ranking
- Adds `GAP_TO_BEST(MHz)` column
- Adds a `TOPOLOGY` column (for example `P0C3`)

4. `AMD Curve/Boost Suggestions` (AMD only)
- Includes newer-than-Ryzen-5000 profiles
- Keeps Ryzen 5000-class tuning fully supported
- Adds `FREQ_INC(+MHz)` column in output
- Includes `TOPOLOGY` column for easier BIOS matching
- Clarifies that Boost Override is commonly global in PBO Advanced

5. `INTEL GUIDANCE` or `GENERIC GUIDANCE` (non-AMD)
- Suggests safe next steps based on available data

## Notes

- Suggestions are heuristic starting points, not guaranteed stable values.
- Always validate with stress tests and monitor temperatures/errors.
- Results vary with thermals, firmware/BIOS behavior, scheduler decisions, and workload.
- Requires Linux `cpufreq` exposure via `/sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq`.

## Disclaimer

Use at your own risk.
