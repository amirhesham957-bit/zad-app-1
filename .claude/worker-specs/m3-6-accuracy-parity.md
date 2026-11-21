# m3-6-accuracy-parity — the TS accuracy formulas and the SQL weekly report give the same numbers

ZAD_OR_PLAN م٣.٦. The owner's weekly report is computed in SQL (`zad_forecast_ledger_weekly`, migration
supabase/migrations/20261122130000_forecast_ledger_weekly.sql); its header says the formulas are the ones in
`supabase/functions/_shared/or/forecastAccuracy.ts`. This slice adds the SQL's "evidence week" rule to TS and a test
that pins both to the same fixture. Pure TypeScript (Deno), no DB, no network.

## Files you may edit (only these)
- supabase/functions/_shared/or/forecastAccuracy.ts   (add only; do not change existing functions)
- supabase/functions/_shared/or/forecastAccuracy_parity_test.ts   (new)

## Do
Read forecastAccuracy.ts and supabase/sql/tests/forecast_ledger_weekly_test.sql first.

Add to forecastAccuracy.ts, exactly:
- `export const EVIDENCE_MIN_RECORDED = 3;`
- `export interface SettledWeek { predicted: number; actual: number; recorded: number }`
- `export function isEvidenceWeek(w: SettledWeek): boolean` — true when recorded >= EVIDENCE_MIN_RECORDED and actual > 0
  (the SQL rule: "a week needs 3+ recorded expenses and a non-zero actual to be evidence").
- `export function weeklySpendSummary(weeks: readonly SettledWeek[]): { settled: number; evidence: number; thin: number; wape: number | null; bias: number | null }`
  settled = weeks.length; evidence/thin split by isEvidenceWeek; wape and bias = the existing `wape()` / `bias()` over
  evidence weeks only, rounded to 3 decimals (null when there is no evidence week).

Test file, each its own Deno.test, using the in-window weekly_spend rows of the SQL fixture:
  {predicted 100, actual 80, recorded 5}, {100, 125, 4}, {90, 0, 0}, {50, 10, 1}
1. settled 4, evidence 2, thin 2.
2. wape 0.220 and bias -0.024 — the exact values the SQL test asserts ((20+25)/205 and (200−205)/205).
3. No evidence weeks (only the two thin rows) → wape null, bias null, evidence 0.
4. isEvidenceWeek: recorded 3 & actual 1 → true; recorded 2 → false; actual 0 → false.
5. The existing exports (mae, wape, bias, coverage, accuracyReport) still behave as before: re-run one known case from
   forecastAccuracy_test.ts and assert the same result.

## Don't
- commit, push, merge; edit any other file (not the SQL, not the migration); add dependencies; change existing functions.

## Done means (run from the repo root, paste the last lines)
- deno check supabase/functions/_shared/or/forecastAccuracy.ts
- deno test -A supabase/functions/_shared/or/forecastAccuracy_test.ts supabase/functions/_shared/or/forecastAccuracy_parity_test.ts
