# m5-2-menu-plan — the week's menu within a budget (خطة الجمعة، المنيو)

ZAD_OR_PLAN م٥.٢, the menu part only (the chore part is done; wiring into the brain is a later slice). Pure TypeScript
(Deno), no DB, no network, no imports except `jsr:@std/assert@1` in the test.

## Files you may edit (only these, both new)
- supabase/functions/_shared/or/menuPlan.ts
- supabase/functions/_shared/or/menuPlan_test.ts

## Do
Style to copy: supabase/functions/_shared/or/pantryPriorities.ts and pantryPriorities_test.ts (validation with
RangeError, integer cents, deterministic tie-breaks).

Exports, exactly these:
- `export interface Dish { id: string; cost: number; taste: number; tags?: readonly string[] }` — cost in money for the
  whole household, taste 0..10 (how much the house likes it).
- `export interface MenuRules { days: number; budget: number; maxRepeat?: number; minDistinctTags?: number }` —
  maxRepeat default 1 (a dish at most once a week), minDistinctTags default 0.
- `export interface MenuPlan { days: Array<string | null>; spent: number; totalTaste: number; feasible: boolean }`
  — `days[i]` is a dish id or null when nothing fits; `feasible` false when fewer than `days` dishes fit the budget.
- `export function planMenu(dishes: readonly Dish[], rules: MenuRules): MenuPlan`
  Choose a multiset of dishes (each used at most maxRepeat times) of size exactly `rules.days` (or as many as fit)
  maximising total taste with total cost <= budget; among equal taste prefer lower cost, then lexicographically smaller
  ids. If minDistinctTags > 0, the chosen dishes must cover at least that many distinct tags (when impossible, ignore the
  rule and set feasible=false). Exact for up to 40 dishes × 7 days (DP over cents and count, or branch-and-bound) —
  no heuristics that can miss the optimum. Order `days` so the same dish is never on two consecutive days when
  avoidable, cheapest-first otherwise stable.
  Validation: RangeError on duplicate ids, non-finite or negative cost/budget, taste outside 0..10, days not an integer
  in 1..14.

## Tests (each its own Deno.test)
1. Budget binds: 3 dishes (taste 9 cost 300, taste 8 cost 100, taste 5 cost 50), days 2, budget 160 → picks 100+50.
2. Budget loose → the two tastiest.
3. maxRepeat 2 with one great cheap dish and days 3 → it appears twice, never on consecutive days.
4. Not enough budget for `days` dishes → feasible false, nulls fill the rest, spent <= budget.
5. minDistinctTags 2 forces a less tasty dish with a second tag.
6. Exactness: brute force over all combinations for 8 random dishes (seeded, deterministic) × days 3 equals planMenu.
7. Validation errors throw RangeError.

## Don't
- commit, push, merge; edit any other file; add dependencies; touch zad-brain or SQL.

## Done means (run from the repo root, paste the last lines)
- deno check supabase/functions/_shared/or/menuPlan.ts
- deno test -A supabase/functions/_shared/or/menuPlan_test.ts
