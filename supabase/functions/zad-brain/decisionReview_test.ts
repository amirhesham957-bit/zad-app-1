// مراجعة القرارات اللي فاتت (docs/agent/ZAD_LIVING_BRAIN.md الشريحة ٢٦).
import { assert, assertEquals } from "jsr:@std/assert@1";
import { dueCheckpoint, type LoggedDecision, reviewDecision, reviewNote, type ReviewTxn } from "./decisionReview.ts";

const DAY = 86_400_000;
const DECIDED = Date.parse("2026-09-01T09:00:00Z");
const at = (days: number) => new Date(DECIDED + days * DAY).toISOString();

const car: LoggedDecision = {
  id: "d1", label: "العربية", decided_at: at(0),
  one_time_cost: 50000, monthly_cost: 1000, monthly_income_change: 0,
  baseline_income: 10000, baseline_spend: 7000, baseline_days: 90, reviews: 0,
};

/** شهر: مرتب ١٠٠٠٠، الشرا نفسه يوم ٢، والمصاريف العادية [spend] على ٤ دفعات. */
function month(spend: number, opts: { purchaseDay?: number | null; income?: number } = {}): ReviewTxn[] {
  const rows: ReviewTxn[] = [
    { amount: opts.income ?? 10000, is_expense: false, txn_kind: "income", created_at: at(1) },
  ];
  if (opts.purchaseDay !== null) {
    rows.push({ amount: 50000, is_expense: true, txn_kind: "expense", created_at: at(opts.purchaseDay ?? 2) });
  }
  for (let i = 0; i < 4; i++) {
    rows.push({ amount: spend / 4, is_expense: true, txn_kind: "expense", created_at: at(5 + i * 6) });
  }
  return rows;
}

Deno.test("decision review: due at 30 days, then at 90, then never", () => {
  assertEquals(dueCheckpoint(car, DECIDED + 29 * DAY), null);
  assertEquals(dueCheckpoint(car, DECIDED + 30 * DAY), 30);
  assertEquals(dueCheckpoint({ ...car, reviews: 1 }, DECIDED + 60 * DAY), null);
  assertEquals(dueCheckpoint({ ...car, reviews: 1 }, DECIDED + 90 * DAY), 90);
  assertEquals(dueCheckpoint({ ...car, reviews: 2 }, DECIDED + 400 * DAY), null);
});

Deno.test("decision review: the plan held — the purchase itself is not spending", () => {
  // المحسوب: ١٠٠٠٠ − (٧٠٠٠ + ١٠٠٠) = ٢٠٠٠. الفعلي: ١٠٠٠٠ − ٨٠٥٠ = ١٩٥٠ — والـ٥٠٠٠٠ بتاعة الشرا اتشالت.
  const r = reviewDecision(car, month(8050), DECIDED + 30 * DAY)!;
  assertEquals(r.predicted_surplus, 2000);
  assertEquals(r.actual_surplus, 1950);
  assertEquals(r.outcome, "as_expected");
  assertEquals(r.purchase_found, true);
  const note = reviewNote(car, r);
  assertEquals(note.sender, "finance");
  assertEquals(note.subject, "مراجعة قرار «العربية» بعد شهر");
  assert(note.detail.includes("مظبوطة"));
});

Deno.test("decision review: spending above the plan is said, with no cancelling advice", () => {
  const r = reviewDecision(car, month(9000), DECIDED + 30 * DAY)!;
  assertEquals(r.outcome, "worse");
  assertEquals(r.delta, -1000);
  assertEquals(r.spend_delta, 1000);
  const note = reviewNote(car, r);
  assert(note.detail.includes("المصاريف أعلى من المحسوب بـ1000"));
  assert(note.detail.includes("من غير ما تقترح إلغاء التزام ثابت"));
});

Deno.test("decision review: more income than planned is better, and named as income", () => {
  const r = reviewDecision(car, month(8000, { income: 12000 }), DECIDED + 30 * DAY)!;
  assertEquals(r.outcome, "better");
  assertEquals(r.income_delta, 2000);
  assert(reviewNote(car, r).detail.includes("الدخل أعلى من المحسوب بـ2000"));
});

Deno.test("decision review: an unfound purchase is not guessed, and said", () => {
  const r = reviewDecision(car, month(8000, { purchaseDay: null }), DECIDED + 30 * DAY)!;
  assertEquals(r.purchase_found, false);
  assert(reviewNote(car, r).detail.includes("كاش"));
});

Deno.test("decision review: a payment weeks later is not the purchase", () => {
  // دفعة كبيرة يوم ٢٠ مش الشرا (أول ١٤ يوم بس) — بتفضل مصروف.
  const r = reviewDecision(car, month(8000, { purchaseDay: 20 }), DECIDED + 30 * DAY)!;
  assertEquals(r.purchase_found, false);
  assertEquals(r.outcome, "worse");
});

Deno.test("decision review: a silent bank is no review, not a good one", () => {
  const few: ReviewTxn[] = month(8000).slice(0, 4);
  assertEquals(reviewDecision(car, few, DECIDED + 30 * DAY), null);
});

Deno.test("decision review: a short history before the decision is said", () => {
  const short = { ...car, baseline_days: 40 };
  const r = reviewDecision(short, month(8050), DECIDED + 30 * DAY)!;
  assertEquals(r.confidence, "low");
  assert(reviewNote(short, r).detail.includes("أقل من شهرين"));
});

Deno.test("decision review: the three-month review has its own subject", () => {
  const r = reviewDecision({ ...car, reviews: 1 }, month(8050), DECIDED + 90 * DAY)!;
  assertEquals(r.checkpoint, 90);
  assertEquals(reviewNote(car, r).subject, "مراجعة قرار «العربية» بعد ٣ شهور");
});
