// م٩.١ وم٩.٢ (ZAD_OR_PLAN): الذاكرة الزمنية في remember.
//
// - م٩.١: لما العميل نفسه بيقول الحقيقة الجديدة في الشات، كلامه هو الحسم: القديمة المتناقضة بتتقفل
//   (zad_memory_resolve_conflict) من غير ما نسأله «أنهي الصح؟» على حاجة لسه قايلها. برّه الشات (الاستخلاص الليلي،
//   لفة من غير كلام عميل) مفيش حسم، فالتعارض بيترفض ويتسأل عليه زي الأول.
// - م٩.٢: الحقيقة بتتربط بفرد من البيت (zad_household_members بالاسم)، والعادة بتتوقف مؤقتاً (zad_memory_pause)
//   مش بتتقفل.

import { itemKey } from "./shared.ts";

export type HouseholdMember = { id: string; display_name: string; kind: string };

/** الفرد اللي اسمه كده في البيت، أو null. «أنا»/«نفسي» = صف self. المطابقة بـitemKey (من غير تشكيل وهمزات). */
export function memberIdFor(name: unknown, members: ReadonlyArray<HouseholdMember>): string | null {
  if (typeof name !== "string" || !name.trim()) return null;
  const key = itemKey(name.trim());
  if (!key) return null;
  if (["انا", "نفسي", "انا نفسي"].includes(key)) return members.find((m) => m.kind === "self")?.id ?? null;
  return members.find((m) => itemKey(m.display_name) === key)?.id ?? null;
}

/** تعارض مع ملاحظة حية: العميل قالها في الشات ⇒ الجديدة بتقفل القديمة. غير كده ⇒ نسأل. */
export function conflictAction(heard: string | undefined | null): "supersede" | "ask" {
  return heard && heard.trim() ? "supersede" : "ask";
}

/** الملاحظة في الـSNAPSHOT: «متوقفة لحد» و«عن مين» بس لو ليهم قيمة. */
export function temporalFields(m: { paused_until?: string | null; member?: string | null }): {
  paused_until?: string;
  member?: string;
} {
  return {
    ...(m.paused_until ? { paused_until: String(m.paused_until).slice(0, 10) } : {}),
    ...(m.member ? { member: m.member } : {}),
  };
}

/** أكواد رفض دوال الذاكرة الزمنية ⇐ جملة للموديل. */
export const MEMORY_TIME_REASONS: Record<string, string> = {
  unknown_note: "الملاحظة اللي بتشاور عليها مش موجودة في memory.",
  note_not_live: "الملاحظة دي اتقفلت أو انتهت خلاص — مش هتتوقف.",
  pause_end_passed: "معاد رجوع العادة لازم يبقى يوم جاي.",
  pause_too_long: "الإيقاف المؤقت أقصاه سنة. لو العادة وقفت خالص سجّل حقيقة جديدة بدلها.",
  pause_reason_length: "اكتب السبب في note في جملة قصيرة («وقف الجيم أسبوع عشان رجله»).",
  not_paused: "العادة دي مش متوقفة دلوقتي.",
  member_not_in_household: "الفرد ده مش في أفراد البيت.",
};

export function memoryTimeRefusal(reason: unknown): string {
  return "مرفوض: " + (MEMORY_TIME_REASONS[String(reason)] ?? `ماقدرتش (${String(reason)}).`);
}
