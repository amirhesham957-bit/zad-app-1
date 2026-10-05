// مستشعر التحول السلوكي (docs/agent/ZAD_LIVING_BRAIN.md الشريحة ٣٠).
import { assert, assertEquals } from "jsr:@std/assert@1";
import { activeShifts, alreadyKnown, detectShifts, shiftNote, shiftSince, type ShiftTxn } from "./lifeShift.ts";
import { curiosityFor, type CuriosityTxn } from "./curiosity.ts";
import { monthlyAverages } from "./decisionImpact.ts";

const DAY = 86_400_000;
const NOW = Date.parse("2026-10-04T12:00:00Z");
const ago = (days: number) => new Date(NOW - days * DAY).toISOString();
const spend = (days: number, amount: number, category: string | null = "بقالة"): ShiftTxn =>
  ({ amount, is_expense: true, txn_kind: "expense", category, created_at: ago(days) });
const income = (iso: string, amount: number): ShiftTxn =>
  ({ amount, is_expense: false, txn_kind: "income", category: "مرتب", created_at: iso });

/** ١٢ أسبوع: أسبوع i (٠ = الأحدث) بمصروف واحد وسطه. */
function weeks(amountOf: (i: number) => number): ShiftTxn[] {
  return Array.from({ length: 12 }, (_, i) => spend(i * 7 + 3, amountOf(i))).concat([spend(90, 1)]);
}

Deno.test("shift: three weeks in a row 30% above the nine before is a new normal", () => {
  const s = detectShifts(weeks((i) => (i < 3 ? 1500 : 1000)), NOW);
  assertEquals(s.map((x) => x.kind), ["shift_spending"]);
  assertEquals(s[0].detail, { before_weekly: 1000, after_weekly: 1500, change_pct: 50 });
  assertEquals(s[0].since, ago(21));
});

Deno.test("shift: one dear week is not a shift; spending less is one too", () => {
  assertEquals(detectShifts(weeks((i) => (i === 0 ? 3000 : 1000)), NOW), []);
  assertEquals(detectShifts(weeks((i) => (i < 3 ? 600 : 1000)), NOW)[0].detail.change_pct, -40);
});

Deno.test("shift: a week abroad is out of the count; under twelve weeks there is no before", () => {
  const trip = [{ from: NOW - 10 * DAY, to: NOW - 8 * DAY }];
  assertEquals(detectShifts(weeks((i) => (i < 3 ? 1500 : 1000)), NOW, trip), [], "two recent weeks left");
  const short = Array.from({ length: 8 }, (_, i) => spend(i * 7 + 3, i < 3 ? 1500 : 1000));
  assertEquals(detectShifts(short, NOW), []);
});

Deno.test("shift: two steady months of a new salary, every month recorded", () => {
  const months = (sep: number, aug: number, older = 10000) => [
    income("2026-05-25T09:00:00Z", older), income("2026-06-25T09:00:00Z", older), income("2026-07-25T09:00:00Z", older),
    income("2026-08-25T09:00:00Z", aug), income("2026-09-25T09:00:00Z", sep), spend(130, 1),
  ];
  const s = detectShifts(months(13000, 12800), NOW);
  assertEquals(s.map((x) => x.kind), ["shift_income"]);
  assertEquals(s[0].detail.change_pct, 29);
  assertEquals(detectShifts(months(13000, 10000), NOW), [], "one month up is a bonus");
  assertEquals(detectShifts(months(13000, 12800).filter((t) => !t.created_at.startsWith("2026-06")), NOW), [],
    "a month with no income recorded");
});

Deno.test("shift: a new expense that keeps coming", () => {
  const base = weeks(() => 1000);
  const fuel = [spend(2, 150, "بنزين"), spend(9, 150, "بنزين"), spend(16, 150, "بنزين")];
  const s = detectShifts([...base, ...fuel], NOW);
  assertEquals(s.map((x) => x.kind), ["shift_new_expense"]);
  assertEquals(s[0].detail, { category: "بنزين", weekly_after: 150 });
  // في أسبوع واحد بس، أو كان موجود قبل كده ⇒ مش جديد.
  assertEquals(detectShifts([...base, spend(1, 300, "بنزين"), spend(2, 300, "بنزين"), spend(3, 300, "بنزين")], NOW)
    .filter((x) => x.kind === "shift_new_expense"), []);
  assertEquals(detectShifts([...base, ...fuel, spend(40, 300, "بنزين")], NOW).filter((x) => x.kind === "shift_new_expense"), []);
});

Deno.test("shift: a new expense that lifted the whole budget is one shift that names it", () => {
  const car = [spend(2, 300, "بنزين"), spend(9, 300, "بنزين"), spend(16, 300, "بنزين")];
  const s = detectShifts([...weeks(() => 1000), ...car], NOW);
  assertEquals(s.map((x) => x.kind), ["shift_spending"]);
  assertEquals(s[0].detail.new_category, "بنزين");
  assert(shiftNote(s[0]).detail.includes("أغلب الزيادة «بنزين»"));
});

Deno.test("shift: what is live, and what was already asked", () => {
  const rows = [
    { kind: "shift_spending", started_at: ago(21), ends_at: ago(-40), confirmed: null },
    { kind: "shift_income", started_at: ago(60), ends_at: ago(-10), confirmed: false },
    { kind: "exceptional", started_at: ago(1), ends_at: ago(-2) },
  ];
  assertEquals(activeShifts(rows, NOW).map((r) => r.kind), ["shift_spending"]);
  const fuel = { kind: "shift_new_expense" as const, since: ago(16), detail: { category: "بنزين", weekly_after: 300 } };
  assert(alreadyKnown(fuel, [{ kind: "shift_new_expense", started_at: ago(50), ends_at: ago(10), detail: { category: "بنزين" } }], NOW));
  assert(!alreadyKnown(fuel, [{ kind: "shift_new_expense", started_at: ago(50), ends_at: ago(10), detail: { category: "نادي" } }], NOW));
  assertEquals(shiftSince([{ kind: "shift_spending", since: "2026-09-13" }, { kind: "shift_new_expense", since: "2026-09-20" }]),
    Date.parse("2026-09-13"));
});

Deno.test("shift: the note asks once, with the numbers, and says what follows", () => {
  const [s] = detectShifts(weeks((i) => (i < 3 ? 1500 : 1000)), NOW);
  const n = shiftNote(s);
  assertEquals(n.sender, "finance");
  assertEquals(n.subject, "تحول: مصاريف البيت زادت من ٣ أسابيع");
  assert(n.detail.includes("حوالي 1500 بدل 1000 (+50٪)"));
  assert(n.detail.includes("confirm_life_shift") && n.detail.includes("propose_next_month_budget"));
});

// ── إعادة الضبط تلقائياً ─────────────────────────────────────────────────────────

const cTxn = (days: number, amount: number, category: string): CuriosityTxn =>
  ({ id: `${category}-${days}`, amount, title: null, category, merchant_name: null, is_expense: true, txn_kind: "expense",
    source_type: null, created_at: ago(days) } as CuriosityTxn);
// مطاعم: ٤٠٠ في الـ٨ أسابيع قبل الأخيرين (١٠٠ كل أسبوعين)، و٣٠٠ آخر أسبوعين ⇒ ٣ أضعاف.
const surge = [cTxn(80, 50, "مطاعم"), cTxn(20, 100, "مطاعم"), cTxn(35, 100, "مطاعم"), cTxn(50, 100, "مطاعم"), cTxn(65, 100, "مطاعم"),
  cTxn(3, 150, "مطاعم"), cTxn(6, 150, "مطاعم")];
const asked = { now: NOW, todayStart: NOW, askedKeys: new Set<string>() };

Deno.test("recalibrate: the new normal is not a 'surge' to ask about", () => {
  assertEquals(curiosityFor({ txns: surge, ...asked })?.kind, "category_surge");
  const live = { kind: "shift_spending", started_at: ago(21), ends_at: ago(-40), confirmed: null };
  assertEquals(curiosityFor({ txns: surge, ...asked, shifts: [live] }), null);
  // تحول اتنفى ⇒ الفضول يرجع.
  assertEquals(curiosityFor({ txns: surge, ...asked, shifts: [{ ...live, confirmed: false }] })?.kind, "category_surge");
  const newCategory = (category: string) => ({ ...live, kind: "shift_new_expense", detail: { category } });
  assertEquals(curiosityFor({ txns: surge, ...asked, shifts: [newCategory("مطاعم")] }), null);
  assertEquals(curiosityFor({ txns: surge, ...asked, shifts: [newCategory("بنزين")] })?.kind, "category_surge");
});

Deno.test("recalibrate: averages from the shift's day, in its real days", () => {
  const txns = [
    ...Array.from({ length: 60 }, (_, i) => ({ amount: 100, is_expense: true, txn_kind: "expense", created_at: ago(30 + i) })),
    ...Array.from({ length: 25 }, (_, i) => ({ amount: 200, is_expense: true, txn_kind: "expense", created_at: ago(i + 0.5) })),
  ];
  assertEquals(monthlyAverages(txns, NOW, NOW - 25 * DAY).spend, 6000);
  assert(monthlyAverages(txns, NOW).spend < 6000, "without the shift, old and new are mixed");
  // تحول عمره أقل من ٢١ يوم: لسه بدري على متوسط لوحده.
  assertEquals(monthlyAverages(txns, NOW, NOW - 10 * DAY).spend, monthlyAverages(txns, NOW).spend);
});
