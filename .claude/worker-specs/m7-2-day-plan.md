# m7-2-day-plan — the best day out in limited time and money (خطة اليوم)

ZAD_OR_PLAN م٧.٢, the ordering only (Places lookup and wiring are later slices). An orienteering problem with time
windows. Pure TypeScript (Deno), no DB, no network, no imports except `jsr:@std/assert@1` in the test.

## Files you may edit (only these, both new)
- supabase/functions/_shared/or/dayPlan.ts
- supabase/functions/_shared/or/dayPlan_test.ts

## Do
Style to copy: supabase/functions/_shared/or/choreAssignment.ts and choreAssignment_test.ts.

Exports, exactly these:
- `export interface Place { id: string; value: number; cost: number; visitMin: number; x: number; y: number; open?: readonly [number, number] }`
  — value 0..10 (how much he'd like it), cost in money, visitMin minutes spent there, x/y in km, open = [from, to] in
  minutes after midnight (no field = always open).
- `export interface DayRules { startMin: number; endMin: number; budget: number; start: { x: number; y: number }; speedKmh?: number; returnToStart?: boolean }`
  — speedKmh default 20, returnToStart default true.
- `export interface DayPlan { order: string[]; value: number; cost: number; finishMin: number }`
- `export function planDay(places: readonly Place[], rules: DayRules): DayPlan`
  Travel minutes = euclidean km / speedKmh * 60. Arriving before `open[0]` waits until it; the visit must END by
  `open[1]` and by `endMin` (including the trip back when returnToStart). Total cost <= budget. Maximise total value;
  ties → lower cost, then earlier finishMin, then the lexicographically smaller `order` (compare ids element-wise).
  Exact for up to 12 places (DP over subsets × last place, or branch-and-bound with a sound bound). Empty plan is valid
  (value 0, finishMin = startMin).
Validation (RangeError): duplicate ids, value outside 0..10, negative or non-finite cost/visitMin/budget, open with
from >= to, endMin <= startMin, speedKmh <= 0, more than 12 places.

## Tests (each its own Deno.test)
1. Two places side by side, enough time for one → the higher value one.
2. Budget binds → the affordable one even if less valuable.
3. A time window: the best place opens late; the plan visits another first, then it.
4. returnToStart false allows a farther last stop that true forbids.
5. Exactness: for 7 places from a seeded deterministic generator, brute force over all orders equals planDay (value,
   cost and order).
6. Validation errors throw RangeError.

## Don't
- commit, push, merge; edit any other file; add dependencies; touch zad-brain or SQL.

## Done means (run from the repo root, paste the last lines)
- deno check supabase/functions/_shared/or/dayPlan.ts
- deno test -A supabase/functions/_shared/or/dayPlan_test.ts
