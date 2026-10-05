// wellbeing.ts — ميزان الرفاهية التلقائي (ZAD_LIVING_BRAIN.md الشريحة ٣١، طلب المالك ٢٠٢٦-١٠-٠٤).
//
// «يرصد طغيان الفواتير والروتين على الترفيه، فيقترح نشاطاً عائلياً اقتصادياً فور توفر أي توفير مالي». صفر توكنز، جولة سكرتير
// العيلة؛ العقل بيصيغ الاقتراح بلهجة العميل وبأفكار من بلده.
//
// الشرطين مع بعض — ولا واحد لوحده:
//   1. **الميزان مايل:** آخر ٦٠ يوم، الترفيه (ترفيه، خروجات، مطاعم، كافيه، سينما، رحلات) أقل من ٥٪ من الصرف المصنّف، والروتين
//      (فواتير، إيجار، بقالة، مواصلات، صحة، تعليم، اشتراكات) ٦٠٪ أو أكتر. صرف أغلبه من غير تصنيف (أقل من ٧٠٪ مصنّف) = مانعرفش.
//   2. **فيه توفير فعلاً:** الدورة دي الصرف أبطأ من وتيرة السقف (velocity أقل من ٠٫٨٥ من zad_budget_state، وthreat = SAFE،
//      والمتاح بعد الالتزامات موجب). اللي اتوفّر = المتوقع لحد النهارده − الصرف.
// الميزانية المقترحة: ٣٠٪ من اللي اتوفّر وبحد ١٥٪ من المتاح — مش أكتر، والباقي يفضل توفير.
//
// مابيتقالش: في ظرف أو تعافي (الشريحة ٢٩ — احتفال مش وقته)، ولو العميل متفق يوفّر (تحدي توفير أو وضع «مفلس»)، ولا أكتر من مرة
// في الشهر (subject فيه الشهر). ومن غير «إنتوا مش بتتبسطوا» — اقتراح مش حكم.

import type { StaffNote } from "./staff.ts";
import { itemKey } from "./shared.ts";

const DAY = 86_400_000;

export const WELLBEING_WINDOW_DAYS = 60;
export const LEISURE_MAX_SHARE = 0.05;
export const ROUTINE_MIN_SHARE = 0.6;
export const PACE_SAVING = 0.85;

const LEISURE = ["ترفيه", "خروجات", "خروجه", "مطاعم", "مطعم", "كافيه", "قهوه", "سينما", "رحلات", "رحله", "فسحه", "العاب"].map(itemKey);
const ROUTINE = ["فواتير", "فاتوره", "ايجار", "بقاله", "سوبر ماركت", "مواصلات", "بنزين", "صحه", "صيدليه", "دوا", "تعليم", "مدارس", "اشتراكات", "كهربا", "مياه", "غاز", "انترنت"].map(itemKey);
const UNLABELLED = new Set(["", "اخرى", "عام", "غير مصنف", "other", "general"].map(itemKey));

export interface WellbeingTxn {
  amount: number | null;
  is_expense: boolean | null;
  txn_kind: string | null;
  category: string | null;
  created_at: string;
}

export interface Balance {
  leisure_share: number;
  routine_share: number;
  labelled_share: number;
}

/** الميزان آخر ٦٠ يوم؛ null = الداتا مش كفاية (أقل من ٤٥ يوم، أقل من ١٥ مصروف، أو أغلبه من غير تصنيف). */
export function balanceFrom(txns: readonly WellbeingTxn[], now: number): Balance | null {
  const since = now - WELLBEING_WINDOW_DAYS * DAY;
  const spends = txns.filter((t) => {
    const at = Date.parse(t.created_at);
    return Number.isFinite(at) && at >= since && at <= now && t.is_expense !== false && (!t.txn_kind || t.txn_kind === "expense");
  });
  if (spends.length < 15) return null;
  const oldest = Math.min(...spends.map((t) => Date.parse(t.created_at)));
  if (now - oldest < 45 * DAY) return null;
  let total = 0, labelled = 0, leisure = 0, routine = 0;
  for (const t of spends) {
    const amount = Math.max(0, Number(t.amount) || 0);
    total += amount;
    const key = itemKey(t.category ?? "");
    if (UNLABELLED.has(key)) continue;
    labelled += amount;
    if (LEISURE.some((w) => key.includes(w))) leisure += amount;
    else if (ROUTINE.some((w) => key.includes(w))) routine += amount;
  }
  if (total <= 0 || labelled / total < 0.7) return null;
  return { leisure_share: leisure / labelled, routine_share: routine / labelled, labelled_share: labelled / total };
}

export interface BudgetPace {
  threat?: string | null;
  velocity?: number | null;
  spent?: number | null;
  available?: number | null;
}

/** اللي اتوفّر الدورة دي لحد النهارده (المتوقع − الصرف)، أو null لو مفيش توفير حقيقي. */
export function savedSoFar(b: BudgetPace): number | null {
  const v = Number(b.velocity);
  const spent = Number(b.spent);
  const available = Number(b.available);
  if (b.threat !== "SAFE" || !(v > 0) || v >= PACE_SAVING || !(spent > 0) || !(available > 0)) return null;
  return spent / v - spent;
}

/** ميزانية النشاط: ٣٠٪ من اللي اتوفّر وبحد ١٥٪ من المتاح، مقرّبة لـ١٠. أقل من ٥٠ ⇒ مش مستاهلة. */
export function activityBudget(saved: number, available: number): number | null {
  const raw = Math.min(saved * 0.3, available * 0.15);
  const rounded = Math.floor(raw / 10) * 10;
  return rounded >= 50 ? rounded : null;
}

export function isOutOfBalance(b: Balance): boolean {
  return b.leisure_share < LEISURE_MAX_SHARE && b.routine_share >= ROUTINE_MIN_SHARE;
}

/** الملاحظة: الأرقام، والميزانية، والصياغة المطلوبة. subject فيه الشهر ⇒ مرة في الشهر. */
export function wellbeingNote(o: {
  balance: Balance; saved: number; budget: number; currency: string | null; family: boolean; month: string;
}): StaffNote {
  const pct = (x: number) => Math.round(x * 100);
  const cur = o.currency ? ` ${o.currency}` : "";
  return {
    sender: "family",
    subject: `ميزان الرفاهية — ${o.month}`,
    detail: `آخر ٦٠ يوم: الفواتير والبيت ${pct(o.balance.routine_share)}٪ من الصرف، والترفيه ${pct(o.balance.leisure_share)}٪ بس. ` +
      `والدورة دي الصرف أبطأ من السقف — اتوفّر حوالي ${Math.round(o.saved)}${cur}. ` +
      `اقترح ${o.family ? "نشاط للعيلة" : "حاجة تبسطه"} بسيط في حدود ${o.budget}${cur} (فسحة قريبة، سينما في البيت، أكلة برّه، رحلة يوم) ` +
      "بأفكار من بلده ولهجته — اقتراح لما الكلام يسمح، مش رسالة لوحده؛ ومن غير «إنتوا مش بتتبسطوا» ولا لوم على الفواتير، " +
      "ولو قال لأ سيبها.",
  };
}
