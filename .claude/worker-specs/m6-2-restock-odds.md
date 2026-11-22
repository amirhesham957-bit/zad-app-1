# m6-2-restock-odds — will this shop have this item? (الريستوك)

ZAD_OR_PLAN م٦.٢, the probability part only (alerts and wiring are a later slice). Pure TypeScript (Deno), no DB, no
network, no imports except `jsr:@std/assert@1` in the test.

## Files you may edit (only these, both new)
- supabase/functions/_shared/or/restockOdds.ts
- supabase/functions/_shared/or/restockOdds_test.ts

## Do
Style to copy: supabase/functions/_shared/or/pantryPriorities.ts and pantryPriorities_test.ts (RangeError validation,
deterministic ordering).

Exports, exactly these:
- `export interface Sighting { store: string; item: string; at: number; seen: boolean; weight?: number }` — `at` is
  epoch ms; `seen` true = the item was on the shelf (receipt, flyer, partner feed), false = reported missing. weight
  default 1. There is NO buyer/household field on purpose: who bought it is never kept.
- `export interface Odds { store: string; item: string; p: number; alpha: number; beta: number; evidence: number }`
- `export interface OddsOptions { halfLifeDays?: number; priorAlpha?: number; priorBeta?: number }` — defaults 14, 1, 1.
- `export function restockOdds(sightings: readonly Sighting[], now: number, opts?: OddsOptions): Odds[]`
  Beta per (store, item): start at (priorAlpha, priorBeta); each sighting adds `w = weight * 0.5 ** (ageDays / halfLifeDays)`
  (ageDays = (now - at) / 86_400_000) to alpha when seen, to beta when not. p = alpha / (alpha + beta);
  evidence = alpha + beta - priorAlpha - priorBeta. Sort by p desc, then store, then item (string compare).
- `export function shouldAlert(o: Odds, minP = 0.7, minEvidence = 2): boolean` — p >= minP and evidence >= minEvidence.
Validation (RangeError): `at > now`, non-finite at/now, weight <= 0 or non-finite, halfLifeDays <= 0, priors <= 0, empty
store or item.

## Tests (each its own Deno.test)
1. One `seen` sighting at `now`, defaults → alpha 2, beta 1, p = 2/3, evidence 1.
2. A sighting exactly 14 days old adds 0.5 (alpha 1.5 → p 0.6).
3. Old "seen" (28 days) + fresh "missing" → p < 0.5: fresh evidence wins.
4. Two stores, two items: groups are independent and the sort order is p desc, then store, then item.
5. shouldAlert: p 0.8 with evidence 1 → false; with evidence 3 → true.
6. Validation errors throw RangeError (one assert per rule).
Use `assertAlmostEquals` for floats.

## Don't
- commit, push, merge; edit any other file; add dependencies; touch zad-brain or SQL.

## Done means (run from the repo root, paste the last lines)
- deno check supabase/functions/_shared/or/restockOdds.ts
- deno test -A supabase/functions/_shared/or/restockOdds_test.ts
