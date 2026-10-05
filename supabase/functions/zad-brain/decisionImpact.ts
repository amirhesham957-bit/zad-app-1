// decisionImpact.ts — أثر قرار كبير على الشهور الجاية (ZAD_LIVING_BRAIN.md الشريحة ١٦).
//
// المالك (٢٠٢٦-١٠-٠٤): «لما أفكر أنقل الولد مدرسة تانية أو أشتري عربية، زاد يوريني أثرها على الميزانية
// الـ٦ شهور الجاية من تاريخ البيت الفعلي، ويعدّل سقف الصرف اليومي». `forward_ledger` بيشوف ١٢٠ يوم بالكتير
// ومن غير دخل، و«لو اشتريت…» (whatIf.ts) لحد آخر الدورة بس. هنا شهر بشهر: الرصيد = اللي معاك + (متوسط
// الدخل − متوسط الصرف الفعلي) كل شهر، وبعدين القرار: تكلفة مرة واحدة، تكلفة شهرية، أو تغيير في الدخل.
// حساب حتمي، صفر كوتة، والموديل بيصيغ بس. تاريخ قصير (أقل من شهرين) ⇒ confidence = low، ولازم يتقال.

export interface Decision {
  one_time_cost?: number;
  monthly_cost?: number;
  monthly_income_change?: number;
  /** القرار بيبدأ بعد كام شهر (٠ = الشهر ده). */
  start_offset?: number;
}

export interface DecisionImpact {
  months: Array<{ month: string; without: number; with: number }>;
  monthly_surplus_now: number;
  monthly_surplus_after: number;
  first_negative: { month: string; balance: number } | null;
  lowest: { month: string; balance: number };
  /** كام شهر الفايض يرجّع التكلفة اللي مرة واحدة — null لو مفيش فايض أو مفيش تكلفة. */
  payback_months: number | null;
  /** لو الفايض بعد القرار بالسالب: تقلل الصرف كام في اليوم عشان تتعادل. */
  daily_cut_needed: number | null;
  confidence: "ok" | "low";
  verdict: "affordable" | "tight" | "not_affordable";
}

const round = (n: number) => Math.round(n);
const num = (v: unknown) => (Number.isFinite(Number(v)) ? Number(v) : 0);

/** «2026-11» بعد [offset] شهر من [from]. */
export function monthLabel(from: Date, offset: number): string {
  const d = new Date(Date.UTC(from.getUTCFullYear(), from.getUTCMonth() + offset, 1));
  return d.toISOString().slice(0, 7);
}

export function projectDecision(input: {
  opening: number;
  avgMonthlyIncome: number;
  avgMonthlySpend: number;
  historyDays: number;
  decision: Decision;
  months?: number;
  now?: Date;
}): DecisionImpact | null {
  const d = input.decision;
  const oneTime = Math.max(0, num(d.one_time_cost));
  const monthly = Math.max(0, num(d.monthly_cost));
  const incomeChange = num(d.monthly_income_change);
  if (oneTime === 0 && monthly === 0 && incomeChange === 0) return null;
  const months = Math.min(12, Math.max(1, Math.trunc(num(input.months) || 6)));
  const start = Math.min(months - 1, Math.max(0, Math.trunc(num(d.start_offset))));
  const now = input.now ?? new Date();
  const surplus = num(input.avgMonthlyIncome) - num(input.avgMonthlySpend);
  const surplusAfter = surplus - monthly + incomeChange;

  const rows: DecisionImpact["months"] = [];
  let without = num(input.opening);
  let withIt = num(input.opening);
  for (let i = 0; i < months; i++) {
    without += surplus;
    withIt += i >= start ? surplusAfter : surplus;
    if (i === start) withIt -= oneTime;
    rows.push({ month: monthLabel(now, i), without: round(without), with: round(withIt) });
  }
  const firstNegative = rows.find((r) => r.with < 0);
  const lowest = rows.reduce((low, r) => (r.with < low.with ? r : low), rows[0]);
  const avgSpend = Math.max(1, num(input.avgMonthlySpend));
  return {
    months: rows,
    monthly_surplus_now: round(surplus),
    monthly_surplus_after: round(surplusAfter),
    first_negative: firstNegative ? { month: firstNegative.month, balance: firstNegative.with } : null,
    lowest: { month: lowest.month, balance: lowest.with },
    payback_months: oneTime > 0 && surplusAfter > 0 ? Math.ceil(oneTime / surplusAfter) : null,
    daily_cut_needed: surplusAfter < 0 ? Math.ceil(-surplusAfter / 30) : null,
    confidence: input.historyDays < 60 ? "low" : "ok",
    // ضيق = مابيقعش تحت الصفر بس بيفضل أقل من ربع شهر صرف — أي مفاجأة توقّعه.
    verdict: firstNegative ? "not_affordable" : lowest.with < avgSpend * 0.25 ? "tight" : "affordable",
  };
}

interface Txn { amount: number | null; is_expense: boolean | null; txn_kind: string | null; created_at: string }

/**
 * متوسط الدخل والصرف في الشهر من حركات آخر ٩٠ يوم (أو من أول حركة لو الحساب أحدث). [shiftSince] = بداية تحول سلوكي
 * قايم (lifeShift.ts، الشريحة ٣٠): لو بقاله ٢١ يوم أو أكتر، المتوسط من يومها بس — الطبيعي الجديد مش متوسط القديم والجديد.
 */
export function monthlyAverages(
  txns: readonly Txn[], now = Date.now(), shiftSince?: number | null,
): { income: number; spend: number; historyDays: number } {
  const fromShift = Boolean(shiftSince && Number.isFinite(shiftSince) && now - (shiftSince as number) >= 21 * 86_400_000);
  const since = fromShift ? Math.max(shiftSince as number, now - 90 * 86_400_000) : now - 90 * 86_400_000;
  const recent = txns.filter((t) => {
    const at = Date.parse(t.created_at);
    return Number.isFinite(at) && at >= since && at <= now;
  });
  if (!recent.length) return { income: 0, spend: 0, historyDays: 0 };
  const first = Math.min(...recent.map((t) => Date.parse(t.created_at)));
  const historyDays = Math.max(1, Math.round((now - first) / 86_400_000));
  let income = 0, spend = 0;
  for (const t of recent) {
    const amount = Math.max(0, num(t.amount));
    if (t.txn_kind === "income" || t.is_expense === false) income += amount;
    else if (!t.txn_kind || t.txn_kind === "expense") spend += amount;
  }
  // أقل من شهر تاريخ بيتحسب كشهر — مانضربش أسبوع في أربعة. إلا من يوم التحول (٢١ يوم على الأقل): هناك الأيام الفعلية —
  // ٢٥ يوم صرف مقسومين على ٣٠ كانوا هيصغّروا المصاريف ويخلّوا القرار يبان أسهل.
  const scale = 30 / Math.max(fromShift ? 21 : 30, historyDays);
  return { income: round(income * scale), spend: round(spend * scale), historyDays };
}
