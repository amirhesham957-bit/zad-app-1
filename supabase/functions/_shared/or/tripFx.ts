// تحويل عملة الرحلة (م٧.٣): rate = وحدات عملة الرحلة مقابل وحدة واحدة من العملة الأصلية.
// مثال: rate = 3.67 يعني ١ من العملة الأصلية = ٣.٦٧ من عملة الرحلة.
// دالة نقية: مافيش I/O.

function round2(x: number): number {
  return Math.round(x * 100) / 100;
}

/** يتأكد إن السعر موجب، وإن الناتج بعد القسمة رقم محدود. غير كده بيرمي RangeError. */
function assertRate(amount: number, rate: number): void {
  if (!(rate > 0)) throw new RangeError("السعر لازم يكون أكبر من صفر");
  if (!Number.isFinite(amount / rate)) throw new RangeError("الناتج مش رقم محدود");
}

/** المبلغ بالعملة الأصلية ← عملة الرحلة: amount × rate، مقرّب لمنزلتين. */
export function convertTrip(amount: number, rate: number): number {
  assertRate(amount, rate);
  return round2(amount * rate);
}

/** عملة الرحلة ← العملة الأصلية: amount ÷ rate، مقرّب لمنزلتين. */
export function homeEquivalent(amount: number, rate: number): number {
  assertRate(amount, rate);
  return round2(amount / rate);
}

/**
 * الوقت المحلي "HH:MM" لنفس اللحظة بعد إزاحة offsetMinutes.
 * الحساب بالـUTC عشان نتفادى مشاكل المنطقة الزمنية بتاعة الجهاز، والـwrap على منتصف الليل بيتعامل صح.
 */
export function localTimeOf(utcISO: string, offsetMinutes: number): string {
  const base = Date.parse(utcISO);
  if (!Number.isFinite(base)) throw new RangeError("التاريخ مش صالح");
  const d = new Date(base + offsetMinutes * 60_000);
  const hh = String(d.getUTCHours()).padStart(2, "0");
  const mm = String(d.getUTCMinutes()).padStart(2, "0");
  return `${hh}:${mm}`;
}
