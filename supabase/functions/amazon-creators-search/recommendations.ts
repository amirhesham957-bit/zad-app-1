// ترشيحات أمازون الحية (٢٠٢٦-٠٩-١٤).
//
// بلاغ من تجربة حقيقية: «إيدج أمازون بايظ — صورة زيت زيتون بس ومفيش ترشيح حي للي ناقصني أو اللي
// بستهلكه، واربطه بالتاج اللي حطيته في سوبابيز عشان آخد عمولة». اللي كان بيحصل:
//   - لو مفيش تطابق مع الكتالوج (صف أو اتنين)، التطبيق كان بيعرض الكتالوج كله كأنه «ترشيح».
//   - التاج جاي من BuildConfig (.env.example = zad0b-21) مش من سر AMAZON_ASSOCIATE_TAG.
//   - الاحتياج من الكمية وقايمة التسوق بس — معدل الاستهلاك المتعلَّم (zad_consumption) مش داخل.
// هنا الاحتياج بيتحسب من المخزون + معدل الاستهلاك + قايمة التسوق، واللينك بيتبني بالتاج والدومين
// من أسرار المشروع. كل التاج من السيرفر: تغيير السر يغيّر كل اللينكات من غير نسخة جديدة.

export interface InventoryRow { item_name: string; quantity: number | null; low_stock_threshold: number | null; unit?: string | null }
export interface ConsumptionRow { item_name: string; avg_daily_qty: number | null; rate_known: boolean | null }
export interface ShoppingRow { item_name: string; is_purchased: boolean | null }
export interface CatalogRow {
  id: string; product_name_ar: string; product_name_search_keywords: string[] | null;
  asin: string | null; asin_verified: boolean | null; image_url: string | null; average_price_sar: number | null; is_active: boolean | null;
}

export interface Need { name: string; reason: string; score: number; days_left: number | null }

export interface AmazonMarket { domain: string; tag: string | null }

export function normalizeAr(raw: string): string {
  return raw.trim().toLowerCase()
    .replace(/[ً-ْـ]/g, "")
    .replace(/[أإآ]/g, "ا")
    .replace(/ة/g, "ه")
    .replace(/ى/g, "ي")
    .replace(/\s+/g, " ");
}

/**
 * تاج ودومين حسب بلد العميل. برنامج Amazon Associates منفصل لكل سوق — تاج متسجل على amazon.sa مابيكسبش
 * على amazon.eg. فالأولوية: AMAZON_ASSOCIATE_TAG_<CC> + AMAZON_DOMAIN_<CC>، وبعدين العام
 * AMAZON_ASSOCIATE_TAG + AMAZON_DOMAIN (افتراضي www.amazon.sa، السوق اللي التطبيق كان مبني عليه).
 */
export function marketFor(country: string | null | undefined, env: (n: string) => string | undefined): AmazonMarket {
  const cc = String(country ?? "").toUpperCase().replace(/[^A-Z]/g, "").slice(0, 2);
  const clean = (v: string | undefined) => (v ?? "").trim() || null;
  const tag = (cc && clean(env(`AMAZON_ASSOCIATE_TAG_${cc}`))) || clean(env("AMAZON_ASSOCIATE_TAG"));
  const rawDomain = (cc && clean(env(`AMAZON_DOMAIN_${cc}`))) || clean(env("AMAZON_DOMAIN")) || "www.amazon.sa";
  const domain = /^[a-z0-9.-]*amazon\.[a-z.]{2,10}$/i.test(rawDomain) ? rawDomain.toLowerCase() : "www.amazon.sa";
  return { domain, tag };
}

export function searchUrl(market: AmazonMarket, term: string): string {
  const q = encodeURIComponent(term.trim());
  return `https://${market.domain}/s?k=${q}${market.tag ? `&tag=${encodeURIComponent(market.tag)}` : ""}`;
}

export function productUrl(market: AmazonMarket, asin: string): string {
  return `https://${market.domain}/dp/${encodeURIComponent(asin)}/${market.tag ? `?tag=${encodeURIComponent(market.tag)}` : ""}`;
}

/** الاحتياج الحقيقي: خلص (٤) > هيخلص خلال ٣ أيام حسب استهلاكه (٤) > قليل (٣) > في قايمة التسوق (٢) > بيستهلكه باستمرار وقرّب (١). */
export function computeNeeds(inv: InventoryRow[], cons: ConsumptionRow[], shopping: ShoppingRow[], limit = 10): Need[] {
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
    const daysLeft = r ? Math.max(0, Math.round((qty / r) * 10) / 10) : null;
    if (qty <= 0) consider(item.item_name, 4, "خلص من مخزونك", 0);
    else if (daysLeft !== null && daysLeft <= 3) consider(item.item_name, 4, `هيخلص خلال ${Math.max(1, Math.ceil(daysLeft))} يوم حسب استهلاكك`, daysLeft);
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
