import { assert, assertEquals, assertThrows } from "jsr:@std/assert@1";
import {
  billVsBudget,
  checkSatisfiable,
  findOverlaps,
  gymVsInstallment,
  type Interval,
  medVsFast,
  needsSolver,
} from "./constraintConflicts.ts";

const iv = (over: Partial<Interval> & Pick<Interval, "id" | "kind" | "startMin" | "endMin">): Interval => ({
  ...over,
});

Deno.test("overlap: same-day intersecting intervals are reported with minutes", () => {
  const out = findOverlaps([
    iv({ id: "b", kind: "task", startMin: 600, endMin: 720 }),
    iv({ id: "a", kind: "task", startMin: 660, endMin: 780 }),
  ]);
  assertEquals(out, [{ a: "a", b: "b", overlapMin: 60 }]);
});

Deno.test("overlap: touching boundaries (end == start) is NOT an overlap", () => {
  const out = findOverlaps([
    iv({ id: "x", kind: "task", startMin: 540, endMin: 600 }),
    iv({ id: "y", kind: "task", startMin: 600, endMin: 660 }),
  ]);
  assertEquals(out, []);
});

Deno.test("overlap: containment counts the inner length", () => {
  const out = findOverlaps([
    iv({ id: "outer", kind: "task", startMin: 480, endMin: 1080 }),
    iv({ id: "inner", kind: "task", startMin: 600, endMin: 630 }),
  ]);
  assertEquals(out, [{ a: "inner", b: "outer", overlapMin: 30 }]);
});

Deno.test("overlap: output is sorted by (a, b) regardless of input order", () => {
  const items = [
    iv({ id: "c", kind: "task", startMin: 0, endMin: 100 }),
    iv({ id: "a", kind: "task", startMin: 0, endMin: 100 }),
    iv({ id: "b", kind: "task", startMin: 0, endMin: 100 }),
  ];
  const out = findOverlaps(items);
  assertEquals(out.map((p) => `${p.a}-${p.b}`), ["a-b", "a-c", "b-c"]);
});

Deno.test("day masks: intervals on disjoint weekdays never overlap", () => {
  const out = findOverlaps([
    iv({ id: "fri", kind: "gym", startMin: 1080, endMin: 1140, days: [5] }),
    iv({ id: "sun", kind: "bill", startMin: 1080, endMin: 1140, days: [0] }),
  ]);
  assertEquals(out, []);
});

Deno.test("day masks: only shared weekdays count toward overlap", () => {
  const out = findOverlaps([
    iv({ id: "w", kind: "task", startMin: 600, endMin: 660, days: [1, 2, 3] }),
    iv({ id: "v", kind: "task", startMin: 600, endMin: 660, days: [3, 4] }),
  ]);
  assertEquals(out, [{ a: "v", b: "w", overlapMin: 60 }]);
});

Deno.test("day masks: omitted days means every day", () => {
  const out = findOverlaps([
    iv({ id: "daily", kind: "task", startMin: 0, endMin: 60 }),
    iv({ id: "sat", kind: "task", startMin: 30, endMin: 90, days: [6] }),
  ]);
  assertEquals(out, [{ a: "daily", b: "sat", overlapMin: 30 }]);
});

Deno.test("validation: invalid minutes-of-day or weekday throws RangeError", () => {
  assertThrows(() => findOverlaps([iv({ id: "bad", kind: "task", startMin: 600, endMin: 500 })]), RangeError);
  assertThrows(() => findOverlaps([iv({ id: "bad", kind: "task", startMin: 0, endMin: 1441 })]), RangeError);
  assertThrows(() => findOverlaps([iv({ id: "bad", kind: "task", startMin: 0, endMin: 60, days: [7] })]), RangeError);
});

Deno.test("med vs fast: med fully inside fast on a shared day is flagged with advisory reason", () => {
  const out = medVsFast([
    iv({ id: "fast1", kind: "fast", startMin: 360, endMin: 720 }),
    iv({ id: "pill", kind: "med", startMin: 420, endMin: 450 }),
  ]);
  assertEquals(out, [{ id: "pill", reason: "med_during_fast" }]);
});

Deno.test("med vs fast: med outside fast window or only partially overlapping is not flagged", () => {
  const out = medVsFast([
    iv({ id: "fast1", kind: "fast", startMin: 360, endMin: 720 }),
    iv({ id: "after", kind: "med", startMin: 720, endMin: 750 }),
    iv({ id: "edge", kind: "med", startMin: 700, endMin: 800 }),
  ]);
  assertEquals(out, []);
});

Deno.test("med vs fast: day mask decides whether the window applies", () => {
  const out = medVsFast([
    iv({ id: "fastSun", kind: "fast", startMin: 360, endMin: 720, days: [0] }),
    iv({ id: "medMon", kind: "med", startMin: 420, endMin: 450, days: [1] }),
  ]);
  assertEquals(out, []);
});

Deno.test("budget: perDay flags only days whose bills exceed the day budget", () => {
  const bills = [
    { id: "rent", amount: 500, dueDay: 1 },
    { id: "net", amount: 100, dueDay: 1 },
    { id: "power", amount: 80, dueDay: 5 },
  ];
  const perDay = [0, 550, 0, 0, 0, 100];
  assertEquals(billVsBudget(bills, { perDay }), { overBudgetDays: [1] });
});

Deno.test("budget: monthly running cap flags the due day where cumulative spend passes it", () => {
  const bills = [
    { id: "a", amount: 300, dueDay: 2 },
    { id: "b", amount: 300, dueDay: 10 },
    { id: "c", amount: 300, dueDay: 20 },
  ];
  assertEquals(billVsBudget(bills, { monthly: 550 }), { overBudgetDays: [10, 20] });
  assertEquals(billVsBudget(bills, { monthly: 650 }), { overBudgetDays: [20] });
  assertEquals(billVsBudget(bills, { monthly: 900 }), { overBudgetDays: [] });
});

Deno.test("gym vs installment: only gym/bill pairs are returned", () => {
  const out = gymVsInstallment([
    iv({ id: "gym", kind: "gym", startMin: 1080, endMin: 1170, days: [1] }),
    iv({ id: "inst", kind: "bill", startMin: 1100, endMin: 1110, days: [1] }),
    iv({ id: "task", kind: "task", startMin: 1100, endMin: 1110, days: [1] }),
  ]);
  assertEquals(out, [{ a: "gym", b: "inst", overlapMin: 10 }]);
});

Deno.test("satisfiable: no hard conflicts gives ok true with no conflicts", () => {
  const res = checkSatisfiable([
    iv({ id: "h1", kind: "task", startMin: 540, endMin: 600, hard: true }),
    iv({ id: "h2", kind: "task", startMin: 600, endMin: 660, hard: true }),
    iv({ id: "soft", kind: "task", startMin: 540, endMin: 600 }),
  ]);
  assertEquals(res.ok, true);
  assertEquals(res.conflicts, []);
  assert(!needsSolver(res));
});

Deno.test("satisfiable: hard overlap with no shifting allowed is ok false", () => {
  const res = checkSatisfiable([
    iv({ id: "h1", kind: "gym", startMin: 540, endMin: 600, hard: true }),
    iv({ id: "h2", kind: "bill", startMin: 570, endMin: 630, hard: true }),
  ]);
  assertEquals(res.ok, false);
  assertEquals(res.conflicts, [{ a: "h1", b: "h2", overlapMin: 30 }]);
  assert(!needsSolver(res));
});

Deno.test("satisfiable: shifting a hard interval by the step finds a placement", () => {
  const res = checkSatisfiable(
    [
      iv({ id: "h1", kind: "gym", startMin: 540, endMin: 600, hard: true }),
      iv({ id: "h2", kind: "bill", startMin: 570, endMin: 630, hard: true }),
    ],
    { shiftStepMin: 30, maxShiftMin: 60 },
  );
  assertEquals(res.ok, true);
  const p1 = res.placements!["h1"];
  const p2 = res.placements!["h2"];
  assert(p1.endMin <= p2.startMin || p2.endMin <= p1.startMin);
});

Deno.test("cap: exceeding the node cap returns ok null and needsSolver true", () => {
  // Six 60-min hard items clustered around 08:00 on one day. Only ~3 fit in the +/-60 min shift window,
  // so the search is infeasible and explores many placements before giving up.
  const items: Interval[] = [];
  for (let i = 0; i < 6; i++) {
    items.push(iv({ id: `h${i}`, kind: "task", startMin: 480, endMin: 540, days: [3], hard: true }));
  }
  const res = checkSatisfiable(items, { shiftStepMin: 5, maxShiftMin: 60 }, 50);
  assertEquals(res.ok, null);
  assertEquals(res.reason, "cap");
  assert(needsSolver(res));
});

Deno.test("cap: a decided case under the cap is not flagged as needing a solver", () => {
  const res = checkSatisfiable(
    [
      iv({ id: "h1", kind: "task", startMin: 480, endMin: 540, hard: true }),
      iv({ id: "h2", kind: "task", startMin: 500, endMin: 560, hard: true }),
    ],
    {},
    10,
  );
  assertEquals(res.ok, false);
  assertEquals(res.reason, undefined);
  assert(!needsSolver(res));
});

Deno.test("determinism: repeated calls give identical results", () => {
  const items: Interval[] = [
    iv({ id: "h2", kind: "gym", startMin: 540, endMin: 600, hard: true, days: [1, 2] }),
    iv({ id: "h1", kind: "bill", startMin: 570, endMin: 630, hard: true, days: [2] }),
    iv({ id: "m", kind: "med", startMin: 555, endMin: 575 }),
    iv({ id: "f", kind: "fast", startMin: 500, endMin: 700 }),
  ];
  const rules = { shiftStepMin: 15, maxShiftMin: 90 };
  const first = JSON.stringify([
    findOverlaps(items),
    medVsFast(items),
    checkSatisfiable(items, rules),
  ]);
  for (let i = 0; i < 5; i++) {
    const again = JSON.stringify([
      findOverlaps(items),
      medVsFast(items),
      checkSatisfiable(items, rules),
    ]);
    assertEquals(again, first);
  }
});
