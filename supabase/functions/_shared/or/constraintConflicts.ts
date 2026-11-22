/**
 * Baseline plain-TS constraint conflict detector (ZAD_OR_PLAN م٥.٦).
 *
 * Purpose: measure whether a solver (Z3 via WASM) is needed at all. Everything here is pure TS
 * with no network, no Deno.env and no external dependency. Times are minutes-of-day (0..1440),
 * intervals never cross midnight, and `days` is a weekday mask (0 = Sunday .. 6 = Saturday;
 * omitted means every day). Intervals are half-open: [startMin, endMin), so end == start is NOT an overlap.
 *
 * `checkSatisfiable` is a bounded backtracking search over hard intervals only. If it exceeds the node cap
 * it returns `ok: null, reason: "cap"`. `needsSolver` is true only in that case: it is the signal that
 * LP/SQL/TS checks are NOT enough and a Z3 trial might be justified. Anything else is decided here.
 *
 * Advisory wording only: the rule outputs are reminders about scheduling, never medical advice.
 */

const DAY_MINUTES = 1440;
const ALL_DAYS: readonly number[] = [0, 1, 2, 3, 4, 5, 6];
const DEFAULT_NODE_CAP = 10000;

export type IntervalKind = "med" | "fast" | "gym" | "bill" | "task";

export interface Interval {
  id: string;
  kind: IntervalKind;
  startMin: number;
  endMin: number;
  days?: number[];
  hard?: boolean;
}

export interface Overlap {
  a: string;
  b: string;
  overlapMin: number;
}

export interface MedFastConflict {
  id: string;
  reason: "med_during_fast";
}

export interface Bill {
  id: string;
  amount: number;
  dueDay: number;
}

export interface Budget {
  /** Budget per dueDay index (perDay[dueDay]). Must cover every bill's dueDay. */
  perDay?: number[];
  /** Single running cap: a day is over budget when cumulative bills by that dueDay exceed it. */
  monthly?: number;
}

export interface HardRules {
  /** Step used to shift a hard interval while searching for a placement. 0 (default) means no shifting. */
  shiftStepMin?: number;
  /** Max absolute shift from the original start, in minutes. */
  maxShiftMin?: number;
}

export interface Placement {
  startMin: number;
  endMin: number;
}

export interface SatisfiableResult {
  /** true: a placement exists. false: none exists in the search space. null: node cap hit (undecided). */
  ok: boolean | null;
  /** Pairwise overlaps among hard intervals at their original positions. */
  conflicts: Overlap[];
  reason?: "cap";
  placements?: Record<string, Placement>;
}

function validateInterval(item: Interval): void {
  if (
    !Number.isInteger(item.startMin) || !Number.isInteger(item.endMin) ||
    item.startMin < 0 || item.endMin > DAY_MINUTES || item.endMin <= item.startMin
  ) {
    throw new RangeError(`invalid minutes-of-day range for ${item.id}: ${item.startMin}..${item.endMin}`);
  }
  if (item.days !== undefined) {
    for (const d of item.days) {
      if (!Number.isInteger(d) || d < 0 || d > 6) {
        throw new RangeError(`day must be an integer 0..6 for ${item.id}: ${d}`);
      }
    }
  }
}

function daysOf(item: Interval): readonly number[] {
  return item.days ?? ALL_DAYS;
}

/** Longest single-day overlap in minutes across the weekdays both intervals share. 0 when none. */
function overlapMinutes(a: Interval, b: Interval): number {
  const bDays = new Set(daysOf(b));
  let best = 0;
  for (const d of daysOf(a)) {
    if (!bDays.has(d)) continue;
    const o = Math.min(a.endMin, b.endMin) - Math.max(a.startMin, b.startMin);
    if (o > best) best = o;
  }
  return best;
}

function orderedPair(x: Interval, y: Interval, overlapMin: number): Overlap {
  return x.id <= y.id
    ? { a: x.id, b: y.id, overlapMin }
    : { a: y.id, b: x.id, overlapMin };
}

/** Same-day overlaps between every pair of intervals, sorted by (a, b). Touching edges do not count. */
export function findOverlaps(items: Interval[]): Overlap[] {
  for (const item of items) validateInterval(item);
  const out: Overlap[] = [];
  for (let i = 0; i < items.length; i++) {
    for (let j = i + 1; j < items.length; j++) {
      const o = overlapMinutes(items[i], items[j]);
      if (o > 0) out.push(orderedPair(items[i], items[j], o));
    }
  }
  out.sort((p, q) => (p.a < q.a ? -1 : p.a > q.a ? 1 : p.b < q.b ? -1 : p.b > q.b ? 1 : 0));
  return out;
}

/** A 'med' interval fully inside a 'fast' interval on a shared weekday. Advisory scheduling flag only. */
export function medVsFast(items: Interval[]): MedFastConflict[] {
  for (const item of items) validateInterval(item);
  const fasts = items.filter((i) => i.kind === "fast");
  const out: MedFastConflict[] = [];
  for (const med of items) {
    if (med.kind !== "med") continue;
    const inside = fasts.some((fast) => {
      const fastDays = new Set(daysOf(fast));
      return daysOf(med).some((d) =>
        fastDays.has(d) && med.startMin >= fast.startMin && med.endMin <= fast.endMin
      );
    });
    if (inside) out.push({ id: med.id, reason: "med_during_fast" });
  }
  return out;
}

/** Days (dueDay values, sorted ascending) where bills exceed the budget. */
export function billVsBudget(bills: Bill[], budget: Budget): { overBudgetDays: number[] } {
  for (const bill of bills) {
    if (!Number.isInteger(bill.dueDay) || bill.dueDay < 0 || !Number.isFinite(bill.amount) || bill.amount < 0) {
      throw new RangeError(`invalid bill ${bill.id}`);
    }
  }
  const over = new Set<number>();
  if (budget.perDay !== undefined) {
    const spent = new Map<number, number>();
    for (const bill of bills) {
      if (bill.dueDay >= budget.perDay.length) {
        throw new RangeError(`perDay has no entry for dueDay ${bill.dueDay}`);
      }
      spent.set(bill.dueDay, (spent.get(bill.dueDay) ?? 0) + bill.amount);
    }
    for (const [day, total] of spent) {
      if (total > budget.perDay[day]) over.add(day);
    }
  } else if (budget.monthly !== undefined) {
    const ordered = [...bills].sort((p, q) => p.dueDay - q.dueDay || (p.id < q.id ? -1 : p.id > q.id ? 1 : 0));
    let running = 0;
    for (const bill of ordered) {
      running += bill.amount;
      if (running > budget.monthly) over.add(bill.dueDay);
    }
  }
  return { overBudgetDays: [...over].sort((p, q) => p - q) };
}

/** Same-day overlaps between a 'gym' item and a 'bill' (installment) item. */
export function gymVsInstallment(items: Interval[]): Overlap[] {
  const kindOf = new Map(items.map((i) => [i.id, i.kind]));
  return findOverlaps(items).filter((p) => {
    const kinds = [kindOf.get(p.a), kindOf.get(p.b)].sort();
    return kinds[0] === "bill" && kinds[1] === "gym";
  });
}

/**
 * Bounded backtracking over hard intervals only. Each hard interval may be shifted by multiples of
 * `shiftStepMin` (within `maxShiftMin`, same weekdays) to find a placement with no same-day overlap.
 * Non-hard intervals are ignored. Once more than `nodeCap` candidate placements are tried, the search
 * stops with `ok: null, reason: "cap"`.
 */
export function checkSatisfiable(
  items: Interval[],
  hardRules: HardRules = {},
  nodeCap = DEFAULT_NODE_CAP,
): SatisfiableResult {
  const hard = items.filter((i) => i.hard === true);
  for (const item of hard) validateInterval(item);
  const conflicts = findOverlaps(hard);

  const step = hardRules.shiftStepMin ?? 0;
  const maxShift = hardRules.maxShiftMin ?? 0;
  if (!Number.isInteger(step) || step < 0 || !Number.isInteger(maxShift) || maxShift < 0) {
    throw new RangeError("shiftStepMin and maxShiftMin must be non-negative integers");
  }
  if (!Number.isInteger(nodeCap) || nodeCap < 1) {
    throw new RangeError("nodeCap must be a positive integer");
  }

  // Deterministic candidate shifts: 0, -step, +step, -2*step, +2*step, ...
  const shifts: number[] = [0];
  if (step > 0) {
    for (let k = 1; k * step <= maxShift; k++) shifts.push(-k * step, k * step);
  }

  const domains = hard.map((item) => {
    const len = item.endMin - item.startMin;
    return shifts
      .map((s) => item.startMin + s)
      .filter((start) => start >= 0 && start + len <= DAY_MINUTES)
      .map((start) => ({ startMin: start, endMin: start + len }));
  });

  const placed: Interval[] = [];
  const placements: Record<string, Placement> = {};
  let nodes = 0;
  let capped = false;

  const search = (idx: number): boolean => {
    if (idx === hard.length) return true;
    for (const slot of domains[idx]) {
      nodes++;
      if (nodes > nodeCap) {
        capped = true;
        return false;
      }
      const candidate: Interval = { ...hard[idx], startMin: slot.startMin, endMin: slot.endMin };
      if (placed.some((p) => overlapMinutes(p, candidate) > 0)) continue;
      placed.push(candidate);
      placements[candidate.id] = slot;
      if (search(idx + 1)) return true;
      placed.pop();
      delete placements[candidate.id];
      if (capped) return false;
    }
    return false;
  };

  const found = search(0);
  if (capped) return { ok: null, reason: "cap", conflicts };
  if (!found) return { ok: false, conflicts };
  return { ok: true, conflicts, placements };
}

/**
 * True only when the backtracking search hit its node cap. That is the signal that LP/SQL/TS checks
 * are not enough and a Z3 trial might be justified. A false result means the TS check decided the case.
 */
export function needsSolver(result: SatisfiableResult): boolean {
  return result.ok === null && result.reason === "cap";
}
