// زاد بتعلّق على الفاتورة بهزار (receipt_reaction، ٢٠٢٦-٠٩-١٤).
//
// الموبايل بيبعت أصناف الفاتورة بعد ما العميل يحفظها. ده نص جاي من OCR — بيانات مش تعليمات،
// فبيتنضف ويتقص هنا قبل ما يدخل أي برومبت (وجوه البرومبت نفسه في بلوك === بيانات ===).
// `highlight` بيختار حاجة واحدة يتعلّق عليها — عشان التعليق يبقى عن حاجة حقيقية في الفاتورة
// والقالب الاحتياطي يقدر يقولها من غير موديل.

export interface ReceiptItemFact {
  name: string;
  price: number;
  quantity: number;
}

export interface ReceiptFacts {
  store: string;
  total: number;
  currency: string | null;
  items: ReceiptItemFact[];
  highlight: { kind: "snacks" | "repeat" | "priciest"; item: string; count: number; amount: number };
}

const clean = (v: unknown, max: number) =>
  typeof v === "string" ? v.replace(/[\u0000-\u001f\u007f\u00ab\u00bb=]/g, " ").replace(/\s+/g, " ").trim().slice(0, max) : "";

/** مطابقة مع أسماء أصناف الفاتورة — بيانات، مش نصوص عرض. */
const SNACK_WORDS = [
  "شيبسي", "شيبس", "بيبسي", "كوكاكولا", "كولا", "سفن", "شوكولات", "بسكويت", "حلويات", "مولتو", "كيك",
  "آيس كريم", "ايس كريم", "جيلي", "مقرمشات", "chips", "cola", "pepsi", "chocolate", "candy", "snack",
];

export function sanitizeReceiptFacts(raw: unknown): ReceiptFacts | null {
  const r = (raw && typeof raw === "object" ? raw : {}) as Record<string, unknown>;
  const total = Number(r.total);
  const items = (Array.isArray(r.items) ? r.items : []).slice(0, 25).map((it) => {
    const o = (it && typeof it === "object" ? it : {}) as Record<string, unknown>;
    return {
      name: clean(o.name, 40),
      price: Math.max(0, Math.round((Number(o.price) || 0) * 100) / 100),
      quantity: Math.min(99, Math.max(1, Math.round(Number(o.quantity) || 1))),
    };
  }).filter((i) => i.name.length > 0);
  if (!Number.isFinite(total) || total <= 0 || items.length === 0) return null;

  const snacks = items.filter((i) => SNACK_WORDS.some((w) => i.name.toLowerCase().includes(w)));
  const snackCount = snacks.reduce((a, i) => a + i.quantity, 0);
  const repeated = [...items].sort((a, b) => b.quantity - a.quantity)[0];
  const priciest = [...items].sort((a, b) => b.price * b.quantity - a.price * a.quantity)[0];
  const highlight = snackCount >= 3
    ? { kind: "snacks" as const, item: snacks[0].name, count: snackCount, amount: Math.round(snacks.reduce((a, i) => a + i.price * i.quantity, 0)) }
    : repeated.quantity >= 4
      ? { kind: "repeat" as const, item: repeated.name, count: repeated.quantity, amount: Math.round(repeated.price * repeated.quantity) }
      : { kind: "priciest" as const, item: priciest.name, count: priciest.quantity, amount: Math.round(priciest.price * priciest.quantity) };

  return {
    store: clean(r.store, 60) || "المحل",
    total: Math.round(total * 100) / 100,
    currency: clean(r.currency, 10) || null,
    items,
    highlight,
  };
}

/** نفس الفاتورة (محل + إجمالي + أصناف) = نفس المفتاح — حفظها مرتين مايطلعش تعليقين. */
export function receiptKey(facts: ReceiptFacts): string {
  const basis = `${facts.store}|${facts.total}|${facts.items.map((i) => `${i.name}x${i.quantity}`).join(",")}`;
  let h = 0;
  for (let i = 0; i < basis.length; i++) h = (Math.imul(31, h) + basis.charCodeAt(i)) | 0;
  return (h >>> 0).toString(36);
}

/** أقصى تعليقات فواتير في اليوم — الهزار اللطيف لو اتكرر بيبقى رخم. */
export const RECEIPT_REACTIONS_PER_DAY = 2;
