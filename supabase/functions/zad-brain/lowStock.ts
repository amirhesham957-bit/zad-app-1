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
 * الأصناف اللي وصلت حدها (low_stock_threshold لو محطوط، وإلا ١) ومش على القايمة كبند
 * مفتوح. كل اسم مرة واحدة حتى لو متكرر في المخزون.
 */
export function lowStockToAdd(pantry: PantryRow[] | null | undefined, openShoppingNames: Array<string | null>): string[] {
  const open = new Set(openShoppingNames.filter((n): n is string => !!n?.trim()).map(normalizeItemName));
  const out: string[] = [];
  for (const row of pantry ?? []) {
    const name = row.item_name?.trim();
    if (!name) continue;
    const qty = Number(row.quantity);
    if (!Number.isFinite(qty) || qty < 0) continue;
    const t = Number(row.low_stock_threshold);
    const threshold = Number.isFinite(t) && t > 0 ? t : 1;
    if (qty > threshold) continue;
    const key = normalizeItemName(name);
    if (open.has(key)) continue;
    open.add(key);
    out.push(name);
  }
  return out;
}
