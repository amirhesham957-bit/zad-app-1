# m6-3-trend-spikes — a jump above the usual (الترند)

ZAD_OR_PLAN م٦.٣, the detector only (wiring is a later slice). Pure TypeScript (Deno), no DB, no network, no imports
except `jsr:@std/assert@1` in the test.

## Files you may edit (only these, both new)
- supabase/functions/_shared/or/trendSpikes.ts
- supabase/functions/_shared/or/trendSpikes_test.ts

## Do
Style to copy: supabase/functions/_shared/or/forecastAccuracy.ts and forecastAccuracy_test.ts.

Exports, exactly these:
- `export interface DaySignal { item: string; day: string; households: number }` — day is `YYYY-MM-DD`; households is
  how many distinct households showed the signal that day (already aggregated; no ids).
- `export interface Spike { item: string; today: number; mean: number; z: number }`
- `export interface SpikeOptions { baselineDays?: number; minHouseholds?: number; minZ?: number }` — defaults 28, 5, 3.
- `export function trendSpikes(signals: readonly DaySignal[], today: string, opts?: SpikeOptions): Spike[]`
  Per item: x = households on `today` (0 if absent). mean = sum of households over the `baselineDays` calendar days
  before today (today excluded; missing days count 0) / baselineDays. z = (x - mean) / sqrt(max(mean, 1)) (Poisson).
  Report only when x >= minHouseholds AND z >= minZ. Days after today are ignored. Several rows for the same item and
  day are summed. Sort by z desc, then item. Round nothing.
Validation (RangeError): bad date strings (must parse as a real UTC calendar date), negative or non-integer households,
baselineDays not an integer >= 1, minHouseholds < 1.

## Tests (each its own Deno.test)
1. Baseline 2 a day for 28 days, today 10 → mean 2, z = 8 / sqrt(2) ≈ 5.657, reported.
2. Today 4 with mean 0 → z 4 but below minHouseholds 5 → not reported (the five-house floor is a privacy rule).
3. Missing baseline days count as zero: only 14 days of 2 → mean 1.
4. Rows after `today` and outside the window do not change the mean.
5. Two rows for the same item and day are summed.
6. Sort: two spiking items come out z desc, ties by item.
7. Validation errors throw RangeError.
Use `assertAlmostEquals` for floats.

## Don't
- commit, push, merge; edit any other file; add dependencies; touch zad-brain or SQL.

## Done means (run from the repo root, paste the last lines)
- deno check supabase/functions/_shared/or/trendSpikes.ts
- deno test -A supabase/functions/_shared/or/trendSpikes_test.ts
