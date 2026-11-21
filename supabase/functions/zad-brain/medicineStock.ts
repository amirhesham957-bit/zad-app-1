// رصيد الدوا ونقطة إعادة الطلب في مكان واحد (ZAD_OR_PLAN م٣.٤)، فوق `_shared/or/pharmacyStock.ts`.
//
// قبل كده كان فيه تلات عتبات: اللقطة «٣ أيام»، ووصول الصيدلية والملخص الأسبوعي «٥ أيام»، والاتنين بيقسموا على
// daily_dose_count بس ومتجاهلين units_per_dose (حبايتين في الجرعة = الرصيد بيخلص في نص الوقت).
// دلوقتي: الاستهلاك اليومي = الجرعات × الوحدات، ونقطة إعادة الطلب = (٣ أيام توريد + يومين أمان) × الاستهلاك.
// ده نفس الـ٥ أيام بتاعة الملخص الأسبوعي (_agent_home_weekly_digest_for_user)، بس بالوحدات الصح.
// remaining_quantity بيتخصم منه أصلاً عند كل جرعة (doseDoor)، فهو الرصيد نفسه: dosesTakenSince = 0.
// اتقاس على الحي ٢١/١١: ٤ أدوية، كلهم units_per_dose = 1، وكلهم «قليل» بالقاعدة القديمة والجديدة.

import { dailyUse, daysOfSupply, shouldReorder, type PharmacyStockInput } from "../_shared/or/pharmacyStock.ts";

export interface MedicineRow {
  remaining_quantity: number | null;
  daily_dose_count: number | null;
  units_per_dose?: number | null;
}

function input(m: MedicineRow): PharmacyStockInput | null {
  const remaining = Number(m.remaining_quantity);
  if (m.remaining_quantity === null || m.remaining_quantity === undefined || !Number.isFinite(remaining)) return null;
  const times = Number(m.daily_dose_count ?? 0);
  const units = Number(m.units_per_dose ?? 1);
  return {
    restockQty: Math.max(0, remaining),
    dosesTakenSince: 0,
    unitsPerDose: Number.isFinite(units) && units > 0 ? units : 1,
    timesPerDay: Number.isFinite(times) && times > 0 ? times : 0,
  };
}

/** أيام الرصيد الكاملة. null = مفيش رصيد متسجل أو مفيش جدول جرعات. */
export function medicineDaysLeft(m: MedicineRow): number | null {
  const i = input(m);
  if (!i) return null;
  const d = daysOfSupply(i);
  return d === null ? null : Math.floor(d);
}

/** محتاج يتطلب دلوقتي: الرصيد خلص، أو وصل لنقطة إعادة الطلب (٥ أيام استهلاك). من غير جدول = بس لو خلص. */
export function medicineLow(m: MedicineRow): boolean {
  const i = input(m);
  if (!i) return false;
  if (i.restockQty <= 0) return true;
  return dailyUse(i) > 0 && shouldReorder(i);
}
