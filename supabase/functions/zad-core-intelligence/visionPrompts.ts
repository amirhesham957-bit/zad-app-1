// visionPrompts.ts — برومبتات رؤية المخزون والدوا، ببلد العميل بدل «Saudi» ثابتة (الموجة ٤، طلب المالك ٢٠٢٦-١٠-١١).
//
// السطر الأول كان «a Saudi household app» و«a Saudi family health app» والعملاء أغلبهم مصريين — الموديل كان بيتوقع ماركات
// وعلب سعودية وهو بيبص على علبة دوا مصرية. دلوقتي الجملة الأولى بتقول بلد العميل (zad_users.country، لصاحب التوكن بس)،
// ومن غير بلد معروفة: «بلد عربي، غالباً مصر أو الخليج». باقي البرومبتين زي ما كانوا حرفياً (اتنقلوا من index.ts).
// برومبت البون (receiptPrompt.ts) اتعدّل قبلها في الموجة ٣ ومابيقولش بلد بعينها.

const COUNTRY_EN: Record<string, string> = {
  EG: "Egypt", SA: "Saudi Arabia", AE: "the United Arab Emirates", KW: "Kuwait", QA: "Qatar", BH: "Bahrain", OM: "Oman",
  JO: "Jordan", LB: "Lebanon", IQ: "Iraq", SY: "Syria", YE: "Yemen", PS: "Palestine", LY: "Libya", SD: "Sudan",
  MA: "Morocco", TN: "Tunisia", DZ: "Algeria", TR: "Turkey",
};

/** مين العميل: بلده لو معروفة، وإلا جملة عامة. اسم البلد بالإنجليزي من جدول ثابت — مفيش نص من العميل هنا. */
export function marketSentence(country: string | null | undefined): string {
  const name = COUNTRY_EN[String(country ?? "").trim().toUpperCase()];
  return name
    ? `The customer lives in ${name}: expect products, brands and packaging sold in ${name}, labelled in Arabic, English or both. `
    : "The customer lives in an Arab country (most often Egypt or the Gulf): expect local brands, labelled in Arabic, English or both. ";
}

export function inventoryPrompt(country: string | null | undefined): string {
  return "You are an inventory-tracking vision AI for ZAD, a household app for Arab families. " +
    marketSentence(country) +
    INVENTORY_REST;
}

export function medicinePrompt(country: string | null | undefined): string {
  return "You are a specialized medical package / prescription scanner AI for ZAD, a family health app for Arab families. " +
    marketSentence(country) +
    MEDICINE_REST;
}

const INVENTORY_REST = "Look at the image carefully and identify EVERY visible product, food item, or branded package — " +
  "read the label text where it is legible and prefer the real product name over a generic noun. " +
  "Even if the image shows a single bottle, can, box or bag, list it. " +
  "If the image contains no grocery/household products at all (a document, a person, a landscape), " +
  "return an empty items array — never invent a product just to avoid an empty list. " +
  // كان المثال في الـ schema نفسه بيقول "عام" — قيمة الموديل بيرجعها فعلاً
  // غالباً، ومش من فئات تابات المخزون في التطبيق (InventoryScreen.kt's
  // categoryDefs)، فالصنف كان بيظهر تحت "أخرى" دايماً حتى لو واضح إنه لبن/جبنة.
  "`category` MUST be exactly one of these Arabic values — never anything else, never \"عام\": " +
  "البقالة، الخضار، الفواكه، اللحوم، الألبان، المشروبات، العناية، أخرى. " +
  "Milk, cheese, yogurt, laban → الألبان. Fresh vegetables → الخضار. Fresh fruit → الفواكه. " +
  "Raw/frozen meat, chicken, fish → اللحوم. Juice, soda, water → المشروبات. " +
  "Soap, shampoo, cleaning supplies → العناية. Packaged/canned/dry goods → البقالة. " +
  "Return ONLY a JSON object, no markdown and no commentary: " +
  "{\"items\":[{\"name\":\"\",\"quantity\":1.0,\"unit\":\"قطعة\",\"category\":\"الألبان\"}]}";

const MEDICINE_REST = "Carefully examine the medicine packaging, box, blister pack, or bottle in the image and extract: " +
  "1. `name`: Trade / brand name (e.g. 'Panadol Extra', 'Augmentin 1g', 'Concor 5mg', 'بنادول'). " +
  "2. `active_ingredient`: Scientific / active substance if legible (e.g. 'Paracetamol + Caffeine', 'Bisoprolol'). " +
  "3. `dosage`: Dosage strength or directions printed (e.g. '500 mg', 'قرص بعد الأكل'). " +
  "4. `category`: One of: 'عام'، 'مسكن'، 'مضاد حيوي'، 'فيتامين'، 'مزمن'. " +
  "5. `quantity`: Number of pills/units in the pack (integer, default 1). " +
  "6. `unit`: Unit in Arabic (e.g. 'قرص', 'حبة', 'كبسولة', 'مل', 'بخاخ', 'نقطة', 'كريم', 'كيس', 'أمبول', 'علبة'). " +
  "7. `expiry_date`: Expiry date in YYYY-MM-DD or YYYY-MM format if visible on pack, or null. " +
  "8. `daily_dose_count`: Recommended daily dose frequency if stated (e.g. 1, 2, 3), default 1. " +
  "9. `suggested_times`: Array of 24-hour time strings (e.g. ['08:00', '20:00']). " +
  "Return ONLY a JSON object: " +
  "{\"name\":\"\",\"active_ingredient\":\"\",\"dosage\":\"\",\"category\":\"مسكن\",\"quantity\":20,\"unit\":\"قرص\",\"expiry_date\":null,\"daily_dose_count\":1,\"suggested_times\":[\"08:00\"]}";
