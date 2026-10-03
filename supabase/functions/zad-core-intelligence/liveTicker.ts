// شريط الأسعار الحية من غير موديل بحث (٢٠٢٦-١٠-٠٣).
//
// الشريط كان بيعتمد على Groq compound بس، والمشروع ده مالوش موديلات بحث على Groq دلوقتي (فحص القبول:
// groq_search_models = []) — فالشريط كان بيقول «تعذر جلب الأسعار الحية» دايماً. وكان بيسأل عن سلة
// سعودية (بنزين ٩١/٩٥) حتى لعميل في مصر. دلوقتي: الدهب من عناوين الأخبار (goldPriceToday) والعملات من
// zad_fx_rates (بيتحدث كل يوم من zad-fx-refresh). أرقام مقرية، مش مكتوبة بموديل. صافي عشان يتختبر.

import type { GoldQuote } from "./searchQuality.ts";

export interface TickerItem { symbol: string; price: number; unit: string; change_percent: number; trend: "up" | "down" | "flat" }

/** العملات اللي بتتعرض في كل سوق، بالترتيب. أسماء عرض للعميل (عربي — الشريط عربي). */
const FOREIGN: Record<string, string> = {
  USD: "الدولار",
  SAR: "الريال السعودي",
  AED: "الدرهم الإماراتي",
  KWD: "الدينار الكويتي",
  EGP: "الجنيه المصري",
};

/** اسم البلد بالعربي (اللي التطبيق بيبعته في `location`) ⇒ الكود. */
const BY_NAME: Record<string, string> = {
  "مصر": "EG", "السعودية": "SA", "الإمارات": "AE", "الكويت": "KW", "قطر": "QA", "البحرين": "BH",
  "عمان": "OM", "عُمان": "OM", "الأردن": "JO",
};

/** null = سوق مش معروف هنا: مفيش شريط أحسن من شريط بعملة بلد تاني. */
export function countryForLocation(location: unknown): string | null {
  const name = typeof location === "string" ? location.trim() : "";
  if (/^[A-Za-z]{2}$/.test(name)) {
    const code = name.toUpperCase();
    return Object.values(BY_NAME).includes(code) ? code : null;
  }
  return BY_NAME[name] ?? null;
}

const round = (n: number) => (n >= 100 ? Math.round(n) : Math.round(n * 100) / 100);

/**
 * [usdRates]: كود ⇒ قيمة الوحدة بالدولار (عمود usd_rate في zad_fx_rates). الجنيه 0.0191 = الدولار ٥٢٫٣ جنيه.
 * [currency]/[currencyAr]: عملة السوق ده.
 */
export function buildTicker(
  gold: GoldQuote[],
  usdRates: Record<string, number>,
  currency: string,
  currencyAr: string,
): TickerItem[] {
  const items: TickerItem[] = [];
  for (const karat of ["21", "24"]) {
    const q = gold.find((g) => g.karat === karat);
    if (q && q.price > 0) {
      items.push({ symbol: `دهب عيار ${karat}`, price: round(q.price), unit: `${currencyAr}/جرام`, change_percent: 0, trend: "flat" });
    }
  }
  const local = usdRates[currency];
  if (local && local > 0) {
    for (const [code, name] of Object.entries(FOREIGN)) {
      if (code === currency) continue;
      const foreign = usdRates[code];
      if (!foreign || foreign <= 0) continue;
      items.push({ symbol: name, price: round(foreign / local), unit: currencyAr, change_percent: 0, trend: "flat" });
    }
  }
  return items;
}
