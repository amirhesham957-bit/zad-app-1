// اللي يتشري من المحل ده (٢٠٢٦-١٠-١٠).
//
// المالك وصله «انت جنب عطارة الرحمة» و«انت جنب مجمدات الأسمر» وتحت الاتنين نفس القايمة كلها:
// شامبو وبيض وكريم تشيز. Google Places بيرجّع نوعين بس (سوبرماركت وصيدلية)، فالعطارة والجزارة
// والمجمدات بتوصل «سوبرماركت»، والسيرفر كان بيبعت كل قايمة التسوق وكل النواقص لأي محل مش صيدلية.
//
// هنا: اسم المحل بيقول تخصّصه، واسم الصنف (أو فئته في المخزن) بيقول قسمه. المحل المتخصص بياخد
// أصناف قسمه بس، والسوبرماركت العادي بياخد القايمة كلها زي الأول — مفيش حاجة بتستخبى من محل
// بيبيع كل حاجة. صافي من غير داتابيز عشان يتختبر.

import { itemKey } from "./shared.ts";

export type StoreSpecialty = "spices" | "meat" | "produce" | "bakery" | "general";

type Section = Exclude<StoreSpecialty, "general">;

/** كلمات في اسم المحل. «مجمدات» و«فراخ» و«سمك» معاهم: محلات اللحوم والطيور والمجمد. */
const STORE_WORDS: Record<Section, string[]> = {
  spices: ["عطار", "عطاره", "عطارة", "بهارات", "توابل"],
  meat: ["جزار", "جزاره", "جزارة", "لحوم", "مجمدات", "فراخ", "دواجن", "طيور", "اسماك", "أسماك", "سمك", "بوري"],
  produce: ["خضار", "خضروات", "فاكهه", "فاكهة", "فواكه"],
  bakery: ["مخبز", "مخابز", "فرن", "افران", "أفران", "مخبوزات"],
};

/** كلمات في اسم الصنف. الأدق الأول: «فلفل أسود» بهارات قبل ما «فلفل» يبقى خضار. */
const ITEM_WORDS: Array<[Section, string[]]> = [
  ["spices", [
    "فلفل اسود", "كمون", "كركم", "قرفه", "بهارات", "توابل", "ينسون", "كركديه", "زبيب", "سمسم",
    "حبه البركه", "شطه", "زعتر", "بابونج", "تمر هندي", "لبان", "حلبه", "كزبره ناشفه", "جنزبيل",
    "زنجبيل", "قرنفل", "حبهان", "هيل", "مستكه", "عرقسوس", "سوداني", "لوز", "عين جمل", "فستق", "كاجو",
  ]],
  ["meat", [
    "لحم", "لحمه", "فراخ", "دجاج", "دواجن", "بانيه", "كبده", "سمك", "جمبري", "مفروم", "برجر", "سجق",
    "كفته", "اوراك", "صدور", "وراك", "بط", "ديك رومي", "سوسيس", "استيك",
  ]],
  ["produce", [
    "طماطم", "بصل", "بطاطس", "ليمون", "خيار", "جزر", "كوسه", "باذنجان", "فلفل", "خس", "بقدونس",
    "كزبره", "شبت", "ثوم", "موز", "تفاح", "برتقال", "يوسفي", "عنب", "بلح", "مانجو", "فراوله", "جوافه",
    "بطيخ", "كانتلوب", "رمان", "خضار", "فاكهه", "سبانخ", "ملوخيه", "باميه", "بسله", "فاصوليا خضرا",
  ]],
  ["bakery", ["خبز", "عيش", "توست", "كرواسون", "باتيه", "فينو", "كيك", "بقسماط", "شامي"]],
];

/** فئات المخزن المعيارية (zad_canonical_category) اللي بتحدد القسم لوحدها. */
const CATEGORY_SECTION: Record<string, Section> = {
  "اللحوم": "meat",
  "الخضار": "produce",
  "الفواكه": "produce",
  "المخبوزات": "bakery",
};

const STORE_KEYS: Array<[Section, string[]]> = (Object.entries(STORE_WORDS) as Array<[Section, string[]]>)
  .map(([s, words]) => [s, words.map(itemKey)]);
const ITEM_KEYS: Array<[Section, string[]]> = ITEM_WORDS.map(([s, words]) => [s, words.map(itemKey)]);

/** الكلمة موجودة ككلمة كاملة أو بداية كلمة («لحمة» في «لحمة مفرومة»، «فراخ» في «الفراخ»). */
function hasWord(text: string, word: string): boolean {
  for (const token of text.split(/[\s\-_/،,()]+/)) {
    const t = token.startsWith("ال") && token.length > 3 ? token.slice(2) : token;
    if (t === word || token === word) return true;
  }
  return word.includes(" ") && ` ${text} `.includes(` ${word} `);
}

/** «عطارة الرحمة» ⇒ spices، «مجمدات الأسمر» ⇒ meat، «كارفور» ⇒ general. */
export function storeSpecialty(storeName: string): StoreSpecialty {
  const key = itemKey(storeName);
  for (const [section, words] of STORE_KEYS) {
    if (words.some((w) => hasWord(key, w))) return section;
  }
  return "general";
}

/** قسم الصنف من اسمه، وإلا من فئته في المخزن. null = مش واضح (يروح للسوبرماركت بس). */
export function itemSection(itemName: string, inventoryCategory?: string | null): Section | null {
  const key = itemKey(itemName);
  for (const [section, words] of ITEM_KEYS) {
    if (words.some((w) => hasWord(key, w))) return section;
  }
  const fromCategory = inventoryCategory ? CATEGORY_SECTION[inventoryCategory.trim()] : undefined;
  return fromCategory ?? null;
}

/**
 * الأصناف اللي ليها معنى في المحل ده. سوبرماركت عادي = كلهم. محل متخصص = قسمه بس، وصنف من غير
 * قسم واضح مايتقالش عنده (أحسن من «شامبو» عند العطار).
 */
export function itemsForStore(
  storeName: string,
  items: string[],
  categoryOf: (item: string) => string | null | undefined = () => null,
): string[] {
  const specialty = storeSpecialty(storeName);
  if (specialty === "general") return items;
  return items.filter((item) => itemSection(item, categoryOf(item)) === specialty);
}

/**
 * زرار «افتح على الخريطة» تحت رسالة المحل (٢٠٢٦-١٠-١٠): المالك طلب اللوكيشن والبوت رد بكلام
 * وسأله «انت في أنهي منطقة؟». النقطة دي نقطة المحل نفسه (مركز نطاقه على الموبايل) — مكان عام، مش
 * مكان العميل. أي رقم مش إحداثي صالح = مفيش زرار.
 */
export function storeMapUrl(lat: unknown, lon: unknown): string | null {
  if (typeof lat !== "number" || typeof lon !== "number") return null;
  if (!Number.isFinite(lat) || !Number.isFinite(lon)) return null;
  if (Math.abs(lat) > 90 || Math.abs(lon) > 180 || (lat === 0 && lon === 0)) return null;
  return `https://www.google.com/maps/search/?api=1&query=${lat.toFixed(5)},${lon.toFixed(5)}`;
}

/**
 * «هات اللوكيشن» في الشات (الموجة ٣، ٢٠٢٦-١٠-١٠): الزرار كان في رسالة البوت بس، والعقل لما يتسأل
 * كان بيسأل «انت في أنهي منطقة؟». مهمة store_arrival بقت شايلة رابطها (agent_tasks.map_url،
 * 20261010180000). الأحدث الأول؛ `wanted` = اسم محل لو العميل سمّاه.
 */
export function storeLocationFrom(
  rows: ReadonlyArray<{ task_description: string | null; map_url: string | null; created_at: string }>,
  wanted?: string | null,
): { store: string; map_url: string; at: string } | null {
  const key = itemKey(String(wanted ?? "").trim());
  const found = [...rows]
    .filter((r) => typeof r.map_url === "string" && r.map_url.startsWith("https://www.google.com/maps/search/"))
    .sort((a, b) => Date.parse(b.created_at) - Date.parse(a.created_at))
    .map((r) => ({ store: /«([^»]*)»/.exec(r.task_description ?? "")?.[1]?.trim() ?? "", map_url: r.map_url as string, at: r.created_at }))
    .filter((r) => r.store.length > 0)
    .find((r) => !key || itemKey(r.store).includes(key) || key.includes(itemKey(r.store)));
  return found ?? null;
}

/** صف agent_tasks لرسالة المحل — ومعاه رابط المحل لو النقطة صالحة («هات اللوكيشن» بعدها بيقراه). */
export function storeArrivalTask(
  userId: string, description: string, result: string, lat: unknown, lon: unknown, nowIso: string,
): Record<string, unknown> & { map_url?: string } {
  const mapUrl = storeMapUrl(lat, lon);
  return {
    user_id: userId, kind: "store_arrival", status: "done", scheduled_for: nowIso,
    task_description: description, result,
    ...(mapUrl ? { map_url: mapUrl } : {}),
  };
}
