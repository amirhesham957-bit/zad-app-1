# m3-2-rate-correction — one tap moves the pantry rate right away

ZAD_OR_PLAN م٣.٢ (the math only; the button and the event are a later slice). Pure TypeScript (Deno), no DB, no network,
no imports except `./tsb.ts` (type only) in the module and `jsr:@std/assert@1` in the test.

## Files you may edit (only these, both new)
- supabase/functions/_shared/or/rateCorrection.ts
- supabase/functions/_shared/or/rateCorrection_test.ts

## Do
Style to copy: supabase/functions/_shared/or/attentionBudget.ts and attentionBudget_test.ts (short doc comments,
`Deno.test`, `assertEquals` / `assertThrows` from "jsr:@std/assert@1"). Read supabase/functions/_shared/or/tsb.ts for
`ItemForecast` ({rate, low, high, basis, days}).

Exports, exactly these:
- `export const TAP_FACTOR = 1.3;`
- `export type Tap = "faster" | "slower";`
- `export function tapCorrection(f: ItemForecast, tap: Tap): ItemForecast`
  The customer says "it runs out faster/slower than you think". "faster" multiplies rate, low and high by TAP_FACTOR;
  "slower" divides them by it. basis and days unchanged. Round rate/low/high to 4 decimals. Throws RangeError for an
  unknown tap or a forecast with a negative / non-finite rate, low or high.
- `export function levelCorrection(f: ItemForecast, prevQty: number, prevAtMs: number, nowQty: number, nowMs: number): ItemForecast`
  The customer says how much is left now. Implied rate = (prevQty − nowQty) / elapsedDays.
  - If elapsed < 1 hour, or nowQty >= prevQty (a restock or no change), return f unchanged (same object values).
  - Otherwise new rate = (w·f.rate + elapsedDays·implied) / (w + elapsedDays) with w = max(f.days, 1).
    low/high keep their distance from the rate in proportion: low' = rate'·(f.low/f.rate), high' = rate'·(f.high/f.rate)
    (if f.rate is 0: low' = rate'·0.5, high' = rate'·1.5). days' = f.days + 1. basis' = "observed" if days' >= 14,
    else "blended". Round rate/low/high to 4 decimals.
  - Throws RangeError for negative or non-finite quantities, or nowMs < prevAtMs.

## Tests (each its own Deno.test)
1. faster then slower returns the original rate (within 4 decimals); low/high scale too; basis and days unchanged.
2. tapCorrection throws for tap "sideways" and for rate -1.
3. levelCorrection: f = {rate 1, low 0.5, high 1.5, basis "blended", days 6}, prevQty 10 two days ago, nowQty 4
   → implied 3, rate' = (6·1 + 2·3)/(6+2) = 1.5, low' 0.75, high' 2.25, days 7, basis "blended".
4. Less than an hour apart → unchanged. nowQty above prevQty (restock) → unchanged.
5. days reaching 14 → basis "observed".
6. f.rate 0 → band 0.5×/1.5× of the new rate.
7. Throws for prevQty -1, nowQty NaN, nowMs before prevAtMs.

## Don't
- commit, push, merge; edit any other file; add dependencies; touch zad-brain, zad-telegram-bot or SQL.

## Done means (run from the repo root, paste the last lines)
- deno check supabase/functions/_shared/or/rateCorrection.ts
- deno test -A supabase/functions/_shared/or/rateCorrection_test.ts
