// receiptPrices.ts — سطور بون تليجرام كبلاغات أسعار للجمهور (الموجة ٥، ٢٠٢٦-١٠-١١).
//
// نفس قواعد التطبيق بالظبط (zad_flutter/lib/shared/prices/domain/prices.dart، receiptPriceReports):
// من غير اسم محل مفيش بلاغ (سعر مالوش مكان مايفيدش اللي بعده)، سعر الوحدة (السعر ÷ الكمية) بخانتين،
// نفس حدود zad_report_price، و٢٠ سطر بالكتير عشان السيرفر بياخد ٣٠ بلاغ في الساعة للعميل.
// لو غيّرت هنا غيّر هناك.

export const RECEIPT_REPORTS_MAX = 20;

export interface ReceiptLine {
  name?: string | null;
  price?: number | null;
  quantity?: number | null;
  category?: string | null;
}

export interface ReceiptPriceReport {
  item: string;
  unitPrice: number;
  category: string | null;
}

/** نفس tidyReportText: المسافات المتكررة مسافة واحدة، ومن غير أطراف. */
export function tidyReportText(raw: unknown): string {
  return String(raw ?? "").replace(/\s+/g, " ").trim();
}

export function receiptPriceReports(store: unknown, lines: ReceiptLine[]): ReceiptPriceReport[] {
  const shop = tidyReportText(store);
  if (!shop || shop.length > 60) return [];
  const out: ReceiptPriceReport[] = [];
  for (const l of lines) {
    const name = tidyReportText(l.name);
    if (name.length < 2 || name.length > 60) continue;
    const price = Number(l.price);
    const qty = Number(l.quantity);
    if (!Number.isFinite(price) || price <= 0) continue;
    const unit = Math.round(((Number.isFinite(qty) && qty > 0) ? price / qty : price) * 100) / 100;
    if (!(unit > 0) || unit > 1_000_000) continue;
    const category = tidyReportText(l.category).slice(0, 40);
    out.push({ item: name, unitPrice: unit, category: category || null });
    if (out.length === RECEIPT_REPORTS_MAX) break;
  }
  return out;
}
