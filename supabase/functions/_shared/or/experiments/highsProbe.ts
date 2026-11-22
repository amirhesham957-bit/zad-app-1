// Experiment (م٥.٠): can HiGHS (npm:highs, WASM) load and solve a small knapsack MILP inside Deno?
// Run: deno run -A supabase/functions/_shared/or/experiments/highsProbe.ts
// Fallback (only if highs fails): ZAD_PROBE_SOLVER=jsls deno run -A ...

const N = 50;
const CAPACITY_FRACTION = 0.4;

// Deterministic pseudo-random data (LCG) so runs are comparable.
let seed = 12345;
function rnd(): number {
  seed = (seed * 1103515245 + 12345) & 0x7fffffff;
  return seed / 0x7fffffff;
}

const values: number[] = [];
const weights: number[] = [];
for (let i = 0; i < N; i++) {
  values.push(1 + Math.floor(rnd() * 99));
  weights.push(1 + Math.floor(rnd() * 49));
}
const capacity = Math.floor(weights.reduce((a, b) => a + b, 0) * CAPACITY_FRACTION);

function knapsackLp(): string {
  const obj = values.map((v, i) => `${v} x${i}`).join(" + ");
  const cons = weights.map((w, i) => `${w} x${i}`).join(" + ");
  const bins = values.map((_, i) => `x${i}`).join(" ");
  return `Maximize\n obj: ${obj}\nSubject To\n cap: ${cons} <= ${capacity}\nBinary\n ${bins}\nEnd\n`;
}

function bruteForceDpOptimum(): number {
  // Exact DP reference (weights are integers) to check the solver's objective.
  const best = new Array<number>(capacity + 1).fill(0);
  for (let i = 0; i < N; i++) {
    for (let c = capacity; c >= weights[i]; c--) {
      best[c] = Math.max(best[c], best[c - weights[i]] + values[i]);
    }
  }
  return best[capacity];
}

function mb(bytes: number): string {
  return (bytes / 1024 / 1024).toFixed(1);
}

async function runHighs(): Promise<{ status: string; objective: number; picked: number }> {
  const mod = await import("npm:highs@latest");
  const loader = (mod as { default?: unknown }).default ?? mod;
  const highs = await (loader as () => Promise<{ solve: (s: string) => unknown }>)();
  const res = highs.solve(knapsackLp()) as {
    Status: string;
    ObjectiveValue: number;
    Columns: Record<string, { Primal: number }>;
  };
  const picked = Object.values(res.Columns).filter((c) => c.Primal > 0.5).length;
  return { status: res.Status, objective: res.ObjectiveValue, picked };
}

async function runJsls(): Promise<{ status: string; objective: number; picked: number }> {
  const mod = await import("npm:javascript-lp-solver@latest");
  const solver = ((mod as { default?: unknown }).default ?? mod) as {
    Solve: (model: unknown) => Record<string, unknown> & { feasible: boolean; result: number };
  };
  const model = {
    optimize: "value",
    opType: "max",
    constraints: { cap: { max: capacity } },
    variables: Object.fromEntries(
      values.map((v, i) => [
        `x${i}`,
        { value: v, cap: weights[i], [`x${i}`]: 1, int: true },
      ]),
    ),
    binaries: Object.fromEntries(values.map((_, i) => [`x${i}`, 1])),
  };
  const res = solver.Solve(model);
  const picked = Object.keys(values.map((_, i) => i)).filter((i) => (res[`x${i}`] as number) > 0.5).length;
  return {
    status: res.feasible ? "feasible" : "infeasible",
    objective: res.result,
    picked,
  };
}

const solverName = Deno.env.get("ZAD_PROBE_SOLVER") === "jsls" ? "javascript-lp-solver" : "highs";
const memBefore = Deno.memoryUsage();
const t0 = performance.now();
let result: { status: string; objective: number; picked: number } | null = null;
let error: string | null = null;
try {
  result = solverName === "highs" ? await runHighs() : await runJsls();
} catch (e) {
  error = e instanceof Error ? `${e.name}: ${e.message}` : String(e);
}
const elapsedMs = performance.now() - t0;
const memAfter = Deno.memoryUsage();

console.log(JSON.stringify({
  solver: solverName,
  vars: N,
  capacity,
  dpOptimum: bruteForceDpOptimum(),
  ...(result ?? {}),
  error,
  wallMs: Number(elapsedMs.toFixed(1)),
  rssBeforeMB: mb(memBefore.rss),
  rssAfterMB: mb(memAfter.rss),
  heapUsedAfterMB: mb(memAfter.heapUsed),
  denoVersion: Deno.version.deno,
}, null, 2));

if (error) Deno.exit(1);
