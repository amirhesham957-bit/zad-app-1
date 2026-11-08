// commute.ts — مواعيد يوم العميل (طلب المالك ٨/١١). الموبايل بيحسبها من خروجه ورجوعه للبيت، وبموافقة منفصلة.
//
// اللي بيوصل هنا مواعيد وأيام بس، مفيش إحداثيات. ملاحظة واحدة في zad_memory بسكوب commute_pattern، شخصية (family_id فاضي)، وبتتمسح لما يقفل.

export const COMMUTE_SCOPE = "commute_pattern";
export const COMMUTE_MIN_SAMPLES = 8;

const DAYS_AR: Record<number, string> = { 1: "الاتنين", 2: "التلات", 3: "الأربع", 4: "الخميس", 5: "الجمعة", 6: "السبت", 7: "الأحد" };
const HHMM = /^([01]\d|2[0-3]):[0-5]\d$/;

export type CommuteRequest = { clear: true } | { clear: false; note: string };

/** الطلب بعد التحقق، أو null لو مش مقبول. الموبايل مش مصدر موثوق: الشكل والعدد بيتفحصوا هنا. */
export function readCommute(body: Record<string, unknown>): CommuteRequest | null {
  if (body.clear === true) return { clear: true };
  const { leave, back, days, samples } = body;
  if (typeof leave !== "string" || !HHMM.test(leave) || typeof back !== "string" || !HHMM.test(back)) return null;
  if (typeof samples !== "number" || samples < COMMUTE_MIN_SAMPLES || !Array.isArray(days) || days.length === 0 || days.length > 7) return null;
  const set = [...new Set(days as unknown[])];
  if (!set.every((d) => typeof d === "number" && DAYS_AR[d])) return null;
  const names = (set as number[]).sort((a, b) => a - b).map((d) => DAYS_AR[d]).join(" و");
  return { clear: false, note: `عادةً بينزل من البيت حوالي ${leave} ويرجع حوالي ${back} (${names}). محسوب من خروجه ورجوعه، فممكن يتغير.` };
}
