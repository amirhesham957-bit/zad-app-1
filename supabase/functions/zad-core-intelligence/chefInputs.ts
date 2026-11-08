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
  /** نص زي ما اتكتب في zad_inventory (YYYY-MM-DD في الغالب). */
  expiry_date?: string | null;
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

const DAY_MS = 86_400_000;
/** ٧.٤: «قرب ينتهي» = جوه الأيام دي. */
export const EXPIRING_DAYS = 5;
/** ٧.٤: وصفة اتعرضت مابتتعرضش تاني قبلها. */
export const NO_REPEAT_DAYS = 14;
const MAX_DEALS_IN_PROMPT = 20;

const oneLine = (v: unknown, max: number) => String(v ?? "").replace(/[\n\r=]+/g, " ").trim().slice(0, max);

/** تطبيع للمقارنة: الهمزات والتاء المربوطة والمسافات مابتفرقش. */
export function dishKey(name: string): string {
  return String(name ?? "").replace(/[ً-ٰٟ]/g, "").replace(/[أإآ]/g, "ا").replace(/ى/g, "ي").replace(/ة/g, "ه")
    .replace(/\s+/g, "").toLowerCase();
}

export interface ExpiringItem {
  name: string;
  in_days: number;
}

/** الأصناف اللي صلاحيتها جوه [EXPIRING_DAYS] يوم، الأقرب الأول. اللي انتهت فعلاً برّه: مش بتتطبخ. تاريخ مش مفهوم = مش معروف. */
export function chefExpiring(rows: readonly PantryRow[] | null | undefined, today: string): ExpiringItem[] {
  const start = Date.parse(`${today}T00:00:00Z`);
  const out = new Map<string, ExpiringItem>();
  for (const r of rows ?? []) {
    const name = oneLine(r.item_name, 60);
    const raw = String(r.expiry_date ?? "").trim().slice(0, 10);
    if (!name || !(Number(r.quantity) > 0) || !/^\d{4}-\d{2}-\d{2}$/.test(raw)) continue;
    const inDays = Math.round((Date.parse(`${raw}T00:00:00Z`) - start) / DAY_MS);
    if (!Number.isFinite(inDays) || inDays < 0 || inDays > EXPIRING_DAYS) continue;
    const key = dishKey(name);
    const seen = out.get(key);
    if (!seen || inDays < seen.in_days) out.set(key, { name, in_days: inDays });
  }
  return [...out.values()].sort((a, b) => a.in_days - b.in_days);
}

export function expiringBlock(items: readonly ExpiringItem[]): string {
  if (items.length === 0) return "";
  return "=== قرب تنتهي صلاحيته ===\n" +
    items.map((i) => `${i.name} (${i.in_days === 0 ? "النهارده" : `بعد ${i.in_days} يوم`})`).join("\n") +
    "\n=== نهاية القسم ===";
}

export interface ChefDealRow {
  store: string | null;
  item_name: string | null;
  price: number | string | null;
  price_before?: number | string | null;
  currency?: string | null;
  city?: string | null;
}

export interface ChefDeal {
  item: string;
  store: string;
  price: number;
  price_before: number | null;
  currency: string;
}

/** عروض محلات البقالة: سعر حقيقي، ومدينته أو من غير مدينة، والخصم الأكبر الأول. */
export function chefDeals(rows: readonly ChefDealRow[] | null | undefined, city: string): ChefDeal[] {
  const here = city.trim();
  const seen = new Set<string>();
  const out: Array<ChefDeal & { off: number }> = [];
  for (const r of rows ?? []) {
    const item = oneLine(r.item_name, 60), store = oneLine(r.store, 40), price = Number(r.price);
    if (!item || !store || !(price > 0) || (r.city && here && r.city !== here)) continue;
    const key = `${dishKey(item)}|${dishKey(store)}`;
    if (seen.has(key)) continue;
    seen.add(key);
    const before = Number(r.price_before);
    const hasBefore = Number.isFinite(before) && before > price;
    out.push({
      item, store, price, price_before: hasBefore ? before : null, currency: oneLine(r.currency, 6),
      off: hasBefore ? (before - price) / before : 0,
    });
  }
  return out.sort((a, b) => b.off - a.off).slice(0, MAX_DEALS_IN_PROMPT).map(({ off: _off, ...d }) => d);
}

export function dealsBlock(deals: readonly ChefDeal[]): string {
  if (deals.length === 0) return "";
  return "=== عروض شغالة ===\n" +
    deals.map((d) => `${d.item} — ${d.store}: ${d.price} ${d.currency}${d.price_before ? ` (بدل ${d.price_before})` : ""}`).join("\n") +
    "\n=== نهاية العروض ===";
}

/** المكوّن الناقص اللي عليه عرض فعلاً. من الكود مش من الموديل: الموديل ممكن يألّف عرض، والعميل هيروح المحل عشانه. */
export function dealsForMissing(missing: unknown, deals: readonly ChefDeal[]): ChefDeal[] {
  if (!Array.isArray(missing)) return [];
  const out: ChefDeal[] = [];
  for (const m of missing) {
    const want = dishKey(String(m ?? ""));
    if (want.length < 2) continue;
    const hit = deals.find((d) => dishKey(d.item).includes(want));
    if (hit && !out.includes(hit)) out.push(hit);
  }
  return out;
}

/** بيشيل اللي اتعرض في آخر [NO_REPEAT_DAYS] يوم. لو ده هيفضّي الرد كله، الرد بيرجع زي ما هو: وصفة متكررة أحسن من شاشة فاضية. */
export function withoutRecent<T extends { recipe_name?: unknown }>(recipes: readonly T[], served: ReadonlySet<string>): T[] {
  const fresh = recipes.filter((r) => !served.has(dishKey(String(r?.recipe_name ?? ""))));
  return fresh.length > 0 ? fresh : [...recipes];
}
