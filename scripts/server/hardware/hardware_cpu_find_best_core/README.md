# hardware_cpu_find_best_core

Samples per-thread CPU frequency, ranks physical cores by observed peak clock, and prints optional AMD Curve Optimizer guidance.

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
| AMD | Thread/core ranking plus Curve Optimizer suggestion ranges |
| Intel | Thread/core ranking only |
| Unknown | Basic thread/core statistics |

## Output Sections

1. `THREAD DATA`
- Per-thread max and average observed frequency
- Number of samples per thread

2. `CORE ANALYSIS`
- Groups logical threads into physical cores
- Uses highest observed frequency per core
- Prints best-to-worst core ranking

3. `AMD Curve Optimizer Suggestions` (AMD only)
- Top 2 cores: `-5 to -10`
- Next 4 cores: `-10 to -15`
- Remaining cores: `-15 to -25`

## Important Notes

- Suggestions are starting ranges, not guaranteed stable values.
- Validate with proper stress tests before daily use.
- Results vary with thermals, scheduler decisions, and active workload.

## Limitations

- Requires Linux `cpufreq` exposure at `/sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq`.
- Core grouping assumes SMT pairs (`0/1`, `2/3`, ...). This may be inaccurate on some systems (for example hybrid or nonstandard topology).
- Single run snapshots can be noisy; run multiple times for better confidence.
