📘 README (clean + practical)
What this tool does
Samples per-thread frequency
Tracks:
max frequency
average frequency
sample count
Groups threads → physical cores
Ranks cores by performance
Platform awareness
Platform	Behavior
AMD	Full analysis + Curve Optimizer suggestions
Intel	Core ranking only (no CO suggestions)
Unknown	Basic stats only
Output sections
1. THREAD DATA

Raw per-thread stats
Useful for debugging and validation

2. CORE ANALYSIS
Combines SMT pairs into physical cores
Uses max observed frequency
Outputs ranking

👉 This is your true “best cores” list

3. AMD Curve Optimizer Suggestions

Only shown on AMD

Rank	Meaning	Curve
Top 2	Best cores	-5 to -10
Next 4	Strong	-10 to -15
Rest	Weak	-15 to -25
How to use results (important)

👉 Don’t blindly copy numbers.

Apply suggested ranges
Test stability
Adjust per core if needed
Limitations (don’t ignore)
No synthetic load → may miss peak boost
Results depend on:
background activity
thermal state
scheduler behavior

👉 For best results:

run while using system normally
or run multiple times and compare
Smart usage strategy

Don’t obsess over every core.

Focus on:

top 2 cores
worst 3–4 cores

That’s where 95% of performance tuning comes from.
