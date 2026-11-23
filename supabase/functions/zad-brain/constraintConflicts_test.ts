import { assert, assertEquals } from "jsr:@std/assert@1";
import { describeConflicts, findConflicts, nextDueDate, parseConflictInput, type ConflictSources } from "./constraintConflicts.ts";
import { guardEngineReply } from "./engineGuard.ts";
import { intentToolHints } from "./specialists.ts";

const TODAY = "2026-11-23";
const base: ConflictSources = {
  today: TODAY, timeZone: "Africa/Cairo", budget: { available: 3000, days_left: 10, currency: "EGP" },
  obligations: [], debts: [], subscriptions: [], pharmacy: [], appointments: [],
};

Deno.test("parse: amount required, date validated, past refused", () => {
  assert("error" in parseConflictInput({}, TODAY));
  assert("error" in parseConflictInput({ amount: -5 }, TODAY));
  assert("error" in parseConflictInput({ amount: 5, date: "2026-02-30" }, TODAY));
  assert("error" in parseConflictInput({ amount: 5, date: "2026-11-01" }, TODAY));
  assertEquals(parseConflictInput({ amount: 500, date: "2026-12-01", label: "غسالة" }, TODAY), { value: { amount: 500, date: "2026-12-01", label: "غسالة" } });
});

Deno.test("nextDueDate rolls to next month and clamps short months", () => {
  assertEquals(nextDueDate(25, "2026-11-23"), "2026-11-25");
  assertEquals(nextDueDate(5, "2026-11-23"), "2026-12-05");
  assertEquals(nextDueDate(31, "2026-02-10"), "2026-02-28");
  assertEquals(nextDueDate(40, TODAY), null);
});

Deno.test("over budget: shortfall is amount minus available, sourced", () => {
  const c = findConflicts({ amount: 5000, date: null, label: "" }, base);
  assertEquals(c.length, 1);
  assertEquals(c[0].kind, "over_budget");
  assert(c[0].text.includes("2000"));
  assertEquals(c[0].source, "zad_budget_state.available");
  assertEquals(findConflicts({ amount: 3000, date: null, label: "" }, base), []);
});

Deno.test("commitments near the date are listed with source rows; far ones are not", () => {
  const s: ConflictSources = {
    ...base,
    obligations: [{ id: "o1", title: "قسط العربية", amount: 1200, due_day: 25 }, { id: "o2", title: "بعيد", amount: 10, due_day: 10 }],
    debts: [{ id: "d1", name: "أحمد", minimum_payment: 300, due_day: 26 }],
    subscriptions: [{ id: "s1", title: "نتفلكس", amount: 200, renewal_date: "2026-11-27" }],
  };
  const c = findConflicts({ amount: 500, date: "2026-11-25", label: "" }, s);
  assertEquals(c.map((x) => x.source).sort(), ["zad_debts:d1", "zad_obligations:o1", "zad_subscriptions:s1"]);
  assert(c.find((x) => x.kind === "obligation_near")!.text.includes("1200"));
});

Deno.test("medicine running out before the date and appointments in the window", () => {
  const s: ConflictSources = {
    ...base,
    pharmacy: [
      { id: "m1", name: "بروفين", remaining_quantity: 10, daily_dose_count: 2, units_per_dose: 1 },
      { id: "m2", name: "كتير", remaining_quantity: 900, daily_dose_count: 1, units_per_dose: 1 },
    ],
    appointments: [{ id: "a1", title: "دكتور", starts_at: "2026-11-25T10:00:00Z", expected_cost: 400, status: "upcoming" }],
  };
  const c = findConflicts({ amount: 100, date: "2026-11-26", label: "" }, s);
  const med = c.find((x) => x.kind === "medicine_runs_out")!;
  assertEquals(med.source, "zad_pharmacy_items:m1");
  assert(med.text.includes("2026-11-28") && med.text.includes("5 يوم"));
  assertEquals(c.filter((x) => x.kind === "medicine_runs_out").length, 1);
  const ap = c.find((x) => x.kind === "appointment_near")!;
  assert(ap.text.includes("400") && ap.source === "zad_appointments:a1");
});

Deno.test("no conflicts and no budget are stated honestly", () => {
  const t = describeConflicts({ amount: 100, date: null, label: "" }, { ...base, budget: null });
  assert(t.includes("مفيش تعارض ظاهر"));
  assert(t.includes("مفيش سقف شهري"));
});

Deno.test("every conflict line carries its source, and the guard replaces an invented number", () => {
  const t = describeConflicts({ amount: 5000, date: null, label: "غسالة" }, base);
  for (const l of t.split("\n").filter((x) => x.startsWith("- "))) assert(l.includes("[المصدر:"));
  const out = [{ tool: "check_constraint_conflicts", content: t }];
  assertEquals(guardEngineReply("الفرق 2000 EGP", "؟", out).replaced, false);
  assertEquals(guardEngineReply("الفرق 2750 EGP", "؟", out).replaced, true);
});

Deno.test("intent reaches the tool", () => {
  assert(intentToolHints("ينفع اقسط غسالة بـ5000؟").includes("check_constraint_conflicts"));
  assert(intentToolHints("ده هيتعارض مع حاجة؟").includes("check_constraint_conflicts"));
  assert(!intentToolHints("صباح الخير").includes("check_constraint_conflicts"));
});
