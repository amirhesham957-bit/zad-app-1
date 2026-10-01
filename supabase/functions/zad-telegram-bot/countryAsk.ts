// «انت في أنهي بلد؟» — مرة واحدة لحساب تليجرام من غير بلد (٢٠٢٦-١٠-٠١).
//
// حساب من غير بلد بيتحسب على توقيت القاهرة (`zad_market_timezone`، ‎20261001170000)،
// فعميل في الرياض أو الدار البيضاء بتوصله تحية الصبح والجرعات بفرق ساعة أو أكتر.
// البوت بيسأله مرة واحدة بزراير، والزرار بيكتب البلد والعملة في `zad_users` زي ما
// شاشة اختيار السوق في التطبيق بتعمل بالظبط (`setMarket`). صافي عشان يتختبر —
// الداتابيز والإرسال في index.ts.

import type { InlineKeyboardButton } from "./telegram.ts";

/** نفس البلاد اللي `zad_market_timezone` عارف توقيتها. الكود والعملة بيتكتبوا في الداتابيز — مايتترجموش. */
export const COUNTRY_CHOICES: ReadonlyArray<{ country: string; currency: string; label: string }> = [
  { country: "EG", currency: "EGP", label: "🇪🇬 مصر" },
  { country: "SA", currency: "SAR", label: "🇸🇦 السعودية" },
  { country: "AE", currency: "AED", label: "🇦🇪 الإمارات" },
  { country: "KW", currency: "KWD", label: "🇰🇼 الكويت" },
  { country: "QA", currency: "QAR", label: "🇶🇦 قطر" },
  { country: "BH", currency: "BHD", label: "🇧🇭 البحرين" },
  { country: "OM", currency: "OMR", label: "🇴🇲 عمان" },
  { country: "JO", currency: "JOD", label: "🇯🇴 الأردن" },
  { country: "IQ", currency: "IQD", label: "🇮🇶 العراق" },
  { country: "LB", currency: "LBP", label: "🇱🇧 لبنان" },
  { country: "MA", currency: "MAD", label: "🇲🇦 المغرب" },
  { country: "TN", currency: "TND", label: "🇹🇳 تونس" },
  { country: "DZ", currency: "DZD", label: "🇩🇿 الجزائر" },
  { country: "LY", currency: "LYD", label: "🇱🇾 ليبيا" },
];

export const COUNTRY_QUESTION =
  "سؤال واحد عشان التنبيهات تيجي في وقتها: انت في أنهي بلد؟\n(لحد ما تختار، مواعيدك ماشية على توقيت مصر.)";

const PREFIX = "cty:";

export function countryKeyboard(): InlineKeyboardButton[][] {
  const rows: InlineKeyboardButton[][] = [];
  for (let i = 0; i < COUNTRY_CHOICES.length; i += 2) {
    rows.push(COUNTRY_CHOICES.slice(i, i + 2).map((c) => ({ text: c.label, callback_data: `${PREFIX}${c.country}` })));
  }
  return rows;
}

/** `null` لو الزرار مش زرار بلد، أو بلد مش في القايمة (callback_data جاي من العميل). */
export function parseCountryCallback(data: string | undefined): { country: string; currency: string; label: string } | null {
  if (!data?.startsWith(PREFIX)) return null;
  const code = data.slice(PREFIX.length);
  return COUNTRY_CHOICES.find((c) => c.country === code) ?? null;
}

/** يتسأل بس لو مفيش بلد ومااتسألش قبل كده. */
export function shouldAskCountry(country: string | null | undefined, askedAt: string | null | undefined): boolean {
  return !(country ?? "").trim() && !askedAt;
}

export function countrySavedReply(label: string): string {
  return `تمام، ${label} ✅ — التنبيهات والجرعات هتيجي على توقيتك من النهارده.`;
}
