// معدل الاستهلاك (zad_consumption) زي ما العقل وتليجرام بيقروه — نفس قواعد SQL.
//
// الفجوة ٧ (20260930000000): معدل من دورة شرا واحدة بيتخزن rate_known = false و
// avg_daily_qty > 0. قبل كده الاتنين كانوا بيتجاهلوه لحد ٣ نزلات، والتعلّم كان
// بياخد شهور.

export type RateConfidence = "known" | "approximate" | "unknown";

/** known = ٣ نزلات على يومين · approximate = دورة أو اتنين · unknown = مفيش معدل. */
export function rateConfidence(avgDailyQty: number | null | undefined, rateKnown: boolean | null | undefined): RateConfidence {
  const hasRate = Number(avgDailyQty) > 0;
  if (!hasRate) return "unknown";
  return rateKnown ? "known" : "approximate";
}

/**
 * يستاهل سؤال «لسه موجود ولا خلص؟»: تحت حد العميل (٢ لو مش محطوط)، أو هيخلص خلال
 * يومين بأي معدل — المؤكد أو التقريبي، لأن السؤال نفسه هو التأكيد. نفس
 * `_inventory_needs_checkin` في SQL.
 */
export function needsCheckIn(
  quantity: number,
  threshold: number | null | undefined,
  avgDailyQty: number | null | undefined,
  createdAt?: string | null,
  now: number = Date.now(),
): boolean {
  // اللي كميته صفر خلص فعلاً — مكانه قايمة الشرا، مش «لسه عندك؟». المالك ١/١١: «بيسألني على حاجات
  // خلصانة من شهرين» — مياه نستله اتسألت ٣ مرات وهي صفر.
  if (!(quantity > 0)) return false;
  // المالك ٤/١١: لما معدل البيت معروف هو اللي بيحكم (يومين أو أقل)، مش الحد الثابت — لبن اتضاف بـ١٫٥
  // كان بيتسأل عنه من أول دقيقة. ومن غير معدل: الحد، بس مش على صنف اتضاف في آخر ٢٤ ساعة — العميل لسه
  // قايل عنده كام. نفس قاعدة الموبايل (shortage.dart) و_inventory_needs_checkin.
  const rate = Number(avgDailyQty);
  if (rate > 0) return quantity / rate <= 2;
  if (createdAt && now - Date.parse(createdAt) < 24 * 3600_000) return false;
  return quantity <= (threshold ?? 2);
}
