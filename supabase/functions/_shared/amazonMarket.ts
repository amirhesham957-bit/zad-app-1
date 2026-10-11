// أي متجر أمازون، وبأي تاج، لعميل من بلد معيّن (قرار صاحب التطبيق ٢٠٢٦-١٠-١٠).
//
// مصر → amazon.eg بتاج zad04-21. أي بلد تاني → amazon.sa، لحد ما نجمع باقي الأسواق.
// برنامج Amazon Associates منفصل لكل سوق: تاج متسجل على amazon.eg مابيكسبش ولا قرش على
// amazon.sa والعكس — فالتاج والدومين لازم ييجوا من نفس السوق دايماً، وعشان كده مفيش تاج
// «عام» بيتركّب على دومين مش بتاعه.
//
// سوق جديد بعدين (الإمارات مثلاً) بيتضاف من أسرار المشروع من غير كود: AMAZON_DOMAIN_AE مع
// AMAZON_ASSOCIATE_TAG_AE. واحد من الاتنين لوحده مابيكفيش — البلد يفضل على السعودية.
// الكود ده متقري من amazon-creators-search (ترشيحات الرئيسية) ومن zad-brain (لينك النواقص).

export interface AmazonMarket { domain: string; tag: string | null }

/** تاج مصر (amazon.eg) — من صاحب التطبيق. السر AMAZON_ASSOCIATE_TAG_EG بيكسب عليه. */
export const EG_ASSOCIATE_TAG = "zad04-21";

/** تاج السعودية (amazon.sa) — اللي التطبيق كان شغال بيه من الأول (.env.example). */
export const SA_ASSOCIATE_TAG = "zad0b-21";

function validDomain(raw: string | null): string | null {
  return raw && /^[a-z0-9.-]*amazon\.[a-z.]{2,10}$/i.test(raw) ? raw.toLowerCase() : null;
}

export function marketFor(country: string | null | undefined, env: (n: string) => string | undefined): AmazonMarket {
  const cc = String(country ?? "").toUpperCase().replace(/[^A-Z]/g, "").slice(0, 2);
  const clean = (v: string | undefined) => (v ?? "").trim() || null;
  if (cc === "EG") {
    return { domain: "www.amazon.eg", tag: clean(env("AMAZON_ASSOCIATE_TAG_EG")) ?? EG_ASSOCIATE_TAG };
  }
  if (cc && cc !== "SA") {
    const domain = validDomain(clean(env(`AMAZON_DOMAIN_${cc}`)));
    const tag = clean(env(`AMAZON_ASSOCIATE_TAG_${cc}`));
    if (domain && tag) return { domain, tag };
  }
  return {
    domain: "www.amazon.sa",
    tag: clean(env("AMAZON_ASSOCIATE_TAG_SA")) ?? clean(env("AMAZON_ASSOCIATE_TAG")) ?? SA_ASSOCIATE_TAG,
  };
}

export function searchUrl(market: AmazonMarket, term: string): string {
  const q = encodeURIComponent(term.trim());
  return `https://${market.domain}/s?k=${q}${market.tag ? `&tag=${encodeURIComponent(market.tag)}` : ""}`;
}

export function productUrl(market: AmazonMarket, asin: string): string {
  return `https://${market.domain}/dp/${encodeURIComponent(asin)}${market.tag ? `?tag=${encodeURIComponent(market.tag)}` : ""}`;
}
