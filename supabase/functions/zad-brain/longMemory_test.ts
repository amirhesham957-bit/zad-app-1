// ذاكرة البيت الطويلة (docs/agent/ZAD_LIVING_BRAIN.md الشريحة ٢٧).
import { assert, assertEquals } from "jsr:@std/assert@1";
import { capsuleNote, monthlyTotals, type MonthTotal, resilience } from "./longMemory.ts";

const DAY = 86_400_000;
const NOW = Date.parse("2027-08-20T07:00:00Z");
const ago = (days: number) => new Date(NOW - days * DAY).toISOString();

Deno.test("capsule: a fact said a year ago today comes back once", () => {
  const n = capsuleNote([{ note: "أخويا جاي من السفر الأسبوع ده", scope: "general", created_at: ago(365) }], [], NOW)!;
  assertEquals(n.sender, "brain");
  assertEquals(n.subject, "زي النهارده من سنة (2026-08-20)");
  assert(n.detail.includes("أخويا جاي من السفر"));
  assert(n.detail.includes("من غير ما تفتحها موضوع لوحدها"));
});

Deno.test("capsule: nothing a year ago is nothing — before August 2027 it stays asleep", () => {
  assertEquals(capsuleNote([{ note: "أخويا جاي من السفر الأسبوع ده", scope: "general", created_at: ago(360) }], [], NOW), null);
  assertEquals(capsuleNote([], [], NOW), null);
});

Deno.test("capsule: a sad or sensitive memory is never 'on this day'", () => {
  for (const note of ["ماما في المستشفى بعد العملية", "عزاء جدي يوم الجمعة", "مزنوقين في الفلوس الشهر ده"]) {
    assertEquals(capsuleNote([{ note, scope: "general", created_at: ago(365) }], [], NOW), null, note);
  }
});

Deno.test("capsule: only what the customer said, not Zad's own notes; a goal counts", () => {
  assertEquals(capsuleNote([{ note: "مهتم بالأكل الصحي جداً", scope: "trait", created_at: ago(365) }], [], NOW), null);
  const n = capsuleNote([], [{ title: "صندوق الطوارئ", updated_at: ago(365) }], NOW)!;
  assert(n.detail.includes("حقق هدف «صندوق الطوارئ»"));
});

const tx = (month: string, income: number, spend: number) => [
  { amount: income, is_expense: false, txn_kind: "income", created_at: `${month}-01T10:00:00Z` },
  { amount: spend, is_expense: true, txn_kind: "expense", created_at: `${month}-15T10:00:00Z` },
  // تحويل بين حساباتك مش صرف.
  { amount: 999, is_expense: true, txn_kind: "transfer", created_at: `${month}-16T10:00:00Z` },
];

Deno.test("resilience: monthly totals classify like the monthly averages", () => {
  assertEquals(monthlyTotals([...tx("2027-01", 100, 80), ...tx("2026-12", 50, 60)]), [
    { month: "2026-12", income: 50, spend: 60 },
    { month: "2027-01", income: 100, spend: 80 },
  ]);
});

const months = (rows: Array<[string, number, number]>): MonthTotal[] =>
  rows.map(([month, income, spend]) => ({ month, income, spend }));

Deno.test("resilience: under six complete months there is nothing to say", () => {
  const five = months([["2027-01", 10, 8], ["2027-02", 10, 8], ["2027-03", 10, 8], ["2027-04", 10, 8], ["2027-05", 10, 8], ["2027-06", 10, 8]]);
  // الشهر الحالي (يونيو) لسه مخلصش — ٥ كاملين بس.
  assertEquals(resilience(five, "2027-06"), null);
  assert(resilience(five, "2027-07") !== null);
});

Deno.test("resilience: a hard month and how long the house took to come back", () => {
  // مارس: عجز ٣٠٠٠. أبريل +١٠٠٠، مايو +٢٠٠٠ ⇒ رجع في شهرين.
  const r = resilience(months([
    ["2027-01", 10000, 9000], ["2027-02", 10000, 9000], ["2027-03", 10000, 13000],
    ["2027-04", 10000, 9000], ["2027-05", 10000, 8000], ["2027-06", 10000, 9500],
  ]), "2027-07")!;
  assertEquals(r.hard_months, [{ month: "2027-03", deficit: 3000, recovered_in: 2 }]);
  assertEquals(r.typical_recovery_months, 2);
});

Deno.test("resilience: not yet recovered is not a recovery; no income is not a crisis; 10% is noise", () => {
  const r = resilience(months([
    ["2027-01", 10000, 10900], // ٩٪ زيادة — مش صعب
    ["2027-02", 0, 4000], // مفيش دخل متسجل — مش أزمة
    ["2027-03", 10000, 9000], ["2027-04", 10000, 9000],
    ["2027-05", 10000, 16000], // عجز ٦٠٠٠
    ["2027-06", 10000, 9000],
  ]), "2027-07")!;
  assertEquals(r.hard_months, [{ month: "2027-05", deficit: 6000, recovered_in: null }]);
  assertEquals(r.typical_recovery_months, null);
});
