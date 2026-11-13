// ترشيحات أمازون الحية (٢٠٢٦-٠٩-١٤).
//
// بلاغ من تجربة حقيقية: «إيدج أمازون بايظ — صورة زيت زيتون بس ومفيش ترشيح حي للي ناقصني أو اللي
// بستهلكه، واربطه بالتاج اللي حطيته في سوبابيز عشان آخد عمولة». اللي كان بيحصل:
//   - لو مفيش تطابق مع الكتالوج (صف أو اتنين)، التطبيق كان بيعرض الكتالوج كله كأنه «ترشيح».
//   - التاج جاي من BuildConfig (.env.example = zad0b-21) مش من سر AMAZON_ASSOCIATE_TAG.
//   - الاحتياج من الكمية وقايمة التسوق بس — معدل الاستهلاك المتعلَّم (zad_consumption) مش داخل.
// هنا الاحتياج بيتحسب من المخزون + معدل الاستهلاك + قايمة التسوق، واللينك بيتبني بالتاج والدومين
// من أسرار المشروع. كل التاج من السيرفر: تغيير السر يغيّر كل اللينكات من غير نسخة جديدة.

// المتجر والتاج حسب بلد العميل — في _shared/amazonMarket.ts، نفس اللي zad-brain بيستعمله.
export { marketFor, productUrl, searchUrl } from "../_shared/amazonMarket.ts";
export type { AmazonMarket } from "../_shared/amazonMarket.ts";

// الاحتياج والمطابقة في _shared/amazonNeeds.ts — نفسها اللي بوت تليجرام بيرشّح بيها (١٠.٤).
export { amazonImageOrNull, computeNeeds, matchCatalog, normalizeAr } from "../_shared/amazonNeeds.ts";
export type { CatalogRow, ConsumptionRow, InventoryRow, Need, ShoppingRow } from "../_shared/amazonNeeds.ts";
