// lifeShift.ts — مستشعر التحول السلوكي (ZAD_LIVING_BRAIN.md الشريحة ٣٠، طلب المالك ٢٠٢٦-١٠-٠٤).
//
// «رصد تغير نمط المعيشة (سفر، وظيفة جديدة) وإعادة ضبط التنبيهات تلقائياً». السفر عنده وضعه (الشريحة ٦) ورجوعه بقى ظرف
// (الشريحة ٢٩). هنا التحولات اللي بتفضل: مصاريف البيت كلها بقت مستوى تاني، المرتب اتغيّر، أو مصروف جديد بيتكرر (عربية ⇒
// بنزين). قواعد ثابتة على الحركات، صفر توكنز، مرة في الأسبوع في جولة المحاسب.
//
// الفرق بين تحول ونزوة: **الاستمرار**. أسبوع غالي أو شهر فيه مكافأة مش تحول:
//   - المصاريف: ٣ أسابيع ورا بعض **كلهم** فوق (أو تحت) وسيط الـ٩ أسابيع اللي قبلهم بـ٣٠٪ — والأسابيع اللي فيها سفر برّه الحسبة.
//   - الدخل: آخر شهرين كاملين قريبين من بعض (١٠٪) وبعيدين عن وسيط الـ٣ اللي قبلهم بـ٢٠٪ — وكل الـ٥ فيهم دخل متسجل (شهر من غير
//     دخل = المرتب مااتسجلش، مش وظيفة جديدة).
//   - مصروف جديد: فئة مالهاش ولا حركة في الـ٩ أسابيع، وبقى ليها ٣ حركات على أسبوعين مختلفين على الأقل آخر ٣ أسابيع، و٥٪ من الصرف.
// وأقل من ١٢ أسبوع تاريخ ⇒ مفيش تحول (مفيش «قبل» نقيس عليه).
//
// «إعادة الضبط تلقائياً»: طول ما التحول قايم ومحدش نفاه — الفضول مابيسألش عن الطبيعي الجديد كأنه غريب، ومتوسطات «أثر قرار»
// و«سقف الشهر الجاي» بتتحسب من يوم التحول. السقف نفسه بيتقترح والعميل بيأكد (الفلوس مابتتغيرش من غير موافقته).

const DAY = 86_400_000;
const WEEK = 7 * DAY;

export const SHIFT_RECENT_WEEKS = 3;
export const SHIFT_PRIOR_WEEKS = 9;
export const SHIFT_SPEND_CHANGE = 0.3;
export const SHIFT_INCOME_CHANGE = 0.2;
/** التحول بيفضل مأثّر في الحسابات قد إيه بعد ما اتكشف. */
export const SHIFT_ACTIVE_DAYS = 60;

export type ShiftKind = "shift_spending" | "shift_income" | "shift_new_expense";

export interface ShiftTxn {
  amount: number | null;
  is_expense: boolean | null;
  txn_kind: string | null;
  category: string | null;
  created_at: string;
}

export interface DetectedShift {
  kind: ShiftKind;
  /** بداية التحول (تقريبي): أول الأسابيع/الشهور الجديدة. */
  since: string;
  detail: Record<string, number | string>;
}

const num = (v: unknown) => (Number.isFinite(Number(v)) ? Number(v) : 0);
const isIncome = (t: ShiftTxn) => t.txn_kind === "income" || t.is_expense === false;
const isSpend = (t: ShiftTxn) => !isIncome(t) && (!t.txn_kind || t.txn_kind === "expense");
const UNLABELLED = new Set(["", "اخرى", "أخرى", "عام", "غير مصنف", "other", "general", "uncategorized"]);

function median(xs: number[]): number {
  if (!xs.length) return 0;
  const s = [...xs].sort((a, b) => a - b);
  const m = Math.floor(s.length / 2);
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
}

/** فترات سفر (من/لحد بالـms) — الأسبوع اللي بيلمسها برّه الحسبة. */
export type Span = { from: number; to: number };

function spendingShift(spends: ShiftTxn[], now: number, travel: readonly Span[]): DetectedShift | null {
  const weeks: Array<{ i: number; sum: number }> = [];
  for (let i = 0; i < SHIFT_RECENT_WEEKS + SHIFT_PRIOR_WEEKS; i++) {
    const to = now - i * WEEK;
    const from = to - WEEK;
    if (travel.some((t) => t.from < to && t.to > from)) continue;
    const sum = spends.reduce((s, t) => {
      const at = Date.parse(t.created_at);
      return at >= from && at < to ? s + Math.max(0, num(t.amount)) : s;
    }, 0);
    weeks.push({ i, sum });
  }
  const recent = weeks.filter((w) => w.i < SHIFT_RECENT_WEEKS).map((w) => w.sum);
  const prior = weeks.filter((w) => w.i >= SHIFT_RECENT_WEEKS).map((w) => w.sum);
  if (recent.length < SHIFT_RECENT_WEEKS || prior.length < 6) return null;
  const before = median(prior);
  if (before <= 0) return null;
  const up = recent.every((w) => w >= before * (1 + SHIFT_SPEND_CHANGE));
  const down = recent.every((w) => w <= before * (1 - SHIFT_SPEND_CHANGE));
  if (!up && !down) return null;
  const after = median(recent);
  return {
    kind: "shift_spending",
    since: new Date(now - SHIFT_RECENT_WEEKS * WEEK).toISOString(),
    detail: { before_weekly: Math.round(before), after_weekly: Math.round(after), change_pct: Math.round((after / before - 1) * 100) },
  };
}

function incomeShift(incomes: ShiftTxn[], now: number): DetectedShift | null {
  const d = new Date(now);
  const months: number[] = [];
  for (let k = 1; k <= 5; k++) {
    const start = Date.UTC(d.getUTCFullYear(), d.getUTCMonth() - k, 1);
    const end = Date.UTC(d.getUTCFullYear(), d.getUTCMonth() - k + 1, 1);
    months.push(incomes.reduce((s, t) => {
      const at = Date.parse(t.created_at);
      return at >= start && at < end ? s + Math.max(0, num(t.amount)) : s;
    }, 0));
  }
  if (months.some((m) => m <= 0)) return null;
  const [m1, m2, ...older] = months;
  if (Math.abs(m1 - m2) > Math.max(m1, m2) * 0.1) return null;
  const before = median(older);
  const after = (m1 + m2) / 2;
  if (Math.abs(after / before - 1) < SHIFT_INCOME_CHANGE) return null;
  return {
    kind: "shift_income",
    since: new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth() - 2, 1)).toISOString(),
    detail: { before_monthly: Math.round(before), after_monthly: Math.round(after), change_pct: Math.round((after / before - 1) * 100) },
  };
}

function newExpense(spends: ShiftTxn[], now: number): DetectedShift | null {
  const recentCut = now - SHIFT_RECENT_WEEKS * WEEK;
  const priorCut = recentCut - SHIFT_PRIOR_WEEKS * WEEK;
  const recentTotal = spends.reduce((s, t) => (Date.parse(t.created_at) >= recentCut ? s + Math.max(0, num(t.amount)) : s), 0);
  if (recentTotal <= 0) return null;
  const by = new Map<string, { category: string; prior: number; times: number[]; total: number }>();
  for (const t of spends) {
    const category = (t.category ?? "").trim();
    if (UNLABELLED.has(category.toLowerCase())) continue;
    const at = Date.parse(t.created_at);
    const g = by.get(category) ?? { category, prior: 0, times: [], total: 0 };
    if (at >= recentCut) {
      g.times.push(at);
      g.total += Math.max(0, num(t.amount));
    } else if (at >= priorCut) {
      g.prior++;
    }
    by.set(category, g);
  }
  const found = [...by.values()].filter((g) => {
    if (g.prior > 0 || g.times.length < 3 || g.total < recentTotal * 0.05) return false;
    const weeksSeen = new Set(g.times.map((at) => Math.floor((now - at) / WEEK)));
    return weeksSeen.size >= 2;
  }).sort((a, b) => b.total - a.total)[0];
  if (!found) return null;
  return {
    kind: "shift_new_expense",
    since: new Date(Math.min(...found.times)).toISOString(),
    detail: { category: found.category.slice(0, 40), weekly_after: Math.round(found.total / SHIFT_RECENT_WEEKS) },
  };
}

/** التحولات المستمرة في حركات العميل. [txns] آخر ~١٢٠ يوم؛ [travel] رحلات (الشريحة ٢٩). */
export function detectShifts(txns: readonly ShiftTxn[], now: number, travel: readonly Span[] = []): DetectedShift[] {
  const oldest = Math.min(...txns.map((t) => Date.parse(t.created_at)).filter(Number.isFinite));
  if (!Number.isFinite(oldest) || now - oldest < (SHIFT_RECENT_WEEKS + SHIFT_PRIOR_WEEKS) * WEEK) return [];
  const spends = txns.filter(isSpend);
  const spending = spendingShift(spends, now, travel);
  let fresh = newExpense(spends, now);
  // مصروف جديد هو اللي رفع المصاريف (٧٠٪ من الزيادة أو أكتر) ⇒ تحول واحد بيسمّي الفئة، مش سؤالين عن نفس التغيير.
  if (spending && fresh && Number(spending.detail.change_pct) > 0) {
    const increase = Number(spending.detail.after_weekly) - Number(spending.detail.before_weekly);
    if (Number(fresh.detail.weekly_after) >= increase * 0.7) {
      spending.detail.new_category = fresh.detail.category;
      spending.detail.new_category_weekly = fresh.detail.weekly_after;
      fresh = null;
    }
  }
  return [spending, incomeShift(txns.filter(isIncome), now), fresh].filter((s): s is DetectedShift => s !== null);
}

/** صف تحول من zad_life_circumstances. */
export interface ShiftRow {
  id?: string;
  kind: string;
  started_at: string;
  ends_at: string;
  ended_at?: string | null;
  confirmed?: boolean | null;
  detail?: Record<string, unknown> | null;
}

/** التحولات القايمة: مخلصتش ومحدش نفاها. */
export function activeShifts<T extends ShiftRow>(rows: readonly T[], now: number): T[] {
  return rows.filter((r) =>
    r.kind.startsWith("shift_") && r.confirmed !== false && !r.ended_at && Date.parse(r.ends_at) > now
  );
}

/** اتسجّل قبل كده؟ نفس النوع (ونفس الفئة للمصروف الجديد) آخر ٣٠ يوم — قايم أو اتنفى. */
export function alreadyKnown(shift: DetectedShift, rows: readonly ShiftRow[], now: number): boolean {
  return rows.some((r) =>
    r.kind === shift.kind && Date.parse(r.ends_at) > now - 30 * DAY &&
    (shift.kind !== "shift_new_expense" || String(r.detail?.category ?? "") === String(shift.detail.category))
  );
}

/** ملاحظة المحاسب: الأرقام، والسؤال مرة واحدة، وإيه يحصل بعد الجواب. */
export function shiftNote(s: DetectedShift): { sender: "finance"; subject: string; detail: string } {
  const after = "لو أكّد: confirm_life_shift بـconfirmed = true، واعرض عليه سقف شهر جديد من propose_next_month_budget (هو اللي يوافق). " +
    "لو نفى: confirmed = false. سؤال واحد خفيف، من غير ما تفترض السبب.";
  if (s.kind === "shift_spending") {
    const up = Number(s.detail.change_pct) > 0;
    return {
      sender: "finance",
      subject: `تحول: مصاريف البيت ${up ? "زادت" : "قلّت"} من ٣ أسابيع`,
      detail: `مصاريف الأسبوع بقت حوالي ${s.detail.after_weekly} بدل ${s.detail.before_weekly} (${up ? "+" : ""}${s.detail.change_pct}٪) ٣ أسابيع ورا بعض` +
        (s.detail.new_category ? ` — أغلب الزيادة «${s.detail.new_category}» (حوالي ${s.detail.new_category_weekly} في الأسبوع) ماكانتش موجودة قبل كده. ` : ". ") +
        `اسأله لو حصل تغيير في البيت (شغل جديد، حد جه أو مشي، عربية، مدرسة) — لو ده الطبيعي الجديد زاد هيقيس عليه. ${after}`,
    };
  }
  if (s.kind === "shift_income") {
    const up = Number(s.detail.change_pct) > 0;
    return {
      sender: "finance",
      subject: `تحول: الدخل ${up ? "زاد" : "قلّ"} آخر شهرين`,
      detail: `الدخل الشهري بقى حوالي ${s.detail.after_monthly} بدل ${s.detail.before_monthly} (${up ? "+" : ""}${s.detail.change_pct}٪) شهرين ورا بعض. ` +
        `اسأله لو غيّر شغله أو اتغيّر مرتبه — من غير تهنئة أو مواساة قبل ما يقول. لو يوم القبض اتغيّر: update_customer_profile. ${after}`,
    };
  }
  return {
    sender: "finance",
    subject: `تحول: مصروف جديد بيتكرر — «${s.detail.category}»`,
    detail: `«${s.detail.category}» ماكانش موجود قبل كده وبقى حوالي ${s.detail.weekly_after} في الأسبوع آخر ٣ أسابيع. ` +
      `اسأله لو ده حاجة جديدة ثابتة (عربية، نادي، دروس) — لو آه زاد مش هيعامله كصرف غريب. ${after}`,
  };
}

/** بداية الطبيعي الجديد للحسابات: أحدث تحول قايم في المصاريف أو الدخل، أو null. */
export function shiftSince(live: ReadonlyArray<{ kind: string; since: string }> | null | undefined): number | null {
  const starts = (live ?? []).filter((r) => r.kind === "shift_spending" || r.kind === "shift_income")
    .map((r) => Date.parse(r.since)).filter(Number.isFinite);
  return starts.length ? Math.max(...starts) : null;
}
