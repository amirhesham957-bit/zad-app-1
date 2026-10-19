// تنقيح رسالة بنك حقيقية قبل ما تدخل bank_corpus.json (ZAD_PLAN ٣.٧).
//
// اللي بيتشال: أرقام الكروت والحسابات والمرجع، أرقام الموبايل، الإيميل وعناوين إنستاباي، والرصيد.
// اللي بيفضل: المبلغ نفسه (هو اللي بيتقاس)، الوقت والتاريخ، اسم التاجر، وشكل الرسالة كله.
// الأسماء مابتتعرفش لوحدها — الأداة بترجع الكلام اللي بعد «من/إلى» عشان حد يبص عليه قبل الحفظ.

const DIGIT_MAP: Record<string, string> = {
  "٠": "0", "١": "1", "٢": "2", "٣": "3", "٤": "4", "٥": "5", "٦": "6", "٧": "7", "٨": "8", "٩": "9",
};
const latin = (s: string) => s.replace(/[٠-٩]/g, (d) => DIGIT_MAP[d]);

/** نفس الطول والشكل، بأرقام مش بتاعت حد: 1234 1234… */
const filler = (digits: string) => digits.replace(/\d|[٠-٩]/g, (_, i: number) => String((i % 4) + 1));

const BALANCE = /(الرصيد(?:\s+(?:المتاح|الحالي|المتبقي))?|رصيدك(?:\s+(?:الحالي|المتاح))?|balance|avail(?:able)?\s*bal(?:ance)?)\s*[:：]?\s*(?:[A-Za-z.]{0,4}|ج\.م|جنيه|ر\.س)?\s*([0-9٠-٩][0-9٠-٩,٬.٫]*)/gi;
const PHONE = /(\+?(?:20|966)\s?)?(0?1[0125]\d{8}|05\d{8})/g;
const EMAIL = /[\p{L}\p{N}._%+-]+@[\p{L}\p{N}.-]+/gu;
const LONG_RUN = /[0-9٠-٩]{4,}/g;
const NAME_AFTER =
  /(?:^|\s)(?:من|إلى|الى|الي|لـ|to|from)\s*[:：]?\s*([^\s\d:،,]{2,}(?:\s+(?!(?:على|في|بطاقة|ببطاقة|on|at|via)(?:\s|$))(?!علي\s+(?:بطاقة|حساب))[^\s\d:،,]{2,})?)/giu;

export interface Redacted {
  text: string;
  /** الكلام اللي بعد «من/إلى» — ممكن يبقى تاجر (يفضل) أو اسم شخص (يتغيّر بإيد). */
  reviewNames: string[];
}

/** [amount] = المبلغ اللي بيتقاس: أي رقم يساويه بيفضل زي ما هو. */
export function redactBankMessage(raw: string, amount: number | null): Redacted {
  const isAmount = (s: string) => {
    const n = Number(latin(s).replace(/[,٬]/g, "").replace("٫", "."));
    return amount != null && Number.isFinite(n) && Math.abs(n - amount) < 0.005;
  };
  let t = raw;
  t = t.replace(EMAIL, (m) => `user@${m.split("@")[1]}`);
  t = t.replace(BALANCE, (m, _label: string, value: string) => (isAmount(value) ? m : m.replace(value, filler(value))));
  t = t.replace(PHONE, (m) => m.replace(/\d/g, (d, i: number) => (i < 3 ? d : "0")));
  t = t.replace(LONG_RUN, (m: string, at: number, all: string) => {
    if (isAmount(m)) return m;
    // A date's year (30/9/2026, 2026-10-12) and a phone number masked above stay.
    const dated = /^(19|20)\d\d$/.test(latin(m)) && (/[\/-]/.test(all[at - 1] ?? "") || /[\/-]/.test(all[at + m.length] ?? ""));
    if (dated || /^(0?1[0125]|05)0+$/.test(m)) return m;
    return filler(m);
  });
  const reviewNames = [...t.matchAll(NAME_AFTER)].map((m) => m[1].trim()).filter((n) => !/^\d/.test(n));
  return { text: t, reviewNames: [...new Set(reviewNames)] };
}
