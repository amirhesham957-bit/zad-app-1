// purchaseDoor.ts — «اشتريت لبن وعيش بـ٤٠» شرا واحد (ZAD_PLAN ٣.٦ د، docs/agent/ZAD_PURCHASE_DOOR.md).
//
// قبل كده log_transaction كان بيكتب الفلوس بس، والأصناف محتاجة الموديل يفتكر يندَه add_inventory_item
// لكل صنف — ولو نسي، الفلوس اتسجلت والمخزن لأ. دلوقتي log_transaction بياخد lines اختياري، ومصروف
// فيه أصناف بيروح كله لـzad_record_purchase_service: الفلوس والمخزن والصيدلية والأسعار في ترانزاكشن
// واحدة. الدوال هنا نقية.

export const TOOL_PURCHASE_LINES_MAX = 30;

export interface ToolPurchaseLine {
  name: string;
  quantity: number;
  unit?: string;
  category?: string;
  price?: number;
  to: "pantry" | "pharmacy";
}

/** lines الموديل كسطور للدالة: اسم فاضي بيتشال، الكمية عدد صحيح ≥ ١، to غير pharmacy = pantry. */
export function toolPurchaseLines(raw: unknown): ToolPurchaseLine[] {
  if (!Array.isArray(raw)) return [];
  const out: ToolPurchaseLine[] = [];
  for (const item of raw) {
    if (!item || typeof item !== "object") continue;
    const r = item as Record<string, unknown>;
    const name = String(r.name ?? "").replace(/\s+/g, " ").trim().slice(0, 80);
    if (!name) continue;
    const q = Number(r.quantity);
    const line: ToolPurchaseLine = {
      name,
      quantity: Number.isFinite(q) && q > 0 ? Math.max(1, Math.round(q)) : 1,
      to: r.to === "pharmacy" ? "pharmacy" : "pantry",
    };
    const unit = String(r.unit ?? "").trim().slice(0, 20);
    if (unit) line.unit = unit;
    const category = String(r.category ?? "").trim().slice(0, 40);
    if (category) line.category = category;
    const price = Number(r.price);
    if (Number.isFinite(price) && price > 0) line.price = Math.round(price * 100) / 100;
    out.push(line);
    if (out.length >= TOOL_PURCHASE_LINES_MAX) break;
  }
  return out;
}

/** رد الأداة على zad_record_purchase_service، بنفس صيغة رفض التكرار القديمة عشان الموديل يسأل. */
export function purchaseToolReply(
  result: Record<string, unknown> | null,
  input: { title: string; amount: number },
  now: number = Date.now(),
): { ok: boolean; text: string; transactionId?: string } {
  if (result?.status === "duplicate_suspected") {
    const twin = (result.twin ?? {}) as { title?: string; created_at?: string };
    const at = twin.created_at ? new Date(twin.created_at).getTime() : now;
    const minsAgo = Math.max(1, Math.round((now - at) / 60000));
    return {
      ok: false,
      text: `مرفوض: فيه مصروف بنفس المبلغ (${input.amount}) اتسجّل من ${minsAgo} دقيقة باسم ` +
        `"${twin.title ?? ""}". غالباً دي نفس العملية اتبعتت تاني. اسأل العميل: دي عملية تانية فعلاً ` +
        `ولا نفس اللي فاتت؟ لو أكّد إنها تانية، نادِ الأداة تاني بـ allow_duplicate=true.`,
    };
  }
  if (result?.ok !== true || typeof result.transaction_id !== "string") {
    return { ok: false, text: `مرفوض: الشرا ماتسجلش (${String(result?.reason ?? "unknown")}) — ولا حاجة اتكتبت.` };
  }
  const n = (group: unknown, key: string) =>
    group && typeof group === "object" ? Number((group as Record<string, unknown>)[key]) || 0 : 0;
  const pantry = n(result.pantry, "added") + n(result.pantry, "topped_up");
  const pharmacy = n(result.pharmacy, "restocked");
  const parts: string[] = [];
  if (pantry > 0) parts.push(`${pantry} صنف في المخزن`);
  if (pharmacy > 0) parts.push(`${pharmacy} دوا في الصيدلية`);
  if (n(result.pantry, "ticked") > 0) parts.push(`${n(result.pantry, "ticked")} اتشال من المشتريات`);
  const skipped = Array.isArray(result.skipped) ? result.skipped.length : 0;
  return {
    ok: true,
    transactionId: result.transaction_id,
    text: `اتسجلت المعاملة: ${input.title} — ${input.amount}` +
      (parts.length ? ` (${parts.join("، ")})` : "") +
      (skipped ? ` — ${skipped} سطر ماتقراش` : ""),
  };
}
