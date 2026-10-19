// purchasePhoto.ts — صورة فاتورة في تليجرام كشرا واحد (ZAD_PLAN ٣.٦ ج، قرار المالك ١٩/١٠).
//
// قبل كده الصورة كانت بتملا المخزن وتبلّغ الأسعار فوراً، والمصروف مستني زرار — فالعميل لو داس «لأ»
// أو ماداسش، المخزن اتملى والفلوس لأ. دلوقتي مفيش حاجة بتتكتب قبل الزرار: الصورة بتحجز الشرا كله
// (الفلوس + الأصناف) في telegram_pending_writes، والأزرار التلاتة بتنادي zad_record_purchase_service:
//   «سجّل الكل»  → الفلوس والأصناف في ترانزاكشن واحدة
//   «المخزن بس»  → الأصناف من غير مصروف (البنك هيسجّل الدفعة) — amount غايب
//   «لأ»         → ولا حاجة (زرار الإلغاء العادي c:)
// الدوال هنا نقية عشان تتختبر من غير بوت ولا داتابيز.

import type { InlineKeyboardButton } from "./telegram.ts";
import { purchaseQuantity } from "../_shared/purchaseQuantity.ts";

export const PURCHASE_LINES_MAX = 100;

export type PurchaseLineTo = "pantry" | "pharmacy";

export interface PurchaseLine {
  name: string;
  quantity: number;
  unit?: string;
  category?: string;
  price?: number;
  to: PurchaseLineTo;
}

/** سطور الصورة كسطور شرا: اسم فاضي بيتشال، والكمية زي ما هي (نص كيلو = ٠٫٥)، والصيدلية بالحبة. */
export function purchaseLinesFromPhoto(
  items: Array<{ name?: string | null; quantity?: number | null; unit?: string | null; category?: string | null; price?: number | null }>,
  to: PurchaseLineTo,
): PurchaseLine[] {
  const out: PurchaseLine[] = [];
  for (const item of items) {
    const name = String(item.name ?? "").replace(/\s+/g, " ").trim().slice(0, 80);
    if (!name) continue;
    const line: PurchaseLine = { name, quantity: purchaseQuantity(item.quantity, to), to };
    const unit = String(item.unit ?? "").trim().slice(0, 20);
    if (unit) line.unit = unit;
    const category = String(item.category ?? "").trim().slice(0, 40);
    if (category) line.category = category;
    const price = Number(item.price);
    if (Number.isFinite(price) && price > 0) line.price = Math.round(price * 100) / 100;
    out.push(line);
    if (out.length >= PURCHASE_LINES_MAX) break;
  }
  return out;
}

/** صف telegram_pending_writes زي ما الأزرار بتقراه. */
export interface PendingPurchase {
  id: string;
  amount: number | null;
  title: string;
  category: string | null;
  wallet: string | null;
  merchant_name: string | null;
  source_type: string | null;
  purchase_lines: unknown;
}

export type PurchaseMode = "all" | "lines";

/**
 * مدخل zad_record_purchase_service من الصف المحجوز. مفتاح الشرا = id الصف: داسة مرتين أو إعادة
 * بعد فشل ملتبس بترجع نفس الرد من غير كتابة تانية. «المخزن بس» = من غير amount. null لو مفيش
 * حاجة تتسجل بالوضع ده (مفيش مبلغ لـ«الكل»، أو مفيش أصناف لـ«المخزن بس»).
 */
export function purchaseFromPending(row: PendingPurchase, mode: PurchaseMode): Record<string, unknown> | null {
  const lines = Array.isArray(row.purchase_lines) ? row.purchase_lines.slice(0, PURCHASE_LINES_MAX) : [];
  const hasAmount = typeof row.amount === "number" && Number.isFinite(row.amount) && row.amount > 0;
  if (mode === "all" && !hasAmount) return null;
  if (mode === "lines" && lines.length === 0) return null;
  const purchase: Record<string, unknown> = {
    id: row.id,
    title: row.title,
    source_type: row.source_type ?? "telegram",
    lines,
  };
  if (row.category) purchase.category = row.category;
  if (row.merchant_name) purchase.merchant_name = row.merchant_name;
  if (mode === "all") {
    purchase.amount = row.amount;
    purchase.wallet = row.wallet ?? "card";
  }
  return purchase;
}

/** الأزرار: «سجّل الكل» بس لو فيه مبلغ اتقرا، و«المخزن بس» بس لو فيه أصناف. */
export function purchaseKeyboard(pendingId: string, opts: { hasAmount: boolean; hasLines: boolean }): InlineKeyboardButton[][] {
  const row: InlineKeyboardButton[] = [];
  if (opts.hasAmount) row.push({ text: opts.hasLines ? "✅ سجّل الكل" : "✅ أكد التسجيل", callback_data: `pa:${pendingId}` });
  if (opts.hasLines) row.push({ text: opts.hasAmount ? "📦 المخزن بس" : "📦 ضيفهم للمخزن", callback_data: `pl:${pendingId}` });
  row.push({ text: "✖️ لأ", callback_data: `c:${pendingId}` });
  return [row];
}

/** "pa:<uuid>" (الكل) / "pl:<uuid>" (الأصناف بس). */
export function parsePurchaseCallback(data: string): { mode: PurchaseMode; pendingId: string } | null {
  const parts = data.split(":");
  if (parts.length !== 2) return null;
  if (parts[0] !== "pa" && parts[0] !== "pl") return null;
  if (!/^[0-9a-fA-F-]{36}$/.test(parts[1])) return null;
  return { mode: parts[0] === "pa" ? "all" : "lines", pendingId: parts[1] };
}

/** سطر يتحط فوق رسالة التأكيد: الأصناف اللي هتدخل لما العميل يقرر. */
export function purchasePreview(lines: PurchaseLine[]): string {
  const pantry = lines.filter((l) => l.to === "pantry").length;
  const pharmacy = lines.filter((l) => l.to === "pharmacy").length;
  const parts: string[] = [];
  if (pantry > 0) parts.push(`${pantry} صنف للمخزن`);
  if (pharmacy > 0) parts.push(`${pharmacy} دوا للصيدلية`);
  if (parts.length === 0) return "";
  return `🧾 قريت ${parts.join(" و")} — مش هضيفهم غير لما تختار.`;
}

/** رد الدالة بعد ما اتسجل: إيه اللي حصل للمخزن والصيدلية. */
export function purchaseDoneLine(result: Record<string, unknown>): string {
  const n = (group: unknown, key: string) =>
    group && typeof group === "object" ? Number((group as Record<string, unknown>)[key]) || 0 : 0;
  const added = n(result.pantry, "added");
  const topped = n(result.pantry, "topped_up");
  const ticked = n(result.pantry, "ticked");
  const restocked = n(result.pharmacy, "restocked");
  const parts: string[] = [];
  if (added > 0) parts.push(`${added} جديد في المخزن`);
  if (topped > 0) parts.push(`${topped} زادت كميته`);
  if (ticked > 0) parts.push(`${ticked} اتشال من المشتريات`);
  if (restocked > 0) parts.push(`${restocked} دوا اتزوّد`);
  return parts.join("، ");
}
