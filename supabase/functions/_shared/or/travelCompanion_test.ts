import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  answerToEvent, attentionAllowsAsk, dailyAsk, type DayCandidate, planDay, tripState, travelNeeds,
} from "./travelCompanion.ts";

const trip = {
  city: "Istanbul", startDate: "2026-07-10", endDate: "2026-07-14",
  budget: { amount: 1000, currency: "USD" }, spent: [{ amount: 200, currency: "USD" }], members: ["a", "b"],
};
const IST = "Europe/Istanbul";

Deno.test("day index by destination local time, not UTC", () => {
  // 21:30 UTC on Jul 10 is already Jul 11 00:30 in Istanbul (UTC+3) -> day 2
  assertEquals(tripState(trip, new Date("2026-07-10T21:30:00Z"), IST).dayIndex, 2);
  assertEquals(tripState(trip, new Date("2026-07-10T20:30:00Z"), IST).dayIndex, 1);
});

Deno.test("day index clamps before and after the trip", () => {
  const b = tripState(trip, new Date("2026-06-01T12:00:00Z"), IST);
  assertEquals([b.status, b.dayIndex, b.totalDays], ["before", 1, 5]);
  const a = tripState(trip, new Date("2026-08-01T12:00:00Z"), IST);
  assertEquals([a.status, a.dayIndex], ["after", 5]);
});

Deno.test("last day boundary: midnight local ends the trip", () => {
  assertEquals(tripState(trip, new Date("2026-07-14T20:59:00Z"), IST).status, "during");
  assertEquals(tripState(trip, new Date("2026-07-14T21:00:00Z"), IST).status, "after");
});

Deno.test("budget left in trip currency", () => {
  const s = tripState(trip, new Date("2026-07-11T10:00:00Z"), IST);
  assertEquals([s.budgetLeft, s.currency, s.members], [800, "USD", ["a", "b"]]);
});

Deno.test("other-currency spend without a rate is reported unconverted, not guessed", () => {
  const t = { ...trip, spent: [{ amount: 200, currency: "USD" }, { amount: 1000, currency: "TRY" }] };
  const s = tripState(t, new Date("2026-07-11T10:00:00Z"), IST);
  assertEquals(s.budgetLeft, 800);
  assertEquals(s.unconverted, [{ amount: 1000, currency: "TRY" }]);
});

Deno.test("other-currency spend with a rate is converted", () => {
  const t = { ...trip, spent: [{ amount: 1000, currency: "TRY" }] };
  const s = tripState(t, new Date("2026-07-11T10:00:00Z"), IST, { TRY: 0.03 });
  assertEquals([s.budgetLeft, s.unconverted], [970, []]);
});

const c = (id: string, value: number, cost: number, durationMin: number, extra: Partial<DayCandidate> = {}): DayCandidate => ({
  id, name: id, kind: "place", cost, durationMin, value, ...extra,
});

/** Reference: try every ordered subset. */
function brute(cs: DayCandidate[], o: { budget: number; timeMin: number; startMin: number }): number {
  let best = 0;
  const go = (used: number[], t: number, cost: number, val: number) => {
    best = Math.max(best, val);
    cs.forEach((x, i) => {
      if (used.includes(i) || cost + x.cost > o.budget) return;
      let at = t + (x.travelMinFromPrev ?? 0);
      if (x.openFrom !== undefined && at < x.openFrom) at = x.openFrom;
      const f = at + x.durationMin;
      if ((x.openTo !== undefined && f > x.openTo) || f > o.startMin + o.timeMin) return;
      go([...used, i], f, cost + x.cost, val + x.value);
    });
  };
  go([], o.startMin, 0, 0);
  return best;
}

Deno.test("planDay matches brute force on a time-window case", () => {
  const cs = [
    c("a", 10, 20, 60, { openFrom: 600, openTo: 720 }),
    c("b", 8, 10, 90, { travelMinFromPrev: 20 }),
    c("c", 7, 5, 45, { openFrom: 780, openTo: 900 }),
    c("d", 12, 40, 120, { travelMinFromPrev: 15 }),
    c("e", 3, 0, 30),
  ];
  const o = { budget: 60, timeMin: 360, startMin: 540 };
  const plan = planDay(cs, o);
  const byId = new Map(cs.map((x) => [x.id, x]));
  assertEquals(plan.picked.reduce((s, id) => s + byId.get(id)!.value, 0), brute(cs, o));
  assert(plan.totalCost <= o.budget && plan.totalMin <= o.timeMin);
});

Deno.test("planDay beats greedy-by-ratio trap", () => {
  // x is the best ratio but blocks y+z which together are worth more
  const cs = [c("x", 10, 0, 60), c("y", 7, 0, 50), c("z", 7, 0, 50)];
  const plan = planDay(cs, { budget: 0, timeMin: 100, startMin: 0 });
  assertEquals([...plan.picked].sort(), ["y", "z"]);
});

Deno.test("planDay respects opening hours and reports closed", () => {
  const cs = [c("museum", 9, 0, 60, { openFrom: 600, openTo: 660 }), c("park", 2, 0, 60)];
  const plan = planDay(cs, { budget: 10, timeMin: 600, startMin: 700 });
  assertEquals(plan.picked, ["park"]);
  assertEquals(plan.skipped, [{ id: "museum", reason: "closed" }]);
});

Deno.test("planDay waits for opening time", () => {
  const plan = planDay([c("cafe", 5, 0, 30, { openFrom: 600 })], { budget: 5, timeMin: 200, startMin: 540 });
  assertEquals([plan.picked, plan.totalMin], [["cafe"], 90]);
});

Deno.test("planDay skip reasons: over budget and over time", () => {
  const cs = [c("fancy", 9, 500, 30), c("long", 9, 0, 500), c("ok", 1, 0, 30)];
  const plan = planDay(cs, { budget: 100, timeMin: 120, startMin: 0 });
  assertEquals(plan.picked, ["ok"]);
  assertEquals(plan.skipped, [{ id: "fancy", reason: "over_budget" }, { id: "long", reason: "over_time" }]);
});

Deno.test("planDay ties are broken deterministically by id", () => {
  const a = planDay([c("b", 5, 0, 60), c("a", 5, 0, 60)], { budget: 0, timeMin: 60, startMin: 0 });
  const b = planDay([c("a", 5, 0, 60), c("b", 5, 0, 60)], { budget: 0, timeMin: 60, startMin: 0 });
  assertEquals(a.picked, ["a"]);
  assertEquals(a, b);
});

Deno.test("planDay with more than 12 candidates uses greedy and stays feasible", () => {
  const cs = Array.from({ length: 15 }, (_, i) => c(`p${String(i).padStart(2, "0")}`, i + 1, i, 30));
  const plan = planDay(cs, { budget: 40, timeMin: 150, startMin: 0 });
  assert(plan.picked.length > 0 && plan.totalCost <= 40 && plan.totalMin <= 150);
});

Deno.test("meds shift to destination time (Riyadh -> Istanbul is 0, Cairo -> Tokyo +7h in summer)", () => {
  const at = new Date("2026-07-10T12:00:00Z");
  const same = travelNeeds({ homeTz: "Asia/Riyadh", destTz: IST, meds: [{ name: "m", dosesPerDay: 2, firstDoseLocalHH: 8 }], checklist: [], at }, 5);
  assertEquals(same.shiftMin, 0);
  assertEquals(same.medSchedule[0].destLocalTimes, [8, 20]);
  const far = travelNeeds({ homeTz: "Africa/Cairo", destTz: "Asia/Tokyo", meds: [{ name: "m", dosesPerDay: 2, firstDoseLocalHH: 8 }], checklist: [], at }, 5);
  assertEquals(far.shiftMin, 6 * 60); // Cairo is UTC+3 in summer (DST), Tokyo +9
  assertEquals(far.medSchedule[0].destLocalTimes, [2, 14]);
  assertEquals(far.medSchedule[0].totalDoses, 10);
});

Deno.test("travelNeeds lists missing items incl. the required ones and fx", () => {
  const n = travelNeeds({
    homeTz: "Asia/Riyadh", destTz: IST, meds: [],
    checklist: [{ item: "passport", have: true }, { item: "power bank", have: false }, { item: "SIM", have: true }],
    rate: { from: "TRY", to: "SAR", value: 0.1 },
  }, 3);
  assertEquals(n.missing, ["power bank", "charger", "nearest pharmacy"]);
  assertEquals(n.fx, { from: "TRY", to: "SAR", rate: 0.1, per100: 10 });
  assertEquals(travelNeeds({ homeTz: IST, destTz: IST, meds: [], checklist: [] }, 1).fx, undefined);
});

const lunch = new Date("2026-07-10T11:00:00Z"); // 14:00 Istanbul
const base = { tz: IST, now: lunch, asksToday: 0, maxPerDay: 2 as const, budgetOk: true };

Deno.test("dailyAsk asks at local lunch in Egyptian Arabic", () => {
  assertEquals(dailyAsk(base), { ask: true, meal: "lunch", text: "اتغديت فين؟ عجبك؟" });
});

Deno.test("dailyAsk uses destination time, not UTC", () => {
  assertEquals(dailyAsk({ ...base, now: new Date("2026-07-10T10:00:00Z"), tz: "Asia/Tokyo" }).ask, false); // 19:00 JST
  assertEquals(dailyAsk({ ...base, now: new Date("2026-07-10T04:00:00Z") }).ask, false); // 07:00 local
});

Deno.test("dailyAsk caps at 2 per day and respects gates", () => {
  assertEquals(dailyAsk({ ...base, asksToday: 2 }).ask, false);
  assertEquals(dailyAsk({ ...base, asksToday: 1 }).ask, true);
  assertEquals(dailyAsk({ ...base, budgetOk: false }).ask, false);
  assertEquals(dailyAsk({ ...base, lastMealLoggedLocal: true }).ask, false);
  assertEquals(dailyAsk({ ...base, attentionAllowed: false }).ask, false);
});

Deno.test("attention gate reuses planMessages", () => {
  assertEquals(attentionAllowsAsk(1, []), true);
  assertEquals(attentionAllowsAsk(1, [{ id: "x", value: 9, cost: 1, critical: false }]), false);
});

Deno.test("answerToEvent shapes a trip_feedback event only", () => {
  assertEquals(answerToEvent({ meal: "lunch", place: " Karaköy ", liked: true }), {
    kind: "trip_feedback", payload: { meal: "lunch", place: "Karaköy", liked: true, note: null },
  });
});

Deno.test("no ads or affiliate wording in any output", () => {
  const at = new Date("2026-07-10T12:00:00Z");
  const outs = [
    tripState(trip, lunch, IST),
    planDay([c("a", 1, 0, 10)], { budget: 1, timeMin: 60, startMin: 0 }),
    travelNeeds({ homeTz: IST, destTz: IST, meds: [], checklist: [], at }, 1),
    dailyAsk(base),
    answerToEvent({ liked: true }),
  ];
  assert(!/affiliate|commission|sponsor|\bads?\b|عمولة|إعلان/i.test(JSON.stringify(outs)));
});
