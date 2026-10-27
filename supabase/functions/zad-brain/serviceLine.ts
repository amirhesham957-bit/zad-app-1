// serviceLine.ts — سطر فاتورة مش صنف: توصيل، رسوم، خدمة، ضريبة، خصم، إجمالي.
//
// اتقاس ٢٨/١٠ على حساب المالك: «توصيل منزلي داخل 600» من فاتورة صيدلية اتسجل دوا، وتحية الصبح سألت
// «بيتاخد الساعة كام؟». القايمة دي بيانات مطابقة (بتتقارن بنص الفاتورة)، مش نص عرض — ماتترجمش.
// نفس الكلمات في فلاتر: `zad_flutter/lib/shared/pharmacy/domain/pharmacy_intake.dart` (isServiceLine).

const SERVICE_WORDS = [
  "توصيل", "توصيله", "رسوم", "رسم", "خدمه", "خدمات", "شحن", "ضريبه", "مضافه", "اكراميه", "بقشيش",
  "خصم", "اجمالي", "الاجمالي", "المجموع", "مجموع", "باقي", "delivery", "service", "fee", "fees",
  "shipping", "vat", "tax", "tip", "discount", "total", "subtotal",
];

const fold = (s: string) =>
  s.replace(/[ً-ْـ]/g, "").replace(/[أإآ]/g, "ا").replace(/ة/g, "ه").replace(/ى/g, "ي").toLowerCase();

/** الاسم ده سطر خدمة أو حساب مش صنف؟ كلمة كاملة بس («خدمة» آه، «مستخدم» لأ). */
export function isServiceLine(name: string | null | undefined): boolean {
  const words = fold(String(name ?? "")).split(/[^\p{L}]+/u).filter(Boolean);
  return words.some((w) => SERVICE_WORDS.includes(w) || (w.startsWith("ال") && SERVICE_WORDS.includes(w.slice(2))));
}
