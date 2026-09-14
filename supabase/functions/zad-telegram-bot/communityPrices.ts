// بوست قناة مجتمع زاد اليومي: أرخص الأسعار اللي بلّغ عنها العملاء (zad_cheapest_prices).
// صافي عشان يتختبر — الداتابيز والإرسال في index.ts.

export interface CheapestRow {
  item_name: string;
  min_price: number;
  avg_price: number;
  reports: number;
  cheapest_location: string | null;
  cheapest_store: string | null;
}

/** العملات اللي بنلف عليها واسمها في البوست. بيانات عرض للقناة (عربي — جمهور القناة عربي). */
export const COMMUNITY_MARKETS: Array<{ currency: string; label: string }> = [
  { currency: "EGP", label: "🇪🇬 مصر" },
  { currency: "SAR", label: "🇸🇦 السعودية" },
  { currency: "AED", label: "🇦🇪 الإمارات" },
  { currency: "KWD", label: "🇰🇼 الكويت" },
  { currency: "QAR", label: "🇶🇦 قطر" },
  { currency: "JOD", label: "🇯🇴 الأردن" },
  { currency: "MAD", label: "🇲🇦 المغرب" },
];

/** سوق بأقل من كده بلاغات مايتنشرش — بوست فيه صنف واحد مش «مجتمع». */
export const MIN_ITEMS_PER_MARKET = 3;
const MAX_ITEMS_PER_MARKET = 8;

const clean = (v: unknown, max: number) =>
  typeof v === "string" ? v.replace(/[\u0000-\u001f\u007f<>]/g, " ").replace(/\s+/g, " ").trim().slice(0, max) : "";

function money(v: number): string {
  return Number.isInteger(v) ? String(v) : v.toFixed(2).replace(/\.?0+$/, "");
}

/** `null` = مفيش سوق فيه بلاغات كفاية — مابنبعتش بوست فاضي. */
export function formatCommunityPricesPost(byMarket: Array<{ currency: string; label: string; rows: CheapestRow[] }>, days: number): string | null {
  const sections = byMarket
    .filter((m) => m.rows.length >= MIN_ITEMS_PER_MARKET)
    .map((m) => {
      const lines = m.rows.slice(0, MAX_ITEMS_PER_MARKET).map((r) => {
        const where = [clean(r.cheapest_store, 40), clean(r.cheapest_location, 40)].filter(Boolean).join("، ");
        return `• ${clean(r.item_name, 40)} — ${money(r.min_price)} ${m.currency}${where ? ` (${where})` : ""} · ${r.reports} بلاغ`;
      });
      return [m.label, ...lines].join("\n");
    });
  if (sections.length === 0) return null;
  return [
    `🛒 أرخص أسعار بلّغ عنها مجتمع زاد (آخر ${days} أيام)`,
    "",
    sections.join("\n\n"),
    "",
    "الأسعار من بلاغات المستخدمين مش أسعار رسمية. شوفت سعر أرخص؟ بلّغ عنه من «لوحة الأسعار» في زاد 💚",
  ].join("\n");
}
