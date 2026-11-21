# m4-2-number-guard — every number in a reply must come from the engine's result

ZAD_OR_PLAN م٤.٢ (the pure check only; wiring into the brain is a later slice). Pure TypeScript (Deno), no DB, no
network, no imports except `jsr:@std/assert@1` in the test.

## Files you may edit (only these, both new)
- supabase/functions/_shared/or/numberGuard.ts
- supabase/functions/_shared/or/numberGuard_test.ts

## Do
Style to copy: supabase/functions/_shared/or/attentionBudget.ts and attentionBudget_test.ts.

Replies are Egyptian/Gulf Arabic and may use Arabic-Indic digits (٠١٢٣٤٥٦٧٨٩), Persian digits (۰-۹), Western digits,
the Arabic decimal separator «٫», the Arabic thousands separator «٬», a Western comma as thousands separator ("1,250"),
a dot decimal, and a percent sign (% or ٪).

Exports, exactly these:
- `export function extractNumbers(text: string): number[]` — every number in the text, in order, normalised to JS
  numbers. "١٬٢٥٠٫٥" → 1250.5, "1,250" → 1250, "٣٥٪" → 35, "2.5" → 2.5. A digit run glued to letters that is clearly an
  identifier (e.g. "B12", "iPhone15") is NOT a number: require the run to be bounded by non-letter characters (Arabic or
  Latin letters both count as letters). Dates "2026-11-22" give 2026, 11, 22 (three numbers).
- `export interface GuardResult { ok: boolean; unknown: number[] }`
- `export function checkNumbers(reply: string, allowed: readonly number[], opts?: { tolerance?: number; free?: readonly number[] }): GuardResult`
  ok when every extracted number n matches some allowed a with |n − a| <= max(tolerance·|a|, 0.5) (tolerance default
  0.01), or n is in `free`. Default free = [0, 1, 2, 3, 7, 14, 24, 30, 100] (counts and units people say naturally).
  `unknown` = the numbers that matched nothing, in order, without duplicates.
  Rounding the reply does: allowed 1249.6 and reply "1250" passes (within 0.5); allowed 12.34 and reply "12" fails
  unless within tolerance.

## Tests (each its own Deno.test)
1. extractNumbers on "فاضلك ١٬٢٥٠٫٥ جنيه و٣٥٪ من الميزانية" → [1250.5, 35].
2. Western/Persian mix: "spent 1,250 and ۴۰ today" → [1250, 40].
3. Identifiers are not numbers: "فيتامين B12 و iPhone15" → [].
4. A date gives three numbers.
5. checkNumbers passes when all numbers are allowed or free; reports the invented one otherwise
   (allowed [1250.5, 35], reply "١٢٥٠ و٣٥٪ و٩٩٩" → ok false, unknown [999]).
6. Tolerance: allowed [1000], reply "1005" passes at default (10 ≥ 5), "1020" fails.
7. No numbers in the reply → ok true, unknown [].

## Don't
- commit, push, merge; edit any other file; add dependencies; touch zad-brain or SQL.

## Done means (run from the repo root, paste the last lines)
- deno check supabase/functions/_shared/or/numberGuard.ts
- deno test -A supabase/functions/_shared/or/numberGuard_test.ts
