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
export function needsCheckIn(quantity: number, threshold: number | null | undefined, avgDailyQty: number | null | undefined): boolean {
  if (quantity <= (threshold ?? 2)) return true;
  const rate = Number(avgDailyQty);
  return rate > 0 && quantity / rate <= 2;
}
