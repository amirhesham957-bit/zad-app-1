// pricelessPurchase.ts — «اشتريت ٣ علب لبن» من غير سعر.
//
// فحص ١٤/١١ على الإنتاج: الموديل نادى log_transaction بـ amount 0 وفيها السطر للمخزن، الحارس رفضها
// («المبلغ لازم يكون رقم موجب»)، والعميل اتقاله «حصلت مشكلة». المشتريات حصلت فعلاً والمخزن مالوش ذنب في
// إن السعر مش معروف: الأصناف تدخل المخزن على طول، والمصروف مايتسجلش (مفيش مبلغ نخمّنه) — الموديل يسأل عنه.

export type PantryLine = { item_name: string; quantity: number; unit?: string; category?: string };

/**
 * أصناف المخزن من log_transaction مصروف من غير مبلغ موجب. null = ده مش الشكل ده (فيه مبلغ، أو دخل، أو
 * مفيش أصناف للمخزن) والحارس العادي يحكم.
 */
export function pantryLinesWithoutPrice(input: unknown): PantryLine[] | null {
  const i = (input ?? {}) as Record<string, unknown>;
  const amount = i.amount;
  if (typeof amount === "number" && Number.isFinite(amount) && amount > 0) return null;
  if (i.txn_kind !== undefined && i.txn_kind !== "expense") return null;
  if (!Array.isArray(i.lines)) return null;
  const out: PantryLine[] = [];
  for (const raw of i.lines.slice(0, 10)) {
    const l = (raw ?? {}) as Record<string, unknown>;
    if (l.to !== undefined && l.to !== "pantry") continue;
    const name = String(l.name ?? l.product ?? "").trim();
    if (!name) continue;
    const q = Number(l.quantity);
    out.push({
      item_name: name,
      quantity: Number.isFinite(q) && q > 0 ? q : 1,
      ...(l.unit ? { unit: String(l.unit).trim() } : {}),
      ...(l.category ? { category: String(l.category).trim() } : {}),
    });
  }
  return out.length > 0 ? out : null;
}

/** نتيجة الأداة للموديل: حالة، مش أمر (شوف التعليق على status=awaiting_user_confirmation في index.ts). */
export function pricelessResult(added: string[], failed: string[]): string {
  const parts = [`status=added_to_pantry_without_expense; price=unknown; expense_recorded=false`];
  if (added.length) parts.push(`added: ${added.join(" | ")}`);
  if (failed.length) parts.push(`failed: ${failed.join(" | ")}`);
  return parts.join("\n");
}
