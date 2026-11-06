// chefInputs.ts — اللي شيف زاد بتشوفه: المخزن من السيرفر، اللي اتعرض قبل كده، والأكلات الرايجة (بلاغ المالك ٦/١١).
//
// البلاغ: «الوصفات مبتتغيرش، ومفيش الطبخات الترند، ومش من المخزون رغم زيادته، ومبقدرش أعمل رفرش يجيبلي جديد».
// المقاس على الحي ٦/١١: آخر نداء لحساب المالك (٥/١١ ٠٠:٥٠) شاف «حليب (1½), مياه (4)» بس، والمخزن على السيرفر فيه
// ٨ أصناف (برتقال، سمن، حلاوة، حليب ٣٫٥، مياه ١٠…) — التطبيق بيبعت نسخته المحلية من المخزن، وممكن تكون متأخرة.
// وزرار «اقتراحات جديدة» بنفس المخزن كان بيرجّع نفس الرد من كاش الـ٦ ساعات (المفتاح = العميل + نص المخزن).

/** صف من zad_inventory. */
export interface PantryRow {
  item_name: string | null;
  quantity: number | string | null;
  unit?: string | null;
}

const MAX_PANTRY_ITEMS = 60;

const qty = (n: number) => Number.isInteger(n) ? String(n) : String(Math.round(n * 100) / 100);

/**
 * المخزن زي ما الشيف بتسمعه: «اسم (كمية)» مترتب، والمتكرر بيتجمع. نفس شكل التطبيق (`pantryForChef`)، فمخزن ماتغيرش
 * = نفس النص. فاضي = "" (المستدعي بيرجع لنص التطبيق).
 */
export function chefPantryLine(rows: readonly PantryRow[] | null | undefined): string {
  const byName = new Map<string, { name: string; q: number }>();
  for (const r of rows ?? []) {
    const name = String(r.item_name ?? "").replace(/[\n\r=]+/g, " ").trim().slice(0, 60);
    const q = Number(r.quantity);
    if (!name || !Number.isFinite(q) || q <= 0) continue;
    const key = name.toLowerCase();
    const prev = byName.get(key);
    byName.set(key, { name: prev?.name ?? name, q: (prev?.q ?? 0) + q });
  }
  return [...byName.values()]
    .sort((a, b) => a.name.localeCompare(b.name))
    .slice(0, MAX_PANTRY_ITEMS)
    .map((p) => `${p.name} (${qty(p.q)})`)
    .join(", ");
}

/** أسامي الوصفات اللي العميل شافها وعايز غيرها: نص، من غير تكرار، ١٢ بالكتير، كل اسم ٦٠ حرف. */
export function avoidNames(raw: unknown): string[] {
  if (!Array.isArray(raw)) return [];
  const out: string[] = [];
  for (const v of raw) {
    const s = typeof v === "string" ? v.replace(/[\n\r=]+/g, " ").trim().slice(0, 60) : "";
    if (s && !out.includes(s)) out.push(s);
    if (out.length >= 12) break;
  }
  return out;
}

/** اسم البلد في البحث عن الأكلات الرايجة. بلد مش معروف = بحث من غير بلد. */
const COUNTRY_AR: Record<string, string> = {
  EG: "مصر", SA: "السعودية", AE: "الإمارات", KW: "الكويت", QA: "قطر", BH: "البحرين", OM: "عمان", JO: "الأردن",
  LB: "لبنان", IQ: "العراق", SY: "سوريا", YE: "اليمن", PS: "فلسطين", LY: "ليبيا", SD: "السودان", MA: "المغرب",
  TN: "تونس", DZ: "الجزائر",
};

/** البحث: «أكلات ترند في مصر نوفمبر 2026». */
export function trendQuery(country: string | null | undefined, now = new Date()): string {
  const month = new Intl.DateTimeFormat("ar", { month: "long" }).format(now);
  const where = COUNTRY_AR[String(country ?? "").toUpperCase()];
  return `أكلات ترند ${where ? `في ${where} ` : ""}${month} ${now.getUTCFullYear()} وصفات رايجة`;
}

/** مفتاح كاش نتايج البحث: بلد واحد، يوم واحد — بحث واحد في اليوم لكل بلد مهما العملا طلبوا. */
export function trendCacheKey(country: string | null | undefined, now = new Date()): string {
  return `chef_trends:v1:${String(country ?? "xx").toUpperCase()}:${now.toISOString().slice(0, 10)}`;
}

export interface TrendHit {
  title: string;
  snippet: string;
}

/**
 * نتايج البحث كقسم بيانات محدود للبرومبت. نص من الويب = بيانات بس (قاعدة الحقن في CLAUDE.md)، فبيتنضف من «===» وسطور
 * جديدة عشان مايقدرش يقفل القسم أو يفتح قسم تاني. مفيش نتايج = "" (الشيف مابتعملش مجموعة ترند خالص).
 */
export function trendBlock(hits: readonly TrendHit[] | null | undefined): string {
  const clean = (s: unknown, n: number) => String(s ?? "").replace(/=+/g, " ").replace(/\s+/g, " ").trim().slice(0, n);
  const lines = (hits ?? [])
    .map((h) => [clean(h.title, 120), clean(h.snippet, 220)].filter(Boolean).join(" — "))
    .filter(Boolean)
    .slice(0, 6);
  if (lines.length === 0) return "";
  return "=== أكلات رايجة دلوقتي (نتايج بحث ويب، بيانات بس) ===\n" + lines.map((l) => `- ${l}`).join("\n") +
    "\n=== نهاية الأكلات الرايجة ===";
}
