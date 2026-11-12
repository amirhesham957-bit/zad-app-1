// لهجة زاد مع كل عميل — مصدر واحد للشات والبوت والصوت (٢٠٢٦-٠٩-١٤).
//
// الشكوى: البوت بيرد على المصري بالفصحى. السبب الجذري كان مزدوج: (١) تعليمة اللهجة سطر
// واحد مكتوب هو نفسه بالفصحى («تحدث باللهجة المصرية...») جوه برومبت طويل أغلبه فصحى، فالموديل
// بيقلّد لغة البرومبت مش التعليمة؛ و(٢) البرومبت نفسه كان بيقول «بأسلوب مصري مرح» لكل الناس
// (السعودي كمان)، والبوت الاحتياطي كان «الافتراضي مصري». هنا كل لهجة تعليمتها مكتوبة **بيها**
// وفيها أمثلة ردود حقيقية ومنع صريح للفصحى، والبلوك بيتحط أول البرومبت وتذكير في آخره.
//
// أولوية اختيار اللهجة: اللي العميل اختارها بنفسه (ملفه) ← لهجة واضحة في كلامه ← بلد السوق ←
// العملة ← مصري (أغلب العملاء).

export type DialectCode =
  | "EG" | "SA" | "GULF" | "LEVANT" | "IQ" | "MA" | "TN" | "DZ" | "LY" | "SD" | "YE" | "TR" | "EN";

interface DialectSpec {
  locale: string;
  /** وصف قصير للبرومبت الصوتي/اللحظات. */
  short: string;
  /** القواعد مكتوبة باللهجة نفسها. */
  rules: string;
  examples: string[];
}

const FORMAL_BAN =
  "ممنوع الفصحى الرسمية تماماً (زي «يمكنك»، «سوف»، «لقد»، «عذراً»، «هل ترغب في»، «تم بنجاح»). اكتب زي ما حد من البلد دي بيكتب لصاحبه على الواتساب.";

/** ١٠.١٦ (٤): زي أهل المنطقة بس باحترام — اللهجة مش معناها ألفاظ شارع. */
const RESPECT_LINE =
  "وكلامك محترم: زي ما واحد محترم من المنطقة دي بيكلّم حد عزيز عليه — من غير شتايم ولا ألفاظ سوقية ولا تريقة على العميل، حتى لو هو بيهزر كده.";

export const DIALECTS: Record<DialectCode, DialectSpec> = {
  EG: {
    locale: "ar-EG",
    short: "اتكلمي مصري عادي زي ما بنتكلم في البيت.",
    rules: "اتكلم مصري عادي خالص زي ما المصريين بيتكلموا في البيت ومع صحابهم — مش لغة كتب ولا مذيع.",
    examples: ["تمام، سجلتهالك 👌", "ولا يهمك، هظبطهالك دلوقتي", "بص، الشهر ده صرفت أكتر شوية على الأكل برّه"],
  },
  SA: {
    locale: "ar-SA",
    short: "تكلمي سعودي عادي مثل ما نسولف.",
    rules: "تكلم سعودي عادي مثل ما نسولف مع بعض — لا فصحى ولا مصري.",
    examples: ["أبشر، سجلتها لك 👌", "ولا يهمك، الحين أضبطها لك", "شوف، هالشهر صرفت زيادة شوي على المطاعم"],
  },
  GULF: {
    locale: "ar-AE",
    short: "تكلمي خليجي عادي.",
    rules: "تكلم خليجي عادي مثل ما نتكلم في البيت — لا فصحى ولا مصري.",
    examples: ["أبشر، سجلتها لك", "لا تشيل هم، الحين أسويها", "هالشهر صرفت وايد على المطاعم"],
  },
  LEVANT: {
    locale: "ar-JO",
    short: "احكي شامي طبيعي.",
    rules: "احكي شامي طبيعي متل ما منحكي بالبيت — لا فصحى ولا مصري.",
    examples: ["تكرم عينك، سجلتلك ياها", "ولا يهمك، هلق بزبطلك ياها", "هالشهر صرفت كتير عالمطاعم"],
  },
  IQ: {
    locale: "ar-IQ",
    short: "احچي عراقي طبيعي.",
    rules: "احچي عراقي طبيعي مثل ما نحچي بالبيت — لا فصحى ولا مصري.",
    examples: ["تدلل، سجلتها إلك", "لا تشيل هم، هسه أسويها", "هالشهر صرفت هواية عالمطاعم"],
  },
  MA: {
    locale: "ar-MA",
    short: "هضري بالدارجة المغربية.",
    rules: "هضر بالدارجة المغربية بحال شي صاحب — ماشي بالفصحى.",
    examples: ["واخا، سجلتها ليك", "ماشي مشكل، دابا نديرها ليك", "هاد الشهر صرفتي بزاف على الماكلة برا"],
  },
  TN: {
    locale: "ar-TN",
    short: "احكي تونسي.",
    rules: "احكي بالتونسي كيف ما نحكيو في الدار — موش بالفصحى.",
    examples: ["باهي، سجلتهالك", "ما تقلقش، توا نعملهالك", "الشهر هذا صرفت برشا على الماكلة لبرا"],
  },
  DZ: {
    locale: "ar-DZ",
    short: "هدري بالدزيري.",
    rules: "هدر بالدارجة الجزائرية كيما نهدرو في الدار — ماشي بالفصحى.",
    examples: ["مليح، سجلتهالك", "ما تقلقش، دركا ندير لك", "هاد الشهر صرفت بزاف على الماكلة برا"],
  },
  LY: {
    locale: "ar-LY",
    short: "احكي ليبي.",
    rules: "احكي ليبي عادي كيف ما نحكوا في الحوش — مش فصحى.",
    examples: ["باهي، سجلتهالك", "ما تشيلش هم، توا نديرهالك", "الشهر هذا صرفت واجد على الماكلة برا"],
  },
  SD: {
    locale: "ar-SD",
    short: "اتكلمي سوداني.",
    rules: "اتكلم سوداني عادي زي ما بنتكلم في البيت — ما فصحى.",
    examples: ["تمام، سجلتها ليك", "ما تشيل هم، هسي بسويها ليك", "الشهر ده صرفت كتير في الأكل برّه"],
  },
  YE: {
    locale: "ar-YE",
    short: "تكلمي يمني.",
    rules: "تكلم يمني عادي مثل ما نتكلم في البيت — مش فصحى.",
    examples: ["تمام، سجلتها لك", "ولا يهمك، الحين باسويها لك", "هذا الشهر صرفت كثير على المطاعم"],
  },
  TR: {
    locale: "tr-TR",
    short: "Doğal, samimi günlük Türkçe konuş.",
    rules: "Tamamen doğal, samimi ve günlük Türkçe konuş, bir arkadaşına yazar gibi. Arapça kullanma.",
    examples: ["Tamam, kaydettim 👌", "Merak etme, hemen hallediyorum", "Bu ay dışarıda yemeğe biraz fazla harcadın"],
  },
  EN: {
    locale: "en",
    short: "Talk casual, friendly English.",
    rules: "Talk like a friend texting — casual, warm English. No stiff or formal phrasing.",
    examples: ["Done, logged it 👌", "No worries, fixing that now", "You spent a bit more on eating out this month"],
  },
};

// ── لهجات جوه البلد (ZAD_PLAN ١٠.١٦، ٢٠٢٦-١١-١٢) ──────────────────────────────────────
//
// الشكوى: «سعودي على مصري ملغبط». السعودية كانت لهجة واحدة (نجدي في الأمثلة) لجدة والرياض
// والدمام وأبها. المنطقة **بتدقّق** لهجة البلد بس، مابتغيّرهاش: الكود المتخزن في
// `zad_customer_profile.dialect` والمقارنات (الحملات، رسايل البوت) فاضلين على `SA`، فمفيش
// مايجريشن. المنطقة جاية من مدينة الملف؛ لو العميل نفسه بيتكلم لهجة تانية، البلوك بيقول
// للموديل يمشي على كلامه (أولوية الخطة: اختياره ⇐ كلامه ⇐ مدينته ⇐ البلد).
//
// ⚠️ القواعد والأمثلة دي محتاجة مراجعة من حد من كل منطقة قبل ما تتنشر (شرط المالك في ١٠.١٦).

export type RegionCode = "SA_HIJAZ" | "SA_NAJD" | "SA_EAST" | "SA_SOUTH";

interface RegionSpec {
  /** اللهجة الأم — المنطقة بتشتغل بس لو لهجة العميل دي. */
  parent: DialectCode;
  short: string;
  rules: string;
  examples: string[];
}

export const REGIONS: Record<RegionCode, RegionSpec> = {
  SA_HIJAZ: {
    parent: "SA",
    short: "تكلّمي حجازي زي أهل جدة.",
    rules: "تكلّم حجازي عادي زي أهل جدة ومكة والمدينة لما يسولفوا — «دحين»، «إيش»، «كدا»، «مرّة»، «أبغى» — لا فصحى ولا نجدي ولا مصري.",
    examples: ["أبشر، سجّلتها لك 👌", "ولا يهمك، دحين أظبطها لك", "شوف، الشهر دا صرفت مرّة على المطاعم"],
  },
  SA_NAJD: {
    parent: "SA",
    short: "تكلّمي نجدي زي أهل الرياض.",
    rules: "تكلّم نجدي عادي زي أهل الرياض والقصيم لما يسولفون — «الحين»، «وش»، «أبي»، «زين»، «ترى» — لا فصحى ولا مصري.",
    examples: ["أبشر، سجلتها لك 👌", "ولا يهمك، الحين أضبطها لك", "ترى هالشهر صرفت زيادة على المطاعم"],
  },
  SA_EAST: {
    parent: "SA",
    short: "تكلّمي زي أهل الشرقية.",
    rules: "تكلّم زي أهل الشرقية (الدمام والخبر والأحساء) لما يسولفون — «الحين»، «وايد»، «زين»، «شلون» — لا فصحى ولا مصري.",
    examples: ["أبشر، سجلتها لك", "لا تشيل هم، الحين أسويها لك", "هالشهر صرفت وايد على المطاعم"],
  },
  SA_SOUTH: {
    parent: "SA",
    short: "تكلّمي سعودي بسيط زي أهل الجنوب.",
    // الجنوب لهجاته كتير (عسير، جازان، نجران، الباحة) — مانقلّدش كلمات مش متأكدين منها: سعودي
    // بسيط مفهوم للكل، والموديل يمشي على كلام العميل لو بان.
    rules: "تكلّم سعودي بسيط وقريب زي أهل الجنوب (أبها وخميس مشيط وجازان ونجران) لما يسولفون — لا فصحى ولا مصري، ولا تقلّد كلمات ما تعرفها؛ وإذا العميل كتب بلهجته امشِ عليها.",
    examples: ["أبشر، سجلتها لك", "ولا يهمك، الحين أضبطها لك", "هالشهر صرفت زيادة شوي على المطاعم"],
  },
};

/** أسماء المدن زي ما العميل بيكتبها — بيانات مطابقة، مش نصوص عرض. */
const CITY_TO_REGION: Array<[RegionCode, string[]]> = [
  ["SA_HIJAZ", ["جدة", "جده", "jeddah", "jiddah", "jedda", "مكة", "مكه", "مكة المكرمة", "makkah", "mecca", "makkah al mukarramah", "المدينة", "المدينه", "المدينة المنورة", "المدينه المنوره", "madinah", "medina", "al madinah", "الطائف", "الطايف", "taif", "ينبع", "yanbu", "رابغ", "rabigh"]],
  ["SA_NAJD", ["الرياض", "رياض", "riyadh", "القصيم", "qassim", "al qassim", "بريدة", "بريده", "buraydah", "buraidah", "عنيزة", "عنيزه", "unaizah", "حائل", "حايل", "hail", "ha'il", "الخرج", "alkharj", "al kharj", "المجمعة", "majmaah", "الزلفي", "zulfi", "الدوادمي", "dawadmi", "شقراء"]],
  ["SA_EAST", ["الدمام", "دمام", "dammam", "الخبر", "khobar", "al khobar", "الظهران", "dhahran", "الأحساء", "الاحساء", "الحسا", "al ahsa", "al-ahsa", "hofuf", "الهفوف", "القطيف", "qatif", "الجبيل", "jubail", "حفر الباطن", "hafar al batin"]],
  ["SA_SOUTH", ["أبها", "ابها", "abha", "خميس مشيط", "khamis mushait", "khamis mushayt", "جازان", "جيزان", "jazan", "jizan", "نجران", "najran", "الباحة", "الباحه", "baha", "al baha", "بيشة", "بيشه", "bisha"]],
];

function normCity(raw: unknown): string {
  return String(raw ?? "")
    .trim()
    .toLowerCase()
    .replace(/[ًٌٍَُِّْـ]/g, "")
    .replace(/[أإآ]/g, "ا")
    .replace(/ة/g, "ه")
    .replace(/ى/g, "ي")
    .replace(/^(?:مدينة|مدينه|city of)\s+/, "")
    .replace(/[,،].*$/, "")
    .replace(/\s+/g, " ")
    .trim();
}

/** منطقة المدينة، أو null لو مش معروفة. */
export function regionForCity(city: unknown): RegionCode | null {
  const c = normCity(city);
  if (!c) return null;
  for (const [region, names] of CITY_TO_REGION) {
    if (names.some((n) => normCity(n) === c)) return region;
  }
  return null;
}

/** المنطقة بتدقّق اللهجة بس لو لهجة العميل هي اللهجة الأم بتاعتها (جدة لعميل بيتكلم مصري = مصري). */
export function resolveRegion(dialect: DialectCode, input: { city?: unknown }): RegionCode | null {
  const region = regionForCity(input.city);
  return region && REGIONS[region].parent === dialect ? region : null;
}

/** القواعد والأمثلة النهائية: المنطقة لو موجودة، وإلا لهجة البلد. */
export function dialectSpec(code: DialectCode, region?: RegionCode | null): { rules: string; short: string; examples: string[] } {
  const r = region && REGIONS[region]?.parent === code ? REGIONS[region] : null;
  return r ?? DIALECTS[code];
}

const COUNTRY_TO_DIALECT: Record<string, DialectCode> = {
  EG: "EG", SA: "SA", AE: "GULF", KW: "GULF", QA: "GULF", BH: "GULF", OM: "GULF",
  JO: "LEVANT", LB: "LEVANT", SY: "LEVANT", PS: "LEVANT", IQ: "IQ",
  MA: "MA", TN: "TN", DZ: "DZ", LY: "LY", SD: "SD", YE: "YE", TR: "TR",
  US: "EN", GB: "EN",
};

const COUNTRY_ALIASES: Record<string, string> = {
  "السعودية": "SA", "مصر": "EG", "الإمارات": "AE", "الامارات": "AE", "الكويت": "KW", "قطر": "QA",
  "البحرين": "BH", "عمان": "OM", "عُمان": "OM", "الأردن": "JO", "الاردن": "JO", "لبنان": "LB",
  "العراق": "IQ", "سوريا": "SY", "اليمن": "YE", "فلسطين": "PS", "ليبيا": "LY", "السودان": "SD",
  "المغرب": "MA", "تونس": "TN", "الجزائر": "DZ", "تركيا": "TR",
  EGYPT: "EG", "SAUDI ARABIA": "SA", UAE: "AE", KUWAIT: "KW", QATAR: "QA", JORDAN: "JO", MOROCCO: "MA", TURKEY: "TR",
};

const CURRENCY_TO_COUNTRY: Record<string, string> = {
  EGP: "EG", SAR: "SA", AED: "AE", KWD: "KW", QAR: "QA", BHD: "BH", OMR: "OM", JOD: "JO", LBP: "LB",
  IQD: "IQ", SYP: "SY", YER: "YE", LYD: "LY", SDG: "SD", MAD: "MA", TND: "TN", DZD: "DZ", TRY: "TR",
};

export function countryCode(raw: unknown): string | null {
  const v = String(raw ?? "").trim();
  if (!v) return null;
  const alias = COUNTRY_ALIASES[v] ?? COUNTRY_ALIASES[v.toUpperCase()];
  const code = (alias ?? v).toUpperCase();
  return /^[A-Z]{2}$/.test(code) ? code : null;
}

export function dialectForCountry(raw: unknown): DialectCode | null {
  const code = countryCode(raw);
  return code ? COUNTRY_TO_DIALECT[code] ?? null : null;
}

/** كلمات مميّزة لكل لهجة — بيانات مطابقة مع كلام العميل (زي FoodImageQuery)، مش نصوص عرض. */
const MARKERS: Array<[DialectCode, string[]]> = [
  ["EG", ["عايز", "عاوز", "عايزة", "عاوزة", "ازاي", "إزاي", "دلوقتي", "دلوقت", "ايه", "إيه", "كده", "كدا", "بتاع", "بتاعي", "اوي", "أوي", "فين", "امتى", "إمتى", "ازيك", "إزيك", "معلش", "خالص", "بقى", "مفيش", "عشان", "هو انا", "ليه"]],
  ["SA", ["ابغى", "أبغى", "ابغا", "ودي", "وش", "ليش", "الحين", "اللحين", "زين", "مره", "يبي", "ابي", "أبي", "تكفى", "يالغالي", "هالشي", "شي", "مافي", "كذا"]],
  ["GULF", ["شلون", "وايد", "شنو", "جذي", "اشوى", "ياهل", "حيل", "عساك"]],
  ["LEVANT", ["شو", "هلق", "هلأ", "بدي", "بدك", "كتير", "منيح", "هيك", "كيفك", "مشان", "ليك", "لسا", "بس هيك"]],
  ["IQ", ["شكو", "اكو", "ماكو", "هواية", "شلونك", "هسه", "شكد", "چ", "گ"]],
  ["MA", ["بغيت", "واش", "بزاف", "دابا", "ديال", "كيفاش", "شحال", "واخا", "مزيان"]],
  ["TN", ["برشا", "توا", "باهي", "شنوة", "نحب", "ياسر", "برشة"]],
  ["DZ", ["راني", "واش راك", "دركا", "بزاف", "كاش", "مليح"]],
  ["SD", ["داير", "شنو", "هسي", "كتير شديد", "زول", "ياخ"]],
];

function tokens(text: string): Set<string> {
  return new Set(text.replace(/[^\p{L}\s]/gu, " ").split(/\s+/).filter(Boolean));
}

/**
 * لهجة واضحة في كلام العميل، أو null. محتاجة إشارتين على الأقل (أو فرق واضح) — كلمة زي «شي»
 * موجودة في لهجات كتير، فكلمة واحدة مابتغيّرش لهجة الحساب.
 */
export function detectDialectFromText(text: string): DialectCode | null {
  const t = String(text ?? "");
  if (!t.trim()) return null;
  const latin = (t.match(/[A-Za-z]/g) ?? []).length;
  const arabic = (t.match(/[؀-ۿ]/g) ?? []).length;
  if (latin > 12 && latin > arabic * 3) return /[çğıöşü]/i.test(t) ? "TR" : "EN";
  const words = tokens(t);
  const scores = MARKERS.map(([code, list]) => [code, list.filter((m) => m.includes(" ") ? t.includes(m) : words.has(m) || (m.length === 1 && t.includes(m))).length] as const)
    .filter(([, n]) => n > 0)
    .sort((a, b) => b[1] - a[1]);
  if (scores.length === 0) return null;
  const [best, second] = scores;
  if (best[1] >= 2 && (!second || best[1] > second[1])) return best[0];
  return null;
}

export function resolveDialect(input: {
  preferred?: unknown;
  text?: string | null;
  country?: unknown;
  currency?: unknown;
}): DialectCode {
  const pref = String(input.preferred ?? "").trim().toUpperCase();
  if (pref && pref in DIALECTS) return pref as DialectCode;
  const fromPrefCountry = dialectForCountry(input.preferred);
  if (fromPrefCountry) return fromPrefCountry;
  const fromText = input.text ? detectDialectFromText(input.text) : null;
  if (fromText) return fromText;
  const fromCountry = dialectForCountry(input.country);
  if (fromCountry) return fromCountry;
  const cur = String(input.currency ?? "").trim().toUpperCase();
  const fromCurrency = CURRENCY_TO_COUNTRY[cur] ? COUNTRY_TO_DIALECT[CURRENCY_TO_COUNTRY[cur]] : null;
  return fromCurrency ?? "EG";
}

/** بلوك اللهجة لأول البرومبت — مكتوب باللهجة نفسها، بأمثلة ومنع الفصحى. */
export function dialectPromptBlock(code: DialectCode, region?: RegionCode | null): string {
  const d = dialectSpec(code, region);
  if (code === "TR" || code === "EN") {
    return `**LANGUAGE (mandatory):** ${d.rules}\nExamples: ${d.examples.map((e) => `«${e}»`).join(" · ")}\nIf the customer clearly writes in another language or dialect, follow theirs.`;
  }
  // من غير «===»: العلامة دي محجوزة لأقسام البيانات المحقونة (قاعدة حقن البرومبت)، والتعليمات
  // لازم تفضل برّه أي قسم منها.
  return [
    `**اللهجة (إجباري):** ${d.rules}`,
    `أمثلة لطريقة الرد: ${d.examples.map((e) => `«${e}»`).join(" · ")}`,
    FORMAL_BAN,
    RESPECT_LINE,
    "لو العميل كتب بلهجة تانية بوضوح أو طلب لهجة معينة، امشي على لهجته هو وسجّلها في ملفه.",
  ].join("\n");
}

/** سطر أخير في البرومبت — آخر حاجة الموديل يقراها قبل ما يكتب. */
export function dialectReminder(code: DialectCode, region?: RegionCode | null): string {
  const d = dialectSpec(code, region);
  return code === "TR" || code === "EN"
    ? `Final reminder: ${d.rules}`
    : `تذكير أخير قبل ما تكتب: ${d.rules} ${d.examples[0] ? `(زي «${d.examples[0]}»)` : ""}`;
}

/**
 * بلد الصوت (لكنة Gemini TTS وصوت Azure) — ZAD_PLAN ١٠.١٦ (٣). اللهجة اللي العميل اختارها في «ملفي»
 * (`zad_customer_profile.dialect`) بتكسب على بلد الحساب، زي ما بتكسب في كلام العقل (`resolveDialect`):
 * مصري حسابه سعودي كان العقل بيكلّمه مصري والصوت بيقرا الكلام ده بلكنة سعودية (اتقاس ١٣/١١: الصوت
 * بيقرا `zad_users.country` بس). لو اللهجة هي لهجة بلد الحساب أصلاً (إماراتي ⇐ GULF) بيفضل بلده هو.
 * من غير اختيار = بلد الحساب زي الأول. EN = من غير لكنة (النص نفسه بيحدد).
 */
export function voiceCountry(country: unknown, preferred: unknown): string | null {
  const account = countryCode(country);
  const pref = String(preferred ?? "").trim().toUpperCase();
  if (!pref || !Object.hasOwn(DIALECTS, pref)) return account;
  const code = pref as DialectCode;
  if (account && COUNTRY_TO_DIALECT[account] === code) return account;
  if (code === "EN") return null;
  return DIALECTS[code].locale.split("-")[1] ?? account;
}
