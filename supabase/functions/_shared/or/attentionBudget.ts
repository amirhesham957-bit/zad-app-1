/**
 * Daily attention budget (ZAD_OR_PLAN م٥.١): pick which non-critical messages go out today as an exact
 * 0/1 knapsack over "attention units". Critical messages are a separate lane and never spend the budget.
 */

/** A message that could go out today. `cost` is in attention units (integer >= 1). */
export interface Candidate {
  id: string;
  value: number;
  cost: number;
  critical: boolean;
}

/** What goes out, what waits, and the budget actually spent by non-critical messages. */
export interface AttentionPlan {
  send: string[];
  deferred: string[];
  used: number;
  value: number;
}

function validate(cands: readonly Candidate[], budget: number): void {
  if (!Number.isInteger(budget) || budget < 0) throw new RangeError(`budget must be a non-negative integer: ${budget}`);
  const seen = new Set<string>();
  for (const c of cands) {
    if (seen.has(c.id)) throw new RangeError(`duplicate id: ${c.id}`);
    seen.add(c.id);
    if (!Number.isInteger(c.cost) || c.cost < 1) throw new RangeError(`cost must be an integer >= 1: ${c.id}`);
    if (!Number.isFinite(c.value) || c.value < 0) throw new RangeError(`value must be finite and >= 0: ${c.id}`);
  }
}

/**
 * Critical candidates always go. The rest: exact DP over capacity 0..budget. A cell is replaced only on a
 * strictly greater value, so ties keep the earlier choice and the plan is deterministic.
 */
export function planMessages(cands: readonly Candidate[], budget: number): AttentionPlan {
  validate(cands, budget);
  const pool = cands.map((c, i) => ({ c, i })).filter(({ c }) => !c.critical);

  // best[w] = best value with total cost <= w; pick[w] = indexes (into cands) of that choice.
  const best = new Array<number>(budget + 1).fill(0);
  const pick: number[][] = Array.from({ length: budget + 1 }, () => []);
  for (const { c, i } of pool) {
    for (let w = budget; w >= c.cost; w--) {
      const v = best[w - c.cost] + c.value;
      if (v > best[w]) {
        best[w] = v;
        pick[w] = [...pick[w - c.cost], i];
      }
    }
  }

  const chosen = new Set(pick[budget]);
  const send: string[] = [];
  const deferred: string[] = [];
  let used = 0;
  let value = 0;
  cands.forEach((c, i) => {
    if (c.critical) send.push(c.id);
    else if (chosen.has(i)) {
      send.push(c.id);
      used += c.cost;
      value += c.value;
    } else deferred.push(c.id);
  });
  return { send, deferred, used, value: Math.round(value * 1e4) / 1e4 };
}
