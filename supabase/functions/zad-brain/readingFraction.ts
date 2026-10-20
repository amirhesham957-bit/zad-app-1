// «الزيت فاضل نصه» (ZAD_PLAN ٣.٩): نسبة من العبوة، مش رقم. الكمية = النسبة × آخر كمية بعد شرا
// (zad_inventory_observations، source = purchase) — ده «المليان» اللي العميل بيقيس عليه في دماغه.
// من غير شرا متسجل: الكمية اللي في المخزون دلوقتي هي المرجع. الحساب هنا مش في الموديل، عشان
// «نص» يبقى نص كل مرة.

/** الكمية من نسبة. null = مفيش مرجع نحسب منه (والنسبة مش صفر). */
export function qtyFromFraction(fraction: number, fullQty: number | null, currentQty: number | null): number | null {
  if (!Number.isFinite(fraction) || fraction < 0 || fraction > 1) return null;
  if (fraction === 0) return 0;
  const ref = fullQty !== null && fullQty > 0 ? fullQty : currentQty !== null && currentQty > 0 ? currentQty : null;
  if (ref === null) return null;
  return Math.round(ref * fraction * 1000) / 1000;
}
