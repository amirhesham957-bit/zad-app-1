// سعر صنف من بنود فواتير العميل نفسه (zad_purchases.lines) — قبل أي بحث نت.
//
// بلاغ المالك ٢٠٢٦-١١-٢٨: سجّل فاتورة «بشاير للخضراوات» بأصنافها وأسعارها (منها الملوخية)، وسأل البوت
// «سعر الملوخية كام» فرد «تفاصيل الأصناف مش ظاهرة». السبب: ماكانش فيه أداة بتقرا بنود الفواتير؛ كلها كانت
// بتقرا بحث النت أو لقطة الإجمالي. بند الفاتورة `price` = إجمالي البند، فسعر الوحدة = price ÷ quantity.
import { normalizeItemName, samePantryItem } from "./pantryMatch.ts";

export interface PurchaseRow {
  id?: string;
  created_at?: string | null;
  lines?: unknown;
  shop?: string | null;
}

export interface OwnPrice {
  name: string;
  unitPrice: number;
  total: number;
  quantity: number;
  unit: string | null;
  at: string | null;
  shop: string | null;
}

/** أحدث الأسعار المسجّلة للصنف (الأحدث الأول). بند من غير سعر أو من غير كمية مابيتحسبش. */
export function ownPricesFor(rows: PurchaseRow[], item: string): OwnPrice[] {
  const key = normalizeItemName(item);
  if (key.length < 2) return [];
  const out: OwnPrice[] = [];
  for (const r of rows) {
    if (!Array.isArray(r.lines)) continue;
    for (const raw of r.lines as Array<Record<string, unknown>>) {
      const names = [raw?.name, raw?.product].filter((n): n is string => typeof n === "string" && n.trim().length > 0);
      if (!names.some((n) => samePantryItem(n, item) || normalizeItemName(n).includes(key))) continue;
      const total = Number(raw.price);
      const qty = Number(raw.quantity) > 0 ? Number(raw.quantity) : 1;
      if (!(total > 0)) continue;
      out.push({
        name: String(names[0]), unitPrice: Math.round((total / qty) * 100) / 100, total, quantity: qty,
        unit: typeof raw.unit === "string" && raw.unit.trim() ? raw.unit.trim() : null,
        at: r.created_at ?? null, shop: r.shop ?? null,
      });
    }
  }
  return out.sort((a, b) => String(b.at ?? "").localeCompare(String(a.at ?? "")));
}

/** رد للموديل: الأسعار الفعلية المسجّلة بتاريخها، أو null لو مفيش (يكمّل بحث النت). */
export function ownPriceReply(prices: OwnPrice[], item: string, currency: string | null): string | null {
  if (prices.length === 0) return null;
  const cur = currency ? ` ${currency}` : "";
  const lines = prices.slice(0, 3).map((p) => {
    const day = p.at ? String(p.at).slice(0, 10) : "تاريخ مش مسجّل";
    const per = p.unit ? ` لكل ${p.unit}` : " للوحدة";
    return `- ${p.name}: ${p.unitPrice}${cur}${per} (البند ${p.total}${cur} × ${p.quantity})${p.shop ? ` من ${p.shop}` : ""} — ${day}`;
  });
  return `سعر "${item}" من فواتير العميل نفسه (مسجّل، مش تقدير):\n${lines.join("\n")}`;
}
