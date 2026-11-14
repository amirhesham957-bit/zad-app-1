// الاحتياج من المخزون + معدل الاستهلاك + قايمة التسوق، ومطابقته بكتالوج الأفلييت (affiliate_products).
// اتنقل من amazon-creators-search/recommendations.ts (١٣/١١، ZAD_PLAN ١٠.٤) عشان بوت تليجرام يرشّح نفس
// الترشيحات اللي في شريط أمازون في الرئيسية، من غير نسخة تانية من القواعد.

export interface InventoryRow { item_name: string; quantity: number | null; low_stock_threshold: number | null; unit?: string | null }
export interface ConsumptionRow { item_name: string; avg_daily_qty: number | null; rate_known: boolean | null }
export interface ShoppingRow { item_name: string; is_purchased: boolean | null }
export interface CatalogRow {
  id: string; product_name_ar: string; product_name_search_keywords: string[] | null;
  asin: string | null; asin_verified: boolean | null; image_url: string | null; average_price_sar: number | null; is_active: boolean | null;
}

export interface Need { name: string; reason: string; score: number; days_left: number | null }


export function normalizeAr(raw: string): string {
  return raw.trim().toLowerCase()
    .replace(/[ً-ْـ]/g, "")
    .replace(/[أإآ]/g, "ا")
    .replace(/ة/g, "ه")
    .replace(/ى/g, "ي")
    .replace(/\s+/g, " ");
}


/** الاحتياج الحقيقي: خلص (٤) > هيخلص خلال ٣ أيام حسب استهلاكه (٤) > قليل (٣) > في قايمة التسوق (٢) > بيستهلكه باستمرار وقرّب (١). */
/**
 * [priorDays] (خطة المخزن ٦): الأيام الباقية بالمعدل المبدئي (zad_pantry_prior_days_for) للصنف اللي مالوش معدل
 * متعلّم، بالاسم بعد normalizeAr. من غيرها الاحتياج كان بيشوف «خلص» و«قليل» بس عند بيت مالوش ولا معدل (حساب المالك ١٤/١١).
 */
export function computeNeeds(
  inv: InventoryRow[], cons: ConsumptionRow[], shopping: ShoppingRow[], limit = 10,
  priorDays?: ReadonlyMap<string, number>,
): Need[] {
  const rate = new Map(cons.filter((c) => c.rate_known && (c.avg_daily_qty ?? 0) > 0).map((c) => [normalizeAr(c.item_name), Number(c.avg_daily_qty)]));
  const needs = new Map<string, Need>();
  const consider = (name: string, score: number, reason: string, daysLeft: number | null = null) => {
    const key = normalizeAr(name);
    if (!key) return;
    const prev = needs.get(key);
    if (!prev || score > prev.score) needs.set(key, { name: name.trim(), reason, score, days_left: daysLeft });
  };
  for (const item of inv) {
    const qty = Number(item.quantity ?? 0);
    const r = rate.get(normalizeAr(item.item_name));
    const prior = r ? undefined : priorDays?.get(normalizeAr(item.item_name));
    const daysLeft = r ? Math.max(0, Math.round((qty / r) * 10) / 10) : prior !== undefined && Number.isFinite(prior) ? Math.max(0, prior) : null;
    const basis = r ? "حسب استهلاكك" : "على قد أفراد البيت";
    if (qty <= 0) consider(item.item_name, 4, "خلص من مخزونك", 0);
    else if (daysLeft !== null && daysLeft <= 3) consider(item.item_name, 4, `هيخلص خلال ${Math.max(1, Math.ceil(daysLeft))} يوم ${basis}`, daysLeft);
    else if (qty <= Number(item.low_stock_threshold ?? 2)) consider(item.item_name, 3, "قارب على النفاد", daysLeft);
    else if (daysLeft !== null && daysLeft <= 10) consider(item.item_name, 1, "بتستهلكه باستمرار", daysLeft);
  }
  for (const s of shopping) if (!s.is_purchased) consider(s.item_name, 2, "في قايمة التسوق");
  return [...needs.values()].sort((a, b) => b.score - a.score || (a.days_left ?? 99) - (b.days_left ?? 99)).slice(0, limit);
}

/** صف كتالوج متحقق منه بيدّي صورة وسعر ولينك منتج مباشر؛ غير كده بحث بالتاج (مستحيل يرجّع 404). */
export function matchCatalog(need: Need, catalog: CatalogRow[]): CatalogRow | null {
  const key = normalizeAr(need.name);
  let best: CatalogRow | null = null;
  let bestScore = 0;
  for (const p of catalog) {
    if (!p.is_active) continue;
    const hay = [p.product_name_ar, ...(p.product_name_search_keywords ?? [])].map(normalizeAr).filter(Boolean);
    const score = hay.some((h) => h === key) ? 2 : hay.some((h) => h.length >= 2 && (h.includes(key) || key.includes(h))) ? 1 : 0;
    if (score > bestScore) { bestScore = score; best = p; }
  }
  return best;
}

/** The URL when Amazon itself serves it (a product photo), else null — never a stock picture. */
export function amazonImageOrNull(url: unknown): string | null {
  if (typeof url !== "string") return null;
  let u: URL;
  try { u = new URL(url.trim()); } catch { return null; }
  if (u.protocol !== "https:") return null;
  const host = u.hostname.toLowerCase();
  const hosts = ["m.media-amazon.com", "images-na.ssl-images-amazon.com", "images-eu.ssl-images-amazon.com",
    "images-fe.ssl-images-amazon.com", "images-amazon.com", "ssl-images-amazon.com"];
  return hosts.some((h) => host === h || host.endsWith(`.${h}`)) ? u.toString() : null;
}

/** صفوف zad_pantry_prior_days_for ⇒ خريطة بالاسم بعد normalizeAr لـcomputeNeeds. */
export function priorDaysMap(rows: unknown): Map<string, number> {
  const out = new Map<string, number>();
  for (const r of Array.isArray(rows) ? rows as Array<{ item_name?: unknown; days_left?: unknown; held?: unknown }> : []) {
    if (!r || typeof r !== "object") continue;
    const d = Number(r.days_left);
    if (typeof r.item_name === "string" && r.days_left !== null && Number.isFinite(d) && r.held !== true) out.set(normalizeAr(r.item_name), d);
  }
  return out;
}
