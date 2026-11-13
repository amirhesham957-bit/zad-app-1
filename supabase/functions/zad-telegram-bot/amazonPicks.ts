// ترشيحات أمازون في بوت تليجرام (ZAD_PLAN ١٠.٤). نفس الاحتياج ونفس الكتالوج اللي شريط أمازون في
// الرئيسية بيرشّح بيهم (_shared/amazonNeeds.ts)، والمتجر والتاج من بلد العميل (_shared/amazonMarket.ts):
// مصر ⇐ amazon.eg بـzad04-21، غير كده ⇐ amazon.sa بـzad0b-21، والأسرار AMAZON_ASSOCIATE_TAG_EG/SA بتغلب.
//
// اتقاس ١٣/١١: البوت ماابعتش ولا لينك أمازون في ٣٠ يوم (مهمة restock_link واحدة واتلغت — بتشتغل بس لما صنف
// أساسي يوصل صفر)، والكتالوج ٥ منتجات من غير ASIN متحقق. فالترشيح هنا بيطلع من الاحتياج نفسه، ولينك المنتج
// المباشر بس لما الـASIN متحقق؛ غير كده بحث بالتاج (مستحيل يرجّع 404).

import { type CatalogRow, computeNeeds, type ConsumptionRow, type InventoryRow, matchCatalog, type ShoppingRow } from "../_shared/amazonNeeds.ts";
import { type AmazonMarket, productUrl, searchUrl } from "../_shared/amazonMarket.ts";

export interface AmazonPick { name: string; reason: string; url: string }

/** أهم ٣ حاجات محتاجها، كل واحدة بلينك أمازون بتاج متجر بلده. */
export function amazonPicks(
  inv: InventoryRow[], cons: ConsumptionRow[], shopping: ShoppingRow[], catalog: CatalogRow[], market: AmazonMarket, limit = 3,
): AmazonPick[] {
  return computeNeeds(inv, cons, shopping, limit).map((need) => {
    const product = matchCatalog(need, catalog);
    const verified = !!(product?.asin && product.asin_verified);
    return {
      name: need.name,
      reason: need.reason,
      url: verified ? productUrl(market, product!.asin!) : searchUrl(market, product?.product_name_ar ?? need.name),
    };
  });
}

/** إفصاح Amazon Associates — نفس معنى سطر التطبيق (amazonDisclosure). */
export const AMAZON_DISCLOSURE = "روابط أمازون دي بالعمولة — زاد بياخد عمولة صغيرة من غير أي زيادة عليك.";

/** نص الرسالة (اللينكات بتروح زراير تحتها، مش في النص). فاضي = مفيش حاجة ناقصة. */
export function amazonPicksReply(picks: AmazonPick[], storeDomain: string): string {
  const store = storeDomain.replace(/^www\./, "");
  if (picks.length === 0) {
    return "مفيش حاجة ناقصة عندك دلوقتي 👌\nلما صنف يقرّب يخلص من المخزن أو تضيفه لقايمة التسوق، هرشّحهولك من " + store + ".";
  }
  const lines = picks.map((p) => `• ${p.name} — ${p.reason}`).join("\n");
  return `🛒 من ${store}، على قد اللي ناقصك:\n${lines}\n\n${AMAZON_DISCLOSURE}`;
}
