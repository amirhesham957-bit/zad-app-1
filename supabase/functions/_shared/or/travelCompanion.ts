/**
 * Travel companion (ZAD_OR_PLAN م٧.١-م٧.٤): pure helpers, no network/DB/env. Nothing here recommends by
 * commission or ads, gives medical advice, or infers sensitive facts; it only does arithmetic on what the user gave.
 */
import { type Candidate as AttentionCandidate, planMessages } from "./attentionBudget.ts";

// ---------- shared time helpers ----------

/** Local wall-clock parts of `at` in `tz` (IANA). */
export function localParts(at: Date, tz: string): { y: number; m: number; d: number; minutes: number } {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: tz, year: "numeric", month: "numeric", day: "numeric", hour: "numeric", minute: "numeric", hourCycle: "h23",
  }).formatToParts(at);
  const g = (t: string) => Number(parts.find((p) => p.type === t)!.value);
  return { y: g("year"), m: g("month"), d: g("day"), minutes: (g("hour") % 24) * 60 + g("minute") };
}

/** Offset of `tz` from UTC at `at`, in minutes. */
export function tzOffsetMin(at: Date, tz: string): number {
  const p = localParts(at, tz);
  const asUtc = Date.UTC(p.y, p.m - 1, p.d, 0, p.minutes);
  return Math.round((asUtc - Math.floor(at.getTime() / 60000) * 60000) / 60000);
}

const dayNum = (y: number, m: number, d: number) => Math.floor(Date.UTC(y, m - 1, d) / 86400000);
function isoDayNum(s: string): number {
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(s);
  if (!m) throw new RangeError(`bad date: ${s}`);
  return dayNum(Number(m[1]), Number(m[2]), Number(m[3]));
}

// ---------- م٧.١ trip state ----------

export interface Money { amount: number; currency: string }
export interface Trip {
  city: string;
  startDate: string; // YYYY-MM-DD, destination local
  endDate: string; // inclusive
  budget: Money;
  spent: Money[];
  members: string[];
}
export interface TripState {
  city: string;
  status: "before" | "during" | "after";
  dayIndex: number; // 1..totalDays, clamped
  totalDays: number;
  budgetLeft: number;
  currency: string;
  /** Spent amounts in other currencies with no rate given: never guessed, reported as-is. */
  unconverted: Money[];
  members: string[];
}

/** `rates[cur]` = how many trip-currency units one unit of `cur` is worth. */
export function tripState(trip: Trip, now: Date, tz: string, rates: Record<string, number> = {}): TripState {
  const start = isoDayNum(trip.startDate);
  const end = isoDayNum(trip.endDate);
  const totalDays = Math.max(1, end - start + 1);
  const p = localParts(now, tz);
  const today = dayNum(p.y, p.m, p.d);
  const status = today < start ? "before" : today > end ? "after" : "during";
  const dayIndex = Math.min(totalDays, Math.max(1, today - start + 1));

  let left = trip.budget.amount;
  const unconverted: Money[] = [];
  for (const s of trip.spent) {
    if (s.currency === trip.budget.currency) left -= s.amount;
    else if (rates[s.currency] !== undefined && Number.isFinite(rates[s.currency])) left -= s.amount * rates[s.currency];
    else unconverted.push({ ...s });
  }
  return {
    city: trip.city, status, dayIndex, totalDays,
    budgetLeft: Math.round(left * 100) / 100, currency: trip.budget.currency,
    unconverted, members: [...trip.members],
  };
}

// ---------- م٧.٢ day plan (orienteering) ----------

export interface DayCandidate {
  id: string;
  name: string;
  kind: "place" | "outing" | "food";
  cost: number;
  durationMin: number;
  travelMinFromPrev?: number;
  value: number;
  openFrom?: number; // minutes from local midnight
  openTo?: number;
}
export interface DayPlan {
  picked: string[]; // in visit order
  totalCost: number;
  totalMin: number; // elapsed from startMin to the end of the last stop
  skipped: { id: string; reason: "over_budget" | "over_time" | "closed" | "lower_value" }[];
}
interface DayOpts { budget: number; timeMin: number; startMin: number }

const EXACT_LIMIT = 12;
const COST_WEIGHT = 1; // greedy: minutes-equivalent of one currency unit

/** Finish time after visiting `c` starting at `t`, or null if it cannot fit inside its opening hours. */
function visit(c: DayCandidate, t: number): number | null {
  let at = t + (c.travelMinFromPrev ?? 0);
  if (c.openFrom !== undefined && at < c.openFrom) at = c.openFrom;
  const fin = at + c.durationMin;
  if (c.openTo !== undefined && fin > c.openTo) return null;
  return fin;
}

export function planDay(candidates: readonly DayCandidate[], opts: DayOpts): DayPlan {
  const cs = [...candidates].sort((a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0));
  const deadline = opts.startMin + opts.timeMin;
  const usable = cs.filter((c) => c.cost <= opts.budget && (visit(c, opts.startMin) ?? Infinity) <= deadline);

  const order = usable.length <= EXACT_LIMIT ? exact(usable, opts) : greedy(usable, opts);

  const picked = new Set(order.map((c) => c.id));
  const totalCost = order.reduce((s, c) => s + c.cost, 0);
  let t = opts.startMin;
  for (const c of order) t = visit(c, t)!;
  const skipped: DayPlan["skipped"] = [];
  for (const c of cs) {
    if (picked.has(c.id)) continue;
    let reason: DayPlan["skipped"][number]["reason"] = "lower_value";
    if (c.cost > opts.budget) reason = "over_budget";
    else {
      const f = visit(c, opts.startMin);
      if (f === null) reason = "closed";
      else if (f > deadline) reason = "over_time";
    }
    skipped.push({ id: c.id, reason });
  }
  return { picked: order.map((c) => c.id), totalCost, totalMin: t - opts.startMin, skipped };
}

/** Bitmask DP over (subset, last stop) -> earliest finish. Exact for time windows + budget (n <= 12). */
function exact(cs: DayCandidate[], opts: DayOpts): DayCandidate[] {
  const n = cs.length;
  if (n === 0) return [];
  const deadline = opts.startMin + opts.timeMin;
  const full = 1 << n;
  const fin = new Float64Array(full * n).fill(Infinity);
  const par = new Int8Array(full * n).fill(-1);
  const cost = new Float64Array(full);
  const val = new Float64Array(full);
  for (let m = 1; m < full; m++) {
    const low = 31 - Math.clz32(m & -m);
    cost[m] = cost[m & (m - 1)] + cs[low].cost;
    val[m] = val[m & (m - 1)] + cs[low].value;
  }
  let bestMask = 0, bestLast = -1;
  let bestKey: [number, number, number] = [0, 0, 0]; // value, -cost, -finish
  for (let m = 1; m < full; m++) {
    if (cost[m] > opts.budget) continue;
    for (let j = 0; j < n; j++) {
      if (!(m & (1 << j))) continue;
      const rest = m ^ (1 << j);
      let f = Infinity, p = -1;
      if (rest === 0) {
        const r = visit(cs[j], opts.startMin);
        if (r !== null) f = r;
      } else {
        for (let k = 0; k < n; k++) {
          const pf = fin[rest * n + k];
          if (pf === Infinity) continue;
          const r = visit(cs[j], pf);
          if (r !== null && r < f) { f = r; p = k; }
        }
      }
      if (f > deadline) continue;
      fin[m * n + j] = f;
      par[m * n + j] = p;
      const key: [number, number, number] = [val[m], -cost[m], -f];
      if (
        key[0] > bestKey[0] ||
        (key[0] === bestKey[0] && (key[1] > bestKey[1] || (key[1] === bestKey[1] && key[2] > bestKey[2])))
      ) {
        bestKey = key; bestMask = m; bestLast = j;
      }
    }
  }
  const out: DayCandidate[] = [];
  let m = bestMask, j = bestLast;
  while (j >= 0 && m !== 0) {
    out.unshift(cs[j]);
    const p = par[m * n + j];
    m ^= 1 << j;
    j = p;
  }
  return out;
}

/** Greedy by value / (time + cost weight); ties by id (input is id-sorted); appends while feasible. */
function greedy(cs: DayCandidate[], opts: DayOpts): DayCandidate[] {
  const deadline = opts.startMin + opts.timeMin;
  const ratio = (c: DayCandidate) => c.value / Math.max(1, c.durationMin + (c.travelMinFromPrev ?? 0) + COST_WEIGHT * c.cost);
  const ranked = [...cs].sort((a, b) => ratio(b) - ratio(a) || (a.id < b.id ? -1 : 1));
  const order: DayCandidate[] = [];
  let t = opts.startMin, spent = 0;
  for (const c of ranked) {
    if (spent + c.cost > opts.budget) continue;
    // try every insertion slot, keep the earliest-finishing feasible one
    let bestPos = -1, bestEnd = Infinity;
    for (let pos = 0; pos <= order.length; pos++) {
      const seq = [...order.slice(0, pos), c, ...order.slice(pos)];
      let tt = opts.startMin, ok = true;
      for (const s of seq) {
        const r = visit(s, tt);
        if (r === null) { ok = false; break; }
        tt = r;
      }
      if (ok && tt <= deadline && tt < bestEnd) { bestEnd = tt; bestPos = pos; }
    }
    if (bestPos >= 0) {
      order.splice(bestPos, 0, c);
      spent += c.cost;
      t = bestEnd;
    }
  }
  void t;
  return order;
}

// ---------- م٧.٣ needs ----------

export interface Med { name: string; dosesPerDay: number; firstDoseLocalHH: number }
export interface TravelNeedsInput {
  homeTz: string;
  destTz: string;
  meds: Med[];
  checklist: { item: string; have: boolean }[];
  rate?: { from: string; to: string; value: number };
  /** Instant used for tz offsets (DST). Defaults to now. */
  at?: Date;
}
export interface TravelNeeds {
  shiftMin: number; // destination minus home
  medSchedule: { name: string; destLocalTimes: number[]; totalDoses: number }[]; // times: hours, 0 <= h < 24
  missing: string[];
  fx?: { from: string; to: string; rate: number; per100: number };
}

/** Always asked about, even when the user's checklist does not list them. */
export const REQUIRED_ITEMS = ["SIM", "charger", "nearest pharmacy"] as const;

/** Dose times are only re-expressed in destination time; no dosing advice or adjustment. */
export function travelNeeds(input: TravelNeedsInput, tripDays: number): TravelNeeds {
  const at = input.at ?? new Date();
  const shiftMin = tzOffsetMin(at, input.destTz) - tzOffsetMin(at, input.homeTz);
  const medSchedule = input.meds.map((m) => {
    const n = Math.max(1, Math.floor(m.dosesPerDay));
    const step = 24 / n;
    const times = Array.from({ length: n }, (_, i) => {
      const h = (((m.firstDoseLocalHH + i * step) * 60 + shiftMin) / 60) % 24;
      return Math.round((h < 0 ? h + 24 : h) * 100) / 100;
    }).sort((a, b) => a - b);
    return { name: m.name, destLocalTimes: times, totalDoses: n * Math.max(0, Math.floor(tripDays)) };
  });

  const have = new Set(input.checklist.filter((c) => c.have).map((c) => c.item.trim().toLowerCase()));
  const missing: string[] = [];
  const listed = new Set<string>();
  for (const c of input.checklist) {
    listed.add(c.item.trim().toLowerCase());
    if (!c.have && !missing.includes(c.item)) missing.push(c.item);
  }
  for (const r of REQUIRED_ITEMS) {
    const k = r.toLowerCase();
    if (!have.has(k) && !listed.has(k)) missing.push(r);
  }

  const out: TravelNeeds = { shiftMin, medSchedule, missing };
  if (input.rate && Number.isFinite(input.rate.value) && input.rate.value > 0) {
    out.fx = {
      from: input.rate.from, to: input.rate.to, rate: input.rate.value,
      per100: Math.round(input.rate.value * 100 * 100) / 100,
    };
  }
  return out;
}

// ---------- م٧.٤ daily ask ----------

export interface AskCtx {
  tz: string;
  now: Date;
  asksToday: number;
  maxPerDay: 2;
  lastMealLoggedLocal?: boolean;
  budgetOk: boolean;
  /** Result of the attention gate (see `attentionAllowsAsk`). Omitted means allowed. */
  attentionAllowed?: boolean;
}

/** Local meal windows, minutes from midnight at the destination. */
export const MEAL_WINDOWS = [
  { meal: "lunch", from: 13 * 60, to: 16 * 60, text: "اتغديت فين؟ عجبك؟" },
  { meal: "dinner", from: 20 * 60, to: 22 * 60 + 30, text: "اتعشيت فين؟ عجبك؟" },
] as const;

export function dailyAsk(ctx: AskCtx): { ask: boolean; meal?: "lunch" | "dinner"; text?: string } {
  if (!ctx.budgetOk || ctx.attentionAllowed === false) return { ask: false };
  if (ctx.asksToday >= Math.min(2, ctx.maxPerDay)) return { ask: false };
  if (ctx.lastMealLoggedLocal) return { ask: false };
  const { minutes } = localParts(ctx.now, ctx.tz);
  const w = MEAL_WINDOWS.find((x) => minutes >= x.from && minutes < x.to);
  if (!w) return { ask: false };
  return { ask: true, meal: w.meal, text: w.text };
}

/** Reuse of the daily attention budget: does one ask of `cost` units survive alongside `others`? */
export function attentionAllowsAsk(budget: number, others: readonly AttentionCandidate[], cost = 1, value = 1): boolean {
  const id = "travel_ask";
  return planMessages([...others, { id, value, cost, critical: false }], budget).send.includes(id);
}

export interface TripAnswer { meal?: "lunch" | "dinner"; place?: string; liked?: boolean; note?: string }
export interface TripFeedbackEvent {
  kind: "trip_feedback";
  payload: { meal: "lunch" | "dinner" | null; place: string | null; liked: boolean | null; note: string | null };
}

/** Shapes the intent-door event only; the caller writes it. Fields are exactly what the user said. */
export function answerToEvent(answer: TripAnswer): TripFeedbackEvent {
  return {
    kind: "trip_feedback",
    payload: {
      meal: answer.meal ?? null,
      place: answer.place?.trim() || null,
      liked: answer.liked ?? null,
      note: answer.note?.trim() || null,
    },
  };
}
