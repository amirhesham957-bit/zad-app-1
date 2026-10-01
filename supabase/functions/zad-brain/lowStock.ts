// نواقص المخزون → قايمة الشراء، في الحلم الليلي (nightly_dream_reflection).
//
// الكود القديم (٢٠٢٦-٠٩-٢٧) كان بيسأل قايمة الشراء بـ.eq(item_name).maybeSingle() من غير
// is_purchased=false:
// - صنف اتشرى مرة من القايمة قبل كده فضل صفّه القديم (is_purchased=true) موجود، فالحلم
//   كان يلاقيه ويفتكره لسه على القايمة — والصنف ما يرجعش تاني أبداً لما يخلص.
// - اسم ليه أكتر من صف كان بيخلّي maybeSingle يرجّع خطأ و data=null، فبيضيف تاني.
// - الحد كان ≤1 ثابت ومتجاهل low_stock_threshold اللي العميل حاطه للصنف.
// الدالة هنا نقية: بتاخد المخزون والبنود المفتوحة وترجّع اللي يتضاف.

export interface PantryRow {
  item_name: string | null;
  quantity: number | string | null;
  low_stock_threshold?: number | string | null;
}

/** نفس تطبيع الأسماء اللي بيتقارن بيه: مسافات، حروف صغيرة، ألف/تاء مربوطة/ياء. */
export function normalizeItemName(s: string): string {
  return s.trim().toLowerCase()
    .replace(/[أإآ]/g, "ا").replace(/ة/g, "ه").replace(/ى/g, "ي")
    .replace(/\s+/g, " ");
}

/**
 * عائلات المنتجات — نفس جدول التطبيق (zad_flutter/lib/shared/inventory/domain/product_family.dart).
 * ٨ إزازات مية من ٥ ماركات كانت بتتحسب ٥ نواقص وتنزل القايمة ٥ مرات (٢٠٢٦-٠٩-٣٠). السلعة
 * الأساسية بماركاتها مخزون واحد: مجموعهم، وأعلى حد، وبتنزل القايمة مرة باسم السلعة.
 * الكلمات دي بتتطابق مع اللي العميل والماسح كتبوه — بيانات، مش نص واجهة.
 */
const STAPLES: Record<string, string> = {
  "ماء": "مياه", "مياه": "مياه", "ميه": "مياه", "مايه": "مياه", "ميا": "مياه", "water": "مياه",
  "رز": "رز", "ارز": "رز", "سكر": "سكر", "ملح": "ملح", "دقيق": "دقيق",
  "بيض": "بيض", "بيضه": "بيض", "عيش": "عيش", "خبز": "عيش",
  "مكرونه": "مكرونه", "معكرونه": "مكرونه", "شاي": "شاي",
  "حليب": "حليب", "لبن": "لبن", "زبادي": "زبادي", "مناديل": "مناديل",
};

/** التعبئة قبل السلعة («عبوة مياه»، «كرتونة ماية»، «كيس سكر») — بتتفوت، نفس جدول التطبيق. */
const PACKAGING = new Set([
  "عبوه", "كرتونه", "كرتون", "زجاجه", "ازازه", "قزازه", "جالون", "باكو", "باكت", "كيس", "علبه",
  "شكاره", "كيلو", "لتر", "صندوق",
]);

/** العائلة اللي الاسم ده منها، أو null لو مش سلعة أساسية. */
export function productFamilyOf(name: string): string | null {
  const words = normalizeItemName(name).split(" ").filter(Boolean)
    .map((w) => (w.startsWith("ال") ? w.slice(2) : w));
  let i = 0;
  while (i < words.length - 1 && PACKAGING.has(words[i])) i++;
  const first = STAPLES[words[i] ?? ""];
  if (first) return first;
  // الماركة قبل السلعة: «صافي مياه معدنية 1.5 لتر» كانت صف لوحدها جنب ٩ صفوف مية (٢٠٢٦-١٠-٠١).
  // للمية بس: «بسكويت شاي» مش شاي، و«عصير بالسكر» مش سكر.
  return STAPLES[words[i + 1] ?? ""] === "مياه" ? "مياه" : null;
}

/**
 * الأصناف اللي وصلت حدها (low_stock_threshold لو محطوط، وإلا ١) ومش على القايمة كبند
 * مفتوح. كل اسم مرة واحدة حتى لو متكرر في المخزون، وكل سلعة أساسية مرة واحدة باسمها
 * لما مجموع ماركاتها يوصل الحد.
 */
export function lowStockToAdd(pantry: PantryRow[] | null | undefined, openShoppingNames: Array<string | null>): string[] {
  const open = new Set(openShoppingNames.filter((n): n is string => !!n?.trim()).map(normalizeItemName));
  const out: string[] = [];
  const families = new Map<string, { total: number; threshold: number }>();
  const familyOrder: string[] = [];
  for (const row of pantry ?? []) {
    const name = row.item_name?.trim();
    if (!name) continue;
    const qty = Number(row.quantity);
    if (!Number.isFinite(qty) || qty < 0) continue;
    const t = Number(row.low_stock_threshold);
    const threshold = Number.isFinite(t) && t > 0 ? t : 1;
    const family = productFamilyOf(name);
    if (family) {
      const f = families.get(family);
      if (f) {
        f.total += qty;
        f.threshold = Math.max(f.threshold, threshold);
      } else {
        families.set(family, { total: qty, threshold });
        familyOrder.push(family);
      }
      continue;
    }
    if (qty > threshold) continue;
    const key = normalizeItemName(name);
    if (open.has(key)) continue;
    open.add(key);
    out.push(name);
  }
  for (const family of familyOrder) {
    const f = families.get(family)!;
    if (f.total > f.threshold) continue;
    const key = normalizeItemName(family);
    if (open.has(key)) continue;
    open.add(key);
    out.push(family);
  }
  return out;
}
