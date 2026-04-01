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

## AMD Profile Mapping (Includes Newer Than Ryzen 5000)

If AMD is detected, the script maps model name to a profile:

- `Ryzen 5000`
- `Ryzen 7000/8000`
- `Ryzen 9000+`
- `AMD fallback` (when model does not match known Ryzen/Threadripper patterns)

For each core rank bucket, the script prints:

- `CURVE`: starting Curve Optimizer range
- `FREQ_INC(+MHz)`: suggested frequency increase target per core

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
- Groups logical threads into core pairs (`0/1`, `2/3`, ...)
- Uses highest observed frequency per core
- Prints best-to-worst ranking
- Adds `GAP_TO_BEST(MHz)` column

4. `AMD Curve/Boost Suggestions` (AMD only)
- Includes newer-than-Ryzen-5000 profiles
- Adds `FREQ_INC(+MHz)` column in output

5. `INTEL GUIDANCE` or `GENERIC GUIDANCE` (non-AMD)
- Suggests safe next steps based on available data

## Notes

- Suggestions are heuristic starting points, not guaranteed stable values.
- Always validate with stress tests and monitor temperatures/errors.
- Results vary with thermals, firmware/BIOS behavior, scheduler decisions, and workload.

## Disclaimer

Use at your own risk.
