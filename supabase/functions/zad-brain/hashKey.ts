// Task 26 (PRODUCT_PLAN.md) — dedupe_key محسوب هنا (مش من الموديل) نفس مبدأ isoWeekKey/
// cycle_start_confirm_ فوق: مفتاح ثابت لكل (تاجر، مبلغ)، مش hash عشوائي، عشان upsert/رفض
// يبقى idempotent. FNV-1a-ish بسيط، مش لأمان — بس عشان ascii ثابت من نص عربي حر.
export function hashKey(s: string): string {
  let h = 5381;
  for (let i = 0; i < s.length; i++) h = ((h << 5) + h + s.charCodeAt(i)) >>> 0;
  return h.toString(36);
}
