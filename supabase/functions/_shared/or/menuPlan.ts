import { type LpModel, solveLp } from "./lp.ts";

/** A dish the house can cook. `cost` is for the whole household; `taste` is 0..10 (how much the house likes it). */
export interface Dish {
  id: string;
  cost: number;
  taste: number;
  tags?: readonly string[];
}

export interface MenuRules {
  days: number;
  budget: number;
  /** A dish at most this many times in the week. Default 1. */
  maxRepeat?: number;
  /** The chosen dishes must cover at least this many distinct tags. Default 0. */
  minDistinctTags?: number;
}

export interface MenuPlan {
  /** days[i] is a dish id, or null when nothing fits that day. */
  days: Array<string | null>;
  spent: number;
  totalTaste: number;
  /** False when fewer than `days` dishes fit the budget, or the tag rule could not be met. */
  feasible: boolean;
}

const cents = (n: number) => Math.round(n * 100);

function validate(dishes: readonly Dish[], rules: MenuRules): void {
  if (!Number.isInteger(rules.days) || rules.days < 1 || rules.days > 14) throw new RangeError("days must be an integer in 1..14");
  if (!Number.isFinite(rules.budget) || rules.budget < 0) throw new RangeError("budget must be a non-negative number");
  const ids = new Set<string>();
  for (const d of dishes) {
    if (ids.has(d.id)) throw new RangeError(`duplicate dish id: ${d.id}`);
    ids.add(d.id);
    if (!Number.isFinite(d.cost) || d.cost < 0) throw new RangeError(`bad cost: ${d.id}`);
    if (!Number.isFinite(d.taste) || d.taste < 0 || d.taste > 10) throw new RangeError(`taste outside 0..10: ${d.id}`);
  }
}

/** Order the picked dishes so the same dish is not on two consecutive days when that can be avoided. */
export function arrangeDays(counts: ReadonlyMap<string, number>, cost: ReadonlyMap<string, number>): string[] {
  const left = new Map(counts);
  const out: string[] = [];
  const total = [...counts.values()].reduce((a, b) => a + b, 0);
  while (out.length < total) {
    const prev = out[out.length - 1];
    const pool = [...left.entries()].filter(([, n]) => n > 0);
    // Most copies left first (so a repeated dish is spread out), then cheapest, then id.
    pool.sort((a, b) => b[1] - a[1] || (cost.get(a[0]) ?? 0) - (cost.get(b[0]) ?? 0) || (a[0] < b[0] ? -1 : 1));
    const pick = pool.find(([id]) => id !== prev) ?? pool[0];
    out.push(pick[0]);
    left.set(pick[0], pick[1] - 1);
  }
  return out;
}

/**
 * The week's menu: the exact optimum (HiGHS MILP) — as many dishes as the budget allows up to `days`, then the most
 * taste, then the lowest cost. Costs are solved in whole cents.
 */
export async function planMenu(dishes: readonly Dish[], rules: MenuRules): Promise<MenuPlan> {
  validate(dishes, rules);
  const maxRepeat = Math.max(1, Math.floor(rules.maxRepeat ?? 1));
  const budget = cents(rules.budget);
  const want = Math.max(0, Math.floor(rules.minDistinctTags ?? 0));
  const tags = [...new Set(dishes.flatMap((d) => d.tags ?? []))].sort();
  const empty: MenuPlan = { days: Array(rules.days).fill(null), spent: 0, totalTaste: 0, feasible: false };
  if (dishes.length === 0) return empty;

  const xs = dishes.map((_, i) => `x${i}`);
  const base = (useTags: boolean): Pick<LpModel, "vars" | "constraints"> => {
    const vars: LpModel["vars"] = xs.map((name) => ({ name, lb: 0, ub: maxRepeat, integer: true }));
    const constraints: LpModel["constraints"] = [
      { name: "budget", terms: Object.fromEntries(xs.map((x, i) => [x, cents(dishes[i].cost)])), op: "<=", rhs: budget },
      { name: "days", terms: Object.fromEntries(xs.map((x) => [x, 1])), op: "<=", rhs: rules.days },
    ];
    if (useTags) {
      tags.forEach((tag, t) => {
        vars.push({ name: `y${t}`, lb: 0, ub: 1, integer: true });
        const members = dishes.flatMap((d, i) => (d.tags?.includes(tag) ? [xs[i]] : []));
        constraints.push({ name: `tag${t}`, terms: { ...Object.fromEntries(members.map((m) => [m, -1])), [`y${t}`]: 1 }, op: "<=", rhs: 0 });
      });
      constraints.push({ name: "distinct", terms: Object.fromEntries(tags.map((_, t) => [`y${t}`, 1])), op: ">=", rhs: want });
    }
    return { vars, constraints };
  };

  // Stage 1 count, stage 2 taste, stage 3 cost; each later stage holds the earlier optimum.
  const run = async (useTags: boolean) => {
    const { vars, constraints } = base(useTags);
    const count = await solveLp({ sense: "max", objective: Object.fromEntries(xs.map((x) => [x, 1])), vars, constraints });
    if (count.status !== "optimal") return null;
    const k = Math.round(count.objective ?? 0);
    const withCount = [...constraints, { name: "fix_count", terms: Object.fromEntries(xs.map((x) => [x, 1])), op: "=" as const, rhs: k }];
    const tasteObj = Object.fromEntries(xs.map((x, i) => [x, Math.round(dishes[i].taste * 10)]));
    const taste = await solveLp({ sense: "max", objective: tasteObj, vars, constraints: withCount });
    if (taste.status !== "optimal") return null;
    const best = Math.round(taste.objective ?? 0);
    const cheap = await solveLp({
      sense: "min",
      objective: Object.fromEntries(xs.map((x, i) => [x, cents(dishes[i].cost)])),
      vars,
      constraints: [...withCount, { name: "hold_taste", terms: tasteObj, op: ">=", rhs: best }],
    });
    return cheap.status === "optimal" ? cheap : null;
  };

  let solved = want > 0 && tags.length >= want ? await run(true) : null;
  const tagRuleMet = solved !== null || want === 0;
  if (!solved) solved = await run(false);
  if (!solved) return empty;

  const counts = new Map<string, number>();
  const cost = new Map<string, number>();
  let spent = 0;
  let totalTaste = 0;
  dishes.forEach((d, i) => {
    const n = Math.round(solved!.values[xs[i]] ?? 0);
    if (n > 0) counts.set(d.id, n);
    cost.set(d.id, d.cost);
    spent += n * cents(d.cost);
    totalTaste += n * d.taste;
  });
  const order = arrangeDays(counts, cost);
  const days: Array<string | null> = [...order, ...Array(rules.days - order.length).fill(null)];
  return {
    days,
    spent: spent / 100,
    totalTaste: Math.round(totalTaste * 10) / 10,
    feasible: order.length === rules.days && tagRuleMet,
  };
}
