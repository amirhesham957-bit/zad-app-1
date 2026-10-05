// decisionReview.ts — مراجعة القرارات اللي فاتت (ZAD_LIVING_BRAIN.md الشريحة ٢٦).
//
// «أثر قرار كبير» (decisionImpact.ts، الشريحة ١٦) بيقول قبل القرار الفايض الشهري هيبقى كام. هنا بعد ٣٠ يوم وبعد
// ٩٠ من القرار: الفايض الفعلي من حركات الفترة دي، قصاد المحسوب (متوسطات البيت ساعة القرار + أثر القرار). مين
// اتحرك — الدخل ولا المصاريف — وبكام. حساب حتمي، صفر توكنز؛ المحاسب في «فريق زاد» بيكتبها ملاحظة.
//
// الصدق قبل الدقة:
//   - أقل من ٥ حركات في الفترة ⇒ مفيش مراجعة (البنك ساكت ≠ «الحسبة طلعت مظبوطة»).
//   - التكلفة اللي مرة واحدة: أكبر مصروف في أول ١٤ يوم بين نص التكلفة ومرة ونص منها بيتشال (ده الشرا نفسه)؛ لو مالقيناهوش
//     مابنشيلش حاجة، وبنقول كده (purchase_found = false) — ممكن يكون اتدفع كاش برّه التطبيق.
//   - تاريخ قبل القرار أقل من شهرين ⇒ confidence = low، ولازم تتقال.

import type { StaffNote } from "./staff.ts";

const DAY = 86_400_000;

/** المراجعات بعد كام يوم من القرار. */
export const DECISION_REVIEW_DAYS = [30, 90] as const;

/** أقل حركات في الفترة عشان المراجعة تتعمل. */
export const DECISION_REVIEW_MIN_TXNS = 5;

/** قرارات مفتوحة (لسه ماخلصتش مراجعاتها) لكل عميل بالكتير. */
export const DECISION_OPEN_MAX = 10;

export interface LoggedDecision {
  id: string;
  label: string;
  decided_at: string;
  one_time_cost: number | null;
  monthly_cost: number | null;
  monthly_income_change: number | null;
  baseline_income: number | null;
  baseline_spend: number | null;
  baseline_days: number | null;
  reviews: number | null;
}

export interface ReviewTxn {
  amount: number | null;
  is_expense: boolean | null;
  txn_kind: string | null;
  created_at: string;
}

export interface DecisionReview {
  /** ٣٠ أو ٩٠. */
  checkpoint: number;
  days: number;
  predicted_surplus: number;
  actual_surplus: number;
  /** الفعلي − المحسوب، في الشهر. */
  delta: number;
  income_delta: number;
  spend_delta: number;
  outcome: "as_expected" | "better" | "worse";
  purchase_found: boolean | null;
  confidence: "ok" | "low";
}

const num = (v: unknown) => (Number.isFinite(Number(v)) ? Number(v) : 0);
const round = (n: number) => Math.round(n);

/** المراجعة المستحقة دلوقتي (٣٠ أو ٩٠)، أو null. */
export function dueCheckpoint(d: Pick<LoggedDecision, "decided_at" | "reviews">, now: number): number | null {
  const reviews = Math.max(0, num(d.reviews));
  const checkpoint = DECISION_REVIEW_DAYS[reviews];
  if (checkpoint === undefined) return null;
  const decided = Date.parse(d.decided_at);
  if (!Number.isFinite(decided)) return null;
  return now - decided >= checkpoint * DAY ? checkpoint : null;
}

/** المراجعة نفسها؛ null = مفيش داتا كفاية (الفحص بيتعلّم اتعمل من غير ملاحظة). */
export function reviewDecision(d: LoggedDecision, txns: readonly ReviewTxn[], now: number): DecisionReview | null {
  const checkpoint = dueCheckpoint(d, now);
  if (checkpoint === null) return null;
  const decided = Date.parse(d.decided_at);
  const window = txns.filter((t) => {
    const at = Date.parse(t.created_at);
    return Number.isFinite(at) && at >= decided && at <= now;
  });
  if (window.length < DECISION_REVIEW_MIN_TXNS) return null;

  let income = 0;
  const expenses: Array<{ amount: number; at: number }> = [];
  for (const t of window) {
    const amount = Math.max(0, num(t.amount));
    if (t.txn_kind === "income" || t.is_expense === false) income += amount;
    else if (!t.txn_kind || t.txn_kind === "expense") expenses.push({ amount, at: Date.parse(t.created_at) });
  }
  let spend = expenses.reduce((s, e) => s + e.amount, 0);

  const oneTime = Math.max(0, num(d.one_time_cost));
  let purchaseFound: boolean | null = null;
  if (oneTime > 0) {
    const purchase = expenses
      .filter((e) => e.at - decided <= 14 * DAY && e.amount >= oneTime * 0.5 && e.amount <= oneTime * 1.5)
      .sort((a, b) => b.amount - a.amount)[0];
    purchaseFound = Boolean(purchase);
    if (purchase) spend -= purchase.amount;
  }

  const days = Math.max(1, Math.round((now - decided) / DAY));
  const months = days / 30;
  const actualIncome = income / months;
  const actualSpend = spend / months;
  const predictedIncome = Math.max(0, num(d.baseline_income)) + num(d.monthly_income_change);
  const predictedSpend = Math.max(0, num(d.baseline_spend)) + Math.max(0, num(d.monthly_cost));
  const predicted = predictedIncome - predictedSpend;
  const actual = actualIncome - actualSpend;
  const delta = actual - predicted;
  // جوه ١٠٪ من المصاريف المحسوبة = «مظبوطة» — الشهور مش متطابقة، وفرق صغير مش خبر.
  const tolerance = Math.max(1, predictedSpend * 0.1);
  return {
    checkpoint,
    days,
    predicted_surplus: round(predicted),
    actual_surplus: round(actual),
    delta: round(delta),
    income_delta: round(actualIncome - predictedIncome),
    spend_delta: round(actualSpend - predictedSpend),
    outcome: Math.abs(delta) <= tolerance ? "as_expected" : delta > 0 ? "better" : "worse",
    purchase_found: purchaseFound,
    confidence: num(d.baseline_days) < 60 ? "low" : "ok",
  };
}

/** ملاحظة المحاسب. subject ثابت لكل قرار ومراجعة (منع التكرار). */
export function reviewNote(d: Pick<LoggedDecision, "label">, r: DecisionReview): StaffNote {
  const when = r.checkpoint === 30 ? "بعد شهر" : "بعد ٣ شهور";
  const label = d.label.replace(/\s+/g, " ").trim().slice(0, 60);
  const head = `من ${r.days} يوم قرر «${label}». المحسوب: فايض ${r.predicted_surplus} في الشهر؛ الفعلي ${r.actual_surplus}.`;
  let body: string;
  if (r.outcome === "as_expected") {
    body = "الحسبة طلعت مظبوطة — قوله ده، تطمين مش تقرير.";
  } else {
    const side = Math.abs(r.spend_delta) >= Math.abs(r.income_delta)
      ? `المصاريف ${r.spend_delta > 0 ? "أعلى" : "أقل"} من المحسوب بـ${Math.abs(r.spend_delta)} في الشهر`
      : `الدخل ${r.income_delta > 0 ? "أعلى" : "أقل"} من المحسوب بـ${Math.abs(r.income_delta)} في الشهر`;
    body = r.outcome === "better"
      ? `أحسن من المحسوب بـ${r.delta} — ${side}. قوله، ولو عايز يحط الفرق في هدف.`
      : `أقل من المحسوب بـ${Math.abs(r.delta)} — ${side}. اسأله لو فيه مصروف ماكانش في الحسبة، من غير لوم، ` +
        "ومن غير ما تقترح إلغاء التزام ثابت.";
  }
  const notes: string[] = [];
  if (r.purchase_found === false) notes.push("التكلفة اللي مرة واحدة مالقيتهاش في الحركات (يمكن اتدفعت كاش) — الرقم ممكن يكون أقل من الحقيقة");
  if (r.confidence === "low") notes.push("التاريخ قبل القرار كان أقل من شهرين، فالمحسوب نفسه تقريبي — قولها");
  return {
    sender: "finance",
    subject: `مراجعة قرار «${label}» ${when}`,
    detail: [head, body, ...notes].join(" ").slice(0, 500),
  };
}
