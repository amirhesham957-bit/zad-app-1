// deliveryApps.ts — تطبيقات التوصيل اللي رسومها بتتقري من فواتير العملاء (ZAD_PLAN ٤.١٠).
//
// قايمة مقفولة عن قصد: اسم من بره القايمة (مطعم، محل، غلطة قراية) مابيتخزنش كرسوم توصيل. نفس تطبيقات
// zad_deal_seed_stores في السعودية ومصر، بالعربي والإنجليزي، وبالمفتاح ده بيتطابق العرض مع رسومه.

const APPS: Array<[key: string, name: string, pattern: RegExp]> = [
  ["ninja", "نينجا", /^(ninja|نينجا)$/],
  ["keeta", "كيتا", /^(keeta|كيتا|كيتا السعودية)$/],
  ["hungerstation", "هنقرستيشن", /^(hunger ?station|هنقر ?ستيشن)$/],
  ["jahez", "جاهز", /^(jahez|جاهز)$/],
  ["toyou", "تو يو", /^(to ?you|تو ?يو)$/],
  ["mrsool", "مرسول", /^(mrsool|مرسول)$/],
  ["nana", "نعناع", /^(nana|نعناع)$/],
  ["talabat", "طلبات", /^(talabat|طلبات)$/],
  ["breadfast", "بريدفاست", /^(breadfast|بريدفاست)$/],
  ["rabbit", "رابيت", /^(rabbit|رابيت)$/],
  ["instashop", "إنستاشوب", /^(insta ?shop|انستا ?شوب|إنستا ?شوب)$/],
  ["careem", "كريم", /^(careem|careem food|careem quik|كريم)$/],
];

/** مفتاح التطبيق واسمه بالعربي، أو null لو الاسم مش تطبيق توصيل معروف. */
export function deliveryApp(name: unknown): { key: string; name: string } | null {
  if (typeof name !== "string") return null;
  const clean = name.toLowerCase().replace(/[^\p{L}\p{N}\s]/gu, " ").replace(/\s+/g, " ").trim()
    .replace(/^(تطبيق|app)\s+/, "").replace(/\s+(app|تطبيق|sa|ksa|egypt|eg|مصر|السعودية)$/, "");
  for (const [key, ar, pattern] of APPS) if (pattern.test(clean)) return { key, name: ar };
  return null;
}

/** رسوم توصيل معقولة: رقم موجب أقل من ١٠٠٠ بكسرين، وإلا null. */
export function deliveryFee(raw: unknown): number | null {
  const fee = typeof raw === "string" ? Number(raw.replace(/[^\d.]/g, "")) : Number(raw);
  return Number.isFinite(fee) && fee > 0 && fee < 1000 ? Math.round(fee * 100) / 100 : null;
}
