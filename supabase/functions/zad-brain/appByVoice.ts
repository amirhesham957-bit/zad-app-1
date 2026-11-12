// ZAD_PLAN ١٠.٢(أ) شريحة ٢: اللي بيتعمل من شاشة يتعمل بالكلام — القواعد الصافية بتاعة الأدوات الجديدة،
// منقولة من التطبيق نفسه عشان الكلام والزرار يعملوا نفس الحاجة بالظبط. صافي عشان يتختبر من غير داتابيز.

import { nextRenewal } from "../_shared/nextRenewal.ts";
import { resolveLocalIso } from "./shared.ts";

// ── «دفعت الاشتراك» (SubscriptionsRepository.markPaid + categoryForCharge في التطبيق) ──

/** «(3 أقساط)» في الاسم: عدّاد الأقساط اللي فاضلة — نفس `_instalments` في subscription.dart. */
const INSTALMENTS = /\((\d+)\s*(?:أقساط|قسط|installments?)\)/i;

/** بعد قسط اتدفع: «(3 أقساط)» ⇐ «(2 أقساط)»، وآخر قسط بيشيل العداد ويوقّف الاشتراك. */
export function afterInstalmentPaid(title: string): { title: string; stillRunning: boolean } {
  const m = INSTALMENTS.exec(title);
  if (!m) return { title, stillRunning: true };
  const remaining = Number(m[1]) || 1;
  if (remaining > 1) return { title: title.replace(m[0], `(${remaining - 1} أقساط)`), stillRunning: true };
  return { title: title.replace(m[0], "").trim(), stillRunning: false };
}

const STANDARD_CATEGORIES = new Set([
  "البقالة", "المطاعم", "الفواتير", "المواصلات", "الوقود", "الاشتراكات", "الأقساط",
  "الرعاية الصحية", "التعليم", "الترفيه", "الملابس", "تحويلات", "أخرى",
]);

/** الفئة اللي الدفعة بتتسجل عليها — فئة الاشتراك لو قياسية، وإلا من نوعه. */
export function categoryForCharge(sub: { category?: string | null; type?: string | null }): string {
  if (sub.category && STANDARD_CATEGORIES.has(sub.category)) return sub.category;
  switch (sub.type) {
    case "utility": case "bill": case "rent": return "الفواتير";
    case "installment": return "الأقساط";
    default: return "الاشتراكات";
  }
}

function addDays(isoDate: string, days: number): string {
  return new Date(Date.parse(`${isoDate}T00:00:00Z`) + days * 86_400_000).toISOString().slice(0, 10);
}

export interface PaidRenewal {
  /** الدفعة اللي اتدفعت (أول تجديد من النهارده)، أو null لو مفيش تاريخ يتحسب منه. */
  paidFor: string | null;
  /** التجديد الجاي بعدها — ده اللي بيتكتب في renewal_date. */
  next: string | null;
  title: string;
  stillRunning: boolean;
}

/** نفس markPaid: الدفعة المستحقة من النهارده، والتجديد اللي بعدها، والأقساط. */
export function paidRenewal(
  sub: { title: string; renewal_date?: string | null; due_day?: number | null; billing_cycle?: string | null },
  today: string,
): PaidRenewal {
  const due = nextRenewal(sub.renewal_date, sub.due_day, sub.billing_cycle, today);
  // من نفس المرساة (renewal_date/due_day) مش من الدفعة: إيجار يوم ٣١ اتدفع ٣٠ نوفمبر يرجع ٣١ ديسمبر، مش ٣٠.
  const next = due ? nextRenewal(sub.renewal_date, sub.due_day, sub.billing_cycle, addDays(due, 1)) : null;
  const inst = afterInstalmentPaid(sub.title);
  return { paidFor: due, next, title: inst.title, stillRunning: inst.stillRunning };
}

// ── تأجيل جرعة (زرار «فكّرني بعدين» في الصيدلية) ──

const HHMM = /^([01]\d|2[0-3]):[0-5]\d$/;

/** مواعيد الدوا من `dose_times` («01:30,13:30») — المكتوب صح بس. */
export function doseTimesOf(raw: string | null | undefined): string[] {
  return String(raw ?? "").split(/[,،\s]+/).map((t) => t.trim()).filter((t) => HHMM.test(t));
}

/**
 * خانة الجرعة اللي العميل بيأجّلها، بتوقيته: الميعاد اللي قاله لو من مواعيد الدوا، وإلا أقرب ميعاد النهارده
 * في نافذة [٣ ساعات فاتت، ساعة جاية] — الجرعة اللي لسه رنّت أو هترن. برّه النافذة = مفيش جرعة يتأجل.
 * بيرجّع scheduled_at بـUTC، نفس اللي الكرون بيحسبه: (تاريخ محلي + الميعاد) في منطقة العميل.
 */
export function doseSlotToSnooze(
  doseTimes: string | null | undefined,
  now: { date: string; time: string; utc_offset: string },
  chosen?: string | null,
): string | null {
  const times = doseTimesOf(doseTimes);
  if (times.length === 0) return null;
  const minutes = (t: string) => Number(t.slice(0, 2)) * 60 + Number(t.slice(3, 5));
  const nowMin = minutes(now.time);
  let pick: string | null = null;
  if (chosen) {
    if (!times.includes(chosen)) return null;
    pick = chosen;
  } else {
    const near = times
      .map((t) => ({ t, d: minutes(t) - nowMin }))
      .filter(({ d }) => d >= -180 && d <= 60)
      .sort((a, b) => Math.abs(a.d) - Math.abs(b.d));
    pick = near[0]?.t ?? null;
  }
  return pick ? resolveLocalIso(`${now.date}T${pick}`, now.utc_offset) : null;
}

// ── قفل رؤية (زرار «مش مهم ليا / الرقم غلط / عرفت خلاص» على الكارت) ──

export const DISMISS_REASONS = ["not_relevant", "wrong_data", "timing"] as const;
export type DismissReason = typeof DISMISS_REASONS[number];

/** الملاحظة اللي القفل بيسيبها للعقل — بالحرف زي `dismissalNote` في التطبيق، عشان الاتنين يعلّموه نفس الحاجة. */
export function dismissalNote(reason: DismissReason, subject: string): { scope: string; note: string; confidence: number } {
  switch (reason) {
    case "not_relevant": return { scope: "dismissal", note: `مش مهتم بتنبيهات زي "${subject}"`, confidence: 0.5 };
    case "wrong_data": return { scope: "data_quality", note: `العميل قال إن "${subject}" غلط — البيانات المصدر محتاجة مراجعة`, confidence: 0.7 };
    case "timing": return { scope: "dismissal", note: `عرف بالفعل عن "${subject}" وقت الرفض ده`, confidence: 0.3 };
  }
}

export interface ShownInsight { id: string; title: string | null; body?: string | null; about_item?: string | null }

const fold = (s: string) => s.trim().toLowerCase()
  .replace(/[أإآ]/g, "ا").replace(/ة/g, "ه").replace(/ى/g, "ي").replace(/[ًٌٍَُِّْـ]/g, "");

/** الرؤية اللي العميل بيتكلم عنها، من المعروض عليه بس: واحدة واضحة، أو أكتر (يتسأل)، أو مفيش. */
export function matchInsight(rows: ShownInsight[], spoken: string): { row?: ShownInsight; ambiguous?: string[] } {
  const want = fold(spoken);
  if (want.length < 2) return {};
  const hits = rows.filter((r) => [r.title, r.about_item, r.body].some((f) => {
    const have = fold(String(f ?? ""));
    return have.length > 0 && (have.includes(want) || (have.length >= 3 && want.includes(have)));
  }));
  if (hits.length === 1) return { row: hits[0] };
  if (hits.length > 1) return { ambiguous: hits.map((r) => r.title ?? "").filter(Boolean).slice(0, 5) };
  return {};
}
