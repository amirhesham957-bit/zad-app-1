# m5-0-highs-probe — HiGHS (WASM) in Deno: does it load, how fast, how much memory

ZAD_OR_PLAN م٥.٠. Pure TypeScript (Deno). One npm dependency, pinned exactly: `npm:highs@1.15.4`. No DB, no network
calls from the code itself, no other imports except `jsr:@std/assert@1` in the test.

## Files you may edit (only these, both new)
- supabase/functions/_shared/or/lp.ts
- supabase/functions/_shared/or/lp_test.ts

## Do
Style to copy: supabase/functions/_shared/or/attentionBudget.ts and attentionBudget_test.ts (short doc comments,
`Deno.test`, `assertEquals` / `assertThrows` / `assertRejects` from "jsr:@std/assert@1").

`lp.ts` exports exactly these:
- `export interface LpVar { name: string; lb?: number; ub?: number; integer?: boolean }`
  (defaults: lb 0, ub +Infinity, integer false; `name` must match /^[A-Za-z_][A-Za-z0-9_]{0,30}$/)
- `export interface LpConstraint { name: string; terms: Record<string, number>; op: "<=" | ">=" | "="; rhs: number }`
- `export interface LpModel { sense: "max" | "min"; objective: Record<string, number>; vars: LpVar[]; constraints: LpConstraint[] }`
- `export interface LpResult { status: "optimal" | "infeasible" | "unbounded" | "other"; objective: number | null; values: Record<string, number> }`
- `export function toLpText(m: LpModel): string` — CPLEX LP format text (Maximize/Minimize, Subject To, Bounds,
  General for integers, End). Throws RangeError for: a bad var name, a duplicate var, a term or objective key that is not
  a declared var, a non-finite coefficient or rhs, lb > ub.
- `export async function solveLp(m: LpModel): Promise<LpResult>` — loads HiGHS once (module-level cached promise:
  `import highsLoader from "npm:highs@1.15.4"`, then `await highsLoader()`), calls `highs.solve(toLpText(m))`, maps the
  status ("Optimal" → optimal, "Infeasible" → infeasible, "Unbounded" → unbounded, anything else → other), and returns
  each var's `Primal` value rounded to 6 decimals. `objective` is `ObjectiveValue` when optimal, else null.

## Tests (each its own Deno.test)
1. `toLpText` on a 2-var model contains "Maximize", "Subject To", "Bounds", "End"; integer vars appear under "General".
2. `toLpText` throws RangeError for each bad input listed above (one assertThrows each).
3. LP: max 3x + 2y, x + y <= 4, x + 3y <= 6, x <= 3 → optimal, objective 11, x = 3, y = 1.
4. MILP knapsack, same data as attentionBudget_test's greedy trap: values x10 y7 z7, costs 4 2 2, capacity 4, binary
   vars → objective 14, y = 1, z = 1, x = 0.
5. Infeasible: x >= 5 and x <= 3 → status "infeasible", objective null.
6. Unbounded: max x with no upper bound and no constraint limiting x → status "unbounded" (or "other" — assert it is not
   "optimal").
7. Performance probe: a 200-item binary knapsack (deterministic values/costs from a fixed formula, e.g.
   value_i = (i*37 % 101) + 1, cost_i = (i*53 % 29) + 1, capacity 500). Measure wall time with performance.now() around
   the FIRST solveLp call (includes WASM load) and a SECOND call (warm). `console.log` one line:
   `highs-probe first_ms=<n> warm_ms=<n> rss_mb=<Deno.memoryUsage().rss/1e6 rounded>`. Assert status optimal and
   warm_ms < 2000.

## Don't
- commit, push, merge; edit any other file; add any other dependency; use a different highs version.
- If HiGHS fails to load or solve under Deno, do NOT switch library. Leave the tests that show the failure in place,
  and put the exact error text in a comment at the top of lp_test.ts.

## Done means (run from the repo root, paste the last lines)
- deno check supabase/functions/_shared/or/lp.ts supabase/functions/_shared/or/lp_test.ts
- deno test -A supabase/functions/_shared/or/lp_test.ts
