// ميزان الرفاهية التلقائي (docs/agent/ZAD_LIVING_BRAIN.md الشريحة ٣١).
import { assert, assertEquals } from "jsr:@std/assert@1";
import { activityBudget, balanceFrom, isOutOfBalance, savedSoFar, wellbeingNote, type WellbeingTxn } from "./wellbeing.ts";

const DAY = 86_400_000;
const NOW = Date.parse("2026-10-05T12:00:00Z");
const spend = (days: number, amount: number, category: string | null): WellbeingTxn =>
  ({ amount, is_expense: true, txn_kind: "expense", category, created_at: new Date(NOW - days * DAY).toISOString() });

/** ٥٠ يوم: كل يومين مصروف — [mix] بيقول الفئة والمبلغ. */
function days(mix: (i: number) => [string | null, number]): WellbeingTxn[] {
  return Array.from({ length: 25 }, (_, i) => {
    const [category, amount] = mix(i);
    return spend(2 + i * 2, amount, category);
  });
}

const routineHeavy = days((i) => (i === 0 ? ["مطاعم", 50] : i % 3 ? ["فواتير", 400] : ["بقالة", 300]));

Deno.test("balance: bills and the house crowd out fun", () => {
  const b = balanceFrom(routineHeavy, NOW)!;
  assert(b.leisure_share < 0.01 && b.routine_share > 0.95);
  assert(isOutOfBalance(b));
});

Deno.test("balance: a home that goes out now and then is fine", () => {
  const b = balanceFrom(days((i) => (i % 5 === 0 ? ["خروجات", 300] : ["فواتير", 400])), NOW)!;
  assertEquals(isOutOfBalance(b), false);
});

Deno.test("balance: unknown when most spending has no category, or the history is short", () => {
  assertEquals(balanceFrom(days((i) => (i % 4 ? ["أخرى", 400] : ["فواتير", 400])), NOW), null);
  assertEquals(balanceFrom(routineHeavy.filter((t) => Date.parse(t.created_at) > NOW - 30 * DAY), NOW), null);
});

Deno.test("saving: spending slower than the cap's pace, safe, with money left after obligations", () => {
  assertEquals(savedSoFar({ threat: "SAFE", velocity: 0.7, spent: 7000, available: 3000 }), 3000);
  assertEquals(savedSoFar({ threat: "SAFE", velocity: 0.9, spent: 7000, available: 3000 }), null, "on pace");
  assertEquals(savedSoFar({ threat: "WATCH", velocity: 0.7, spent: 7000, available: 3000 }), null);
  assertEquals(savedSoFar({ threat: "SAFE", velocity: 0.7, spent: 7000, available: -10 }), null, "obligations eat it");
  assertEquals(savedSoFar({ threat: "UNKNOWN", velocity: null, spent: 0, available: null }), null, "no cap");
});

Deno.test("activity: a part of the saving, never most of what is left", () => {
  assertEquals(activityBudget(3000, 3000), 450);
  assertEquals(activityBudget(1000, 10000), 300);
  assertEquals(activityBudget(100, 1000), null, "too little to suggest anything");
});

Deno.test("note: once a month, with the numbers, a suggestion not a verdict", () => {
  const n = wellbeingNote({
    balance: { leisure_share: 0.02, routine_share: 0.85, labelled_share: 0.9 }, saved: 3000, budget: 450,
    currency: "EGP", family: true, month: "2026-10",
  });
  assertEquals(n.sender, "family");
  assertEquals(n.subject, "ميزان الرفاهية — 2026-10");
  assert(n.detail.includes("الفواتير والبيت 85٪") && n.detail.includes("الترفيه 2٪"));
  assert(n.detail.includes("نشاط للعيلة بسيط في حدود 450 EGP"));
  assert(wellbeingNote({
    balance: { leisure_share: 0.02, routine_share: 0.85, labelled_share: 0.9 }, saved: 3000, budget: 450,
    currency: null, family: false, month: "2026-10",
  }).detail.includes("حاجة تبسطه"));
});
