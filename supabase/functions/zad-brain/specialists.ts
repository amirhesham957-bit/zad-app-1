// specialists.ts — توجيه الوكلاء المتخصصين (المرحلة ٣).
//
// الفكرة: كل رسالة عميل بتتصنّف لوكيل متخصص (مال / مخزون وشيف / صيدلية / عائلة ومهام)،
// والبرومبت بياخد هوية الوكيل + تعليماته. التوجيه **حقيقي مش تجميلي**:
// - التصنيف كلمات-مفتاحية deterministic سريعة (مش نداء موديل إضافي، مش تكلفة).
// - أي رسالة مش متطابقة = وكيل عام (general) بنفس البرومبت الموجود — مفيش تغيير سلوك.
// - كل لفة agent_turn بتسجّل specialist في zad_brain_runs.specialist — ده الـ trace
//   اللي بيخلي "مين عالج الرسالة دي" مثبت في الداتابيز مش ادعاء.
// - الأدوات نفسها بتتحقق في validators.ts زي ما هي — التوجيه ما بيغيرش صلاحيات.

import { SupabaseClient } from "jsr:@supabase/supabase-js@2";

export type SpecialistId = "finance" | "pantry" | "pharmacy" | "family" | "home" | "general";

export interface SpecialistDef {
  id: SpecialistId;
  /** اسم بشري يظهر للعميل في كارت التنفيذ الحي. */
  nameAr: string;
  /** جملة حالة بتظهر وهو شغال ("بيفتش في الدفتر..."). */
  activeLineAr: string;
  keywords: string[];
}

// الكلمات المفتاحية مصرية/عربية فعلية من طريقة كلام العملاء. المطابقة على مستوى
// substring بعد تطبيع بسيط (إزالة تشكيل وتوحيد أ/إ/آ) — مش regex معقد بيتكسر.
export const SPECIALISTS: Record<SpecialistId, SpecialistDef> = {
  finance: {
    id: "finance",
    nameAr: "وكيل المال",
    activeLineAr: "وكيل المال بيفتح الدفتر...",
    keywords: [
      "مصروف", "مصاريف", "صرفت", "دفعت", "فلوس", "جنيه", "ريال", "درهم", "رصيد", "الميزانية",
      "ميزانيتي", "الكارت", "راتب", "قبضت", "قسط", "دين", "ديون", "ادخر", "مدخرات", "باقي",
      "معايا", "فاضل", "اشتراك", "فاتورة", "كهربا", "مياه", "غاز", "انترنت", "بنك", "فيزا",
      "كاش", "سحبت", "حوّلت", "حولت", "تحويل", "إيداع", "ايداع", "budget", "spend", "spent",
      "paid", "salary", "money", "balance",
    ],
  },
  pantry: {
    id: "pantry",
    nameAr: "وكيل المخزون والمطبخ",
    activeLineAr: "وكيل المطبخ بيصور الخزنة...",
    keywords: [
      "مخزون", "خزنة", "لازم نشتري", "ضيف", "زود", "البقالة", "خضار", "فواكه", "لحمة", "لحوم",
      "ألبان", "اللبن", "جبنة", "أرز", "مكرونة", "زيت", "سكر", "شاي", "قهوة", "تاريخ الصلاحية",
      "صلاحية", "هينزل", "وجبة", "أطبخ", "اطبخ", "طبخة", "وصفة", "العشا", "الفطار", "الغدا",
      "غدا", "قائمة الشراء", "التسوق", "سوبر ماركت", "ماركت", "inventory", "grocery", "recipe",
      "cook", "meal", "shopping",
    ],
  },
  pharmacy: {
    id: "pharmacy",
    nameAr: "وكيل الصيدلية",
    activeLineAr: "وكيل الصيدلية بيراجع الجرعات...",
    keywords: [
      "دوا", "الدوا", "دواء", "أدوية", "ادوية", "حبة", "جرعة", "جرعات", "قرص", "شراب", "بخاخ",
      "مرهم", "تحليل", "معمل", "دكتور", "عيادة", "مرض", "سخن", "حرارة", "صداع", "ضغط", "سكري",
      "انسولين", "فيتامين", "مكمل", "مسكن", "antibiotic", "medicine", "dose", "pill",
    ],
  },
  family: {
    id: "family",
    nameAr: "وكيل العائلة والاستهلاك",
    activeLineAr: "وكيل العائلة بيراجع حال البيت...",
    keywords: [
      "مهمة", "مهام", "موعد", "مواعيد", "مذكر", "فكرني", "ذكرني", "جدول", "مناسبة", "عيد ميلاد",
      // صيغ المؤنث/اللهجات: «فكّريني» بعد شيل التشكيل = «فكريني» ومابتحتويش «فكرني» — فالرسالة
      // «فكّريني بكرة الساعة ٥ أروح البنك» كانت بتروح لوكيل المال بسبب «البنك» (قياس ٢٠٢٦-٠٩-١٤).
      "فكريني", "ذكريني", "نبهني", "نبهيني", "فكرنى", "ميعاد", "ميعادي", "اجتماع", "مشوار", "رتبلي مواعيدي", "نظملي",
      "عزومة", "زيارة", "مدرسة", "أطفال", "الاولاد", "اولادي", "زوجتي", "جوازي", "واجب", "امتحان",
      "مذاكرة", "تسبيحة", "tasbih", "task", "reminder", "appointment",
      // استهلاك الأسرة ككل — تقرير/نمط، مش تسجيل صرفة واحدة (ده نطاق finance)
      "استهلاك", "استهلكنا", "بنستهلك", "بنضيع", "ضيعنا", "هدر", "بيتهدر", "معدل الاستهلاك",
      "الأسرة بتصرف", "العيلة بتصرف", "تقرير العيلة", "سلوك الأسرة", "family digest", "consumption",
    ],
  },
  home: {
    id: "home",
    nameAr: "وكيل المنزل والدفع",
    activeLineAr: "وكيل المنزل بيراجع الفواتير والصيانة...",
    keywords: [
      "فاتورة", "فواتير", "كهربا", "مياه", "غاز", "انترنت", "سددت", "سداد", "دفعت الفاتورة",
      "الضمان", "ضمان", "صيانة", "التكييف", "تكييف", "غسالة", "ثلاجة", "بوتاجاز", "سخان",
      "بيت", "شقة", "إيجار البيت", "نظافة", "ترتيب", "عطل", "بايظ", "مكسور", "تصليح",
      "bill", "warranty", "maintenance", "home", "repair",
    ],
  },
  general: {
    id: "general",
    nameAr: "زاد",
    activeLineAr: "",
    keywords: [],
  },
};

const ORDER: SpecialistId[] = ["finance", "pantry", "pharmacy", "family", "home"];

/** تطبيع خفيف: تشكيل، همزات، ألف مقصورة، تاء مربوطة. */
function normalize(text: string): string {
  return text
    .replace(/[\u064B-\u065F\u0670]/g, "")
    .replace(/[أإآ]/g, "ا")
    .replace(/ى/g, "ي")
    .replace(/ة/g, "ه")
    // ی/ک الفارسي: الموديل كتب «تیکت» (٢٠٢٦-١٠-٠٢)، فمكانتش هتطابق «تيكت».
    .replace(/ی/g, "ي")
    .replace(/ک/g, "ك")
    .toLowerCase();
}

/**
 * نية واضحة ⇒ الأدوات اللي لازم تتنادى (٢٠٢٦-٠٩-١٤). قياس حي: موديل الوكيل (flash-lite) مع ٣٨–٦٠ أداة
 * كان بيرد بكلام من غير ما ينادي add_appointment («فكّريني بكرة الساعة ٥») ولا update_customer_profile
 * («أنا اسمي كريم وبشتغل محاسب»)، ومع ٢٤ أداة نادى صح. فلو اللفة الأولى رجعت من غير أدوات والنية دي
 * واضحة، العقل بيعيد السؤال بالأدوات دي بس. مش بيجبر نداء: الموديل لسه يقدر يرد بكلام.
 */
// كلمة تذكير أو ميعاد صريحة، مش ساعة لوحدها: «سجلي جرعة الدوا الساعة ٨» جرعة صيدلية مش ميعاد.
const APPOINTMENT_INTENT = /(فكر|ذكر|نبه)(ني|يني|نى)|ميعاد|موعد|مواعيد|اجتماع|مشوار/;
// «الساعة ٢ الظهر عاوز اصحى» — رد «ظبطتهالك وهصحيك» من غير أي أداة (zad_brain_runs ٢٠٢٦-٠٩-٣٠ ٠٢:٤٦).
// الصحيان تذكير بميعاد، بس ولا كلمة فيه كانت في APPOINTMENT_INTENT. «صحي» لوحدها مش منها: «أكل صحي».
const WAKE_INTENT = /صحي(ني|يني)|(^|\s)[اهح]صحي(\s|$)|(^|\s)منبه(\s|$)|صحيان/;
// ساعة أو مدة في الرسالة: «الساعة ٢ الظهر»، «٧ الصبح»، «كمان ١٠ دقايق».
const CLOCK_TIME = /الساعه\s*[0-9٠-٩]|[0-9٠-٩]{1,2}(:[0-9٠-٩]{2})?\s*(الصبح|الظهر|العصر|المغرب|بالليل|صباحا|مساء|ص|م)(\s|$)|كمان\s*[0-9٠-٩]+\s*(دقيقه|دقايق|د|ساعه|ساعات)/;
// الرد اللي قبلها كان بيسأل عن وقت تذكير: «عايز أصحيك الساعة كام بالظبط؟» — ساعتها الرد اللي بعده
// («الساعة ٢ الظهر») هو الطلب نفسه حتى لو مافيهوش ولا كلمة تذكير.
const ASKED_REMINDER_TIME = /(افكرك|اصحيك|انبهك|اسجلهولك|اسجله|اسجلها).{0,40}(الساعه كام|امتي|بالظبط|وقت)|(الساعه كام|امتي بالظبط).{0,40}(افكرك|اصحيك|انبهك)/;

function reminderIntent(norm: string, priorNorm: string): boolean {
  if (APPOINTMENT_INTENT.test(norm) || WAKE_INTENT.test(norm)) return true;
  return CLOCK_TIME.test(norm) && ASKED_REMINDER_TIME.test(priorNorm);
}
const PROFILE_INTENT = /اسمي|انا اسمي|بشتغل|شغلي|شغلتي|وظيفتي|بقبض|مرتبي|راتبي|قبضي|انا (ام|اب|ست|راجل|بنت|ولد|طالب|طالبه|متجوز|متجوزه|اعزب)|عندي\s*[0-9٠-٩]+\s*(عيال|ولاد|اطفال)|ساكن|ساكنه|عمري|عندي\s*[0-9٠-٩]+\s*سنه|مواليد/;

// سؤال عن سعر أو ترند حي — مكانه البحث على النت، مش أدوات التطبيق: «كم سعر الذهب اليوم»،
// «كام سعر زجاجة المياه في السعودية» (تليجرام ٢٠٢٦-١٠-٠١). مصروف العميل نفسه («صرفت كام»،
// «دفعت ٥٠») مش منها — دي فلوسه هو.
const WEB_PRICE_INTENT = /(كام|كم|بكام|بكم)\s*(سعر|تمن|ثمن)|سعر\s*\S+.*(النهارده|اليوم|دلوقتي|الحين)|(اسعار|أسعار)\s|ترند/;
const OWN_MONEY = /صرفت|دفعت|اشتريت|قبضت/;
// «سعر الدهب» من غير «النهارده» ماكانش بيعدّي WEB_PRICE_INTENT (٢٠٢٦-١٠-٠١ ٢٠:٠٥ تليجرام).
const GOLD_INTENT = /دهب|ذهب|عيار\s*(24|21|18|٢٤|٢١|١٨)/;
// سؤال عن حدث أو «آخر مرة»: معلومات الموديل قديمة. «مين كسب كاس العالم للأندية آخر مرة؟» اترد عليه
// «مانشستر سيتي ٢٠٢٣» من الذاكرة، والنسخة الأحدث (٢٠٢٥) كسبها تشيلسي (اختبار القبول، ٢٠٢٦-١٠-٠١).
const RECENT_FACT_INTENT = /(مين|من)\s*(اللي)?\s*(كسب|فاز|اخد|بطل)|(اخر|آخر)\s*(مره|نسخه|بطوله|ماتش|مباراه)|(اخبار|أخبار)|نتيجه\s*(ماتش|مباراه)|مين\s*(رئيس|وزير|مدرب)/;
const FX_INTENT = /(دولار|يورو|استرليني|ريال|درهم|دينار|ليره|ليرة)\s*(بكام|بكم|كام|كم|النهارده|اليوم|دلوقتي)|(بكام|بكم|كام|كم|سعر)\s*(ال)?(دولار|يورو|استرليني|ريال|درهم|دينار|ليره|ليرة)|سعر\s*(ال)?صرف/;

const MEMORY_INTENT = /افتكر|افتكري|خليك فاكر|خليكي فاكره|متنساش|متنسيش|احفظ|اعرف ان|خد بالك ان|خدي بالك ان/;
// نوايا الأدوات اللي خرجت من الأساسي (٢٠٢٦-١٠-٠٢). النص متطبّع (normalize): ة→ه، أ/إ/آ→ا، ى→ي.
const BROKE_INTENT = /مفلس|طفران|خلصت فلوسي|فلوسي خلصت|مفيش فلوس|معيش فلوس|معنديش فلوس|ماعنديش فلوس|مخلص فلوسي/;
const RECIPE_INTENT = /اطبخ|نطبخ|تطبخ|طبخه|وصفه|وصفات|(اعمل|نعمل|ناكل|اكل)\s*(اكل)?\s*ايه|(غدا|عشا|فطار|سحور)\s*(ايه|النهارده)|شيف/;
const NEARBY_INTENT = /اقرب|قريب مني|قريبه مني|جنبي|حواليا|فين الاقي|فين القي|محلات قريبه/;
// «عاوز اتواصل مع موظف» ماكانتش بتعدّي (٢٠٢٦-١٠-٠٢ ٠١:٢٥): الأداة ماتعرضتش والموديل قال «فتحت لك تيكت» من غير تيكت.
const SUPPORT_INTENT = /شكوي|اشتكي|اكلم حد|اكلم (موظف|مسؤول|انسان|بني ادم)|موظف|اتواصل|تواصل مع|الدعم|خدمه العملاء|التطبيق\s*(فيه مشكله|بايظ|واقف|مش شغال|بيقفل)|عطل في التطبيق|مشكله في (التطبيق|الصفحه|الشاشه)|بلاغ/;
// «خلصت كافة ادويتي شلها من الليستة» — الأداة موجودة والموديل قال «مش بعرف أشيلها» (٢٠٢٦-١٠-٠٢ ٠١:٢٧).
// حارس المستندات (الشريحة ٣٢). «جواز» لوحدها = زواج في المصري («جوازي»)، فلازم «سفر» أو كلام عن انتهاء/تجديد جنبها.
const DOCUMENT_TIME = "(نتهي|انتهت|خلصت|تجديد|اجدد|جددت|صلاحي|لحد)";
const DOCUMENT_INTENT = new RegExp(
  "جواز (ال)?سفر|باسبور|passport|" +
    `(جواز|البطاقه|بطاقتي|الرقم القومي|اقامه|اقامتي|الاقامه|رخصه|رخصتي|الرخصه).{0,30}${DOCUMENT_TIME}|` +
    `${DOCUMENT_TIME}.{0,20}(جواز|البطاقه|بطاقتي|اقامه|اقامتي|الاقامه|رخصه|رخصتي|الرخصه)`,
);
// كارت التسليم (الشريحة ٣٤): غياب عن البيت + حد هيمسك مكانه، أو طلب الكارت نفسه.
const HANDOVER_INTENT = /كارت تسليم|تسليم الشفت|تسليم البيت|(مسافر|هسافر|حسافر|مسافره|هغيب|مش هبقي موجود|مش هكون موجود).{0,40}(مراتي|جوزي|زوجي|زوجتي|البيت|الاولاد|العيال|ماما|بابا|اللي في البيت)/;
// نمط العزومة (الشريحة ٣٥).
const GATHERING_INTENT = /عزومه|عزايم|عازم|عازمين|هعزم|هنعزم|عزمت|ضيوف|جايين يتغدوا|جايين يتعشوا|جايلنا ناس|عندنا ناس جايين/;
// إيقاع النوم (الشريحة ٣٧): العميل بيقول مواعيد نومه، أو مايتبعتلوش حاجة في وقت.
const SLEEP_INTENT = /(بنام|بنامي|بانام|بصحي|بصحى|بقوم من النوم|مواعيد نومي).{0,30}(الساعه|[0-9٠-٩])|ماتبعتليش.{0,25}(قبل|بعد|بالليل|الصبح)|ماتصحينيش/;
const MEDICINE_EDIT_INTENT = /(شيل|شلها|شيلها|شيلهم|امسح|امسحها|امسحهم|احذف|احذفها|احذفهم|الغي|الغيها).{0,30}(دوا|دوه|ادوي|علاج|حبوب|اقراص|كريم|مرهم|صيدليه)|(دوا|دوه|ادوي|علاج|كورس).{0,40}(شيل|شلها|شيلها|امسح|احذف|من (الليسته|اللسته|القايمه))/;

/** [priorReply]: رد زاد اللي قبل الرسالة دي مباشرة، لو فيه — بيكمّل نية الرسالة لما تكون رد على سؤال. */
export function intentToolHints(message: string, priorReply = ""): string[] {
  const norm = normalize(message);
  const tools: string[] = [];
  if (reminderIntent(norm, normalize(priorReply))) tools.push("add_appointment", "update_appointment", "add_place_reminder");
  if (PROFILE_INTENT.test(norm)) tools.push("update_customer_profile", "remember");
  // «افتكر إني مش باكل تونة» — قياس ما بعد النشر: الموديل رد بكلام ومانداش remember.
  if (MEMORY_INTENT.test(norm) && !tools.includes("remember")) tools.push("remember", "update_customer_profile");
  if (GOLD_INTENT.test(norm) && !OWN_MONEY.test(norm)) tools.push("gold_price");
  else if (FX_INTENT.test(norm) && !OWN_MONEY.test(norm)) tools.push("fetch_current_exchange_rate");
  else if (WEB_PRICE_INTENT.test(norm) && !OWN_MONEY.test(norm)) tools.push("web_search");
  else if (RECENT_FACT_INTENT.test(norm)) tools.push("web_search");
  if (BROKE_INTENT.test(norm)) tools.push("set_broke_mode");
  if (RECIPE_INTENT.test(norm)) tools.push("suggest_recipes");
  if (NEARBY_INTENT.test(norm)) tools.push("find_nearby_stores");
  if (SUPPORT_INTENT.test(norm)) tools.push("open_support_ticket");
  if (MEDICINE_EDIT_INTENT.test(norm)) tools.push("delete_pharmacy_item", "update_pharmacy_item");
  if (DOCUMENT_INTENT.test(norm)) tools.push("save_document", "delete_document", "read_house");
  if (HANDOVER_INTENT.test(norm)) tools.push("handover_card");
  if (GATHERING_INTENT.test(norm)) tools.push("plan_gathering", "add_gathering_to_list", "add_appointment");
  if (SLEEP_INTENT.test(norm)) tools.push("set_sleep_window");
  return [...new Set(tools)];
}

// «جاهز، سُجلت! 👌» على «فكرني كمان ٥ د وبعدين كل ساعة» — ولا أداة اتنادت، ولا رفض (zad_brain_runs
// ٢٠٢٦-٠٩-١٥ ٠٤:٢٢). مراجعة الادعاءات في العقل بتشتغل بس لو فيه تنفيذ؛ اللفة اللي مفيهاش أي أداة كانت بتعدّي.
const REMINDER_DONE_CLAIM = /سجلت|سجلته|سجلتها|اتسجل|ظبطت|ظبطته|خليته يفكرك|خليته هيفكرك|هفكرك|هصحيك|هنبهك|حطيته|ضفته|ضفتلك/;

/** طلب تذكير واضح + رد بيقول إنه اتعمل، من غير أي أداة ⇒ الرد كذب ولازم يتصحح. */
export function unbackedReminderClaim(message: string, reply: string, priorReply = ""): boolean {
  return intentToolHints(message, priorReply).includes("add_appointment") && REMINDER_DONE_CLAIM.test(normalize(reply));
}

/**
 * رد زاد اللي قبل آخر رسالة للعميل في [history]. بيدوّر على آخر رسالة عميل الأول، لأن بعدها ممكن
 * يكون فيه نداءات أدوات ونتايجها من اللفة نفسها.
 */
export function priorAssistantText(history: ReadonlyArray<{ role: string; text?: string }>): string {
  let i = history.length - 1;
  while (i >= 0 && history[i].role !== "user") i--;
  for (i--; i >= 0; i--) {
    const turn = history[i];
    if (turn.role === "user") return "";
    if (turn.role === "assistant" && turn.text?.trim()) return turn.text;
  }
  return "";
}

/** نقاط كل وكيل لرسالة واحدة، بترتيب `ORDER` (general مش فيها لأنها مالهاش كلمات). */
function scoreAll(message: string): Array<{ id: SpecialistId; score: number }> {
  const norm = normalize(message);
  // نية ميعاد/تذكير واضحة بتكسب التعادل لوكيل العيلة: «فكّريني أروح البنك» ميعاد، مش عملية فلوس.
  const appointmentBonus = APPOINTMENT_INTENT.test(norm) || WAKE_INTENT.test(norm) ? 1 : 0;
  return ORDER.map((id) => ({
    id,
    score: SPECIALISTS[id].keywords.reduce(
      (acc, kw) => acc + (norm.includes(normalize(kw)) ? 1 : 0),
      0,
    ) + (id === "family" ? appointmentBonus : 0),
  }));
}

/**
 * تصنيف deterministic. أول وكيل بيجمع أكتر نقاط كلمات مفتاحية بيكسب — العدّ مهم
 * لأن رسالة واحدة ممكن تمس مجالات (لو كلمة واحدة فقط اتطابقت بنقطة واحدة والباقي
 * صفر، برضه بيكسب). مفيش تطابق خالص = general.
 */
export function routeSpecialist(message: string): SpecialistId {
  let best: SpecialistId = "general";
  let bestScore = 0;
  for (const { id, score } of scoreAll(message)) {
    if (score > bestScore) {
      bestScore = score;
      best = id;
    }
  }
  return best;
}

/**
 * بند 31.6 — متخصص أساسي + استشاري تانٍ. رسالة زي "أطبخ إيه بـ٥٠ جنيه؟" بتمس مطبخ
 * *و* فلوس مع بعض؛ اختيار وكيل واحد بيخلي الرد ناقص نص السؤال. الاستشاري هو ثاني
 * أعلى نقاط **من غير general ومن غير الأساسي نفسه**، وبس لو نقطته > 0 (تطابق كلمة
 * حقيقية على الأقل، مش تخمين). general مالهاش استشاري — مفيش هوية أساسية توجّه منها.
 */
export function routeSpecialists(
  message: string,
): { primary: SpecialistId; secondary: SpecialistId | null } {
  const ranked = scoreAll(message).sort((a, b) => b.score - a.score);
  const primary = ranked[0]?.score > 0 ? ranked[0].id : "general";
  if (primary === "general") return { primary, secondary: null };
  const runnerUp = ranked.find((r) => r.id !== primary && r.score > 0);
  return { primary, secondary: runnerUp ? runnerUp.id : null };
}

/** وصف نطاق كل وكيل — مستخدم في هوية الوكيل الأساسي *وفي* سطر الاستشاري (31.6). */
const SPECIALIST_SCOPE_AR: Record<Exclude<SpecialistId, "general">, string> = {
  finance:
    "المعاملات، الرصيد، الالتزامات، الاشتراكات، الديون، دورة الراتب. أدوات الفلوس بتعرض تأكيد قبل الكتابة.",
  pantry:
    "المخزون، قائمة الشراء، الصلاحيات، اقتراح وجبات من الموجود فعلاً في المخزون بس — ماتقترحش صنف مش موجود.",
  pharmacy:
    "أدوات الصيدلية والجرعات. أوقات الجرعات لازم تكون ضمن ٢٤ ساعة وبصيغة HH:mm — دي قاعدة تحقق صارمة، لو الوقت مش مفهوم اسأل بدل ما تخمّن.",
  family:
    "المهام والمواعيد والتذكيرات، وكمان نمط استهلاك الأسرة ككل (تقرير سلوك، هدر، مقارنة بين الأفراد) عبر family_digest — مش تسجيل صرفة فردية، ده نطاق وكيل المال. المهمة محتاجة عنوان واضح، ولو التاريخ/الوقت مش محدد اسأل.",
  home:
    "فواتير البيت ومتابعة سدادها (تنبيه واستفسار بس — مفيش تسجيل فلوس من هنا)، الأجهزة والضمانات والصيانة الدورية، وأعطال المنزل. تقدر تفتح شاشة الصيانة للعميل بـ app_command.",
};

/**
 * سطر هوية الوكيل اللي بيتحقن في برومبت المحادثة. general = null (البرومبت زي ما هو).
 *
 * بند 31.6 — لو فيه استشاري (secondary)، بيتضاف سطر تحت هوية الأساسي بدل ما الموديل
 * يقتصر على نطاق واحد. الاستشاري **مش** هوية تانية بيتلبسها — هو معلومة إضافية
 * الأساسي مسموح له يستخدمها من غير ما يحوّل شخصيته الكاملة له.
 */
export function specialistPromptBlock(
  id: SpecialistId,
  secondary?: SpecialistId | null,
): string | null {
  if (id === "general") return null;
  const s = SPECIALISTS[id];
  const consultLine = secondary
    ? `\nاستشارة إضافية متاحة (نطاق ${SPECIALISTS[secondary].nameAr}): ${SPECIALIST_SCOPE_AR[secondary as Exclude<SpecialistId, "general">]} استخدم أدوات النطاق ده لو السؤال محتاجها فعلاً، من غير ما تحوّل هويتك الكاملة له.`
    : "";
  return `=== الوكيل المتخصص ===
انت دلوقتي ${s.nameAr} داخل نظام زاد — الجزء المتخصص اللي العقل العام حوّل له الرسالة دي.
- نطاقك: ${SPECIALIST_SCOPE_AR[id as Exclude<SpecialistId, "general">]}
برا نطاقك: جاوب باقتضاب واعرض إنك تحوّل الموضوع للوكيل المناسب بمجرد ما العميل يكمله — متتعمقش فيه.${consultLine}
=== نهاية الوكيل ===`;
}

/**
 * Trace دائم: specialist بيتكتب في صف zad_brain_runs بتاع اللفة. الفشل هنا مابيرميش —
 * التتبع تحسين، مش مسار حرج. `specialist_secondary` (31.6) نفس المنطق، عمود منفصل
 * nullable — general مالهاش استشاري فمش بيتكتب أصلاً.
 */
export async function recordSpecialistTrace(
  sb: SupabaseClient,
  runId: string | null | undefined,
  specialist: SpecialistId,
  secondary?: SpecialistId | null,
): Promise<void> {
  if (!runId || specialist === "general") return;
  try {
    await sb.from("zad_brain_runs")
      .update({ specialist, specialist_secondary: secondary ?? null })
      .eq("id", runId);
  } catch (e) {
    console.error("specialist trace failed:", e);
  }
}

/** خرائط أدوات كل وكيل — مستخدمة في الأساسي *وفي* اتحاد أدوات الاستشاري (31.6). */
const SPECIALIST_TOOL_SCOPE: Record<Exclude<SpecialistId, "general">, string[]> = {
  finance: [
    "log_transaction", "allocate_income", "update_transaction", "delete_transaction",
    "set_monthly_limit", "add_debt", "update_debt", "delete_debt",
    "add_obligation", "update_obligation", "delete_obligation",
    "add_subscription", "update_subscription", "delete_subscription",
    "forward_ledger", "check_price_online", "query_family", "weekly_savings_plan",
    "home_health_score", "propose_next_month_budget", "decision_impact", "log_decision", "household_resilience",
    "confirm_life_shift",
  ],
  pantry: [
    "add_inventory_item", "update_inventory_qty", "delete_inventory_item",
    "add_shopping_item", "complete_shopping_item", "delete_shopping_item",
    "suggest_product", "check_price_online", "find_nearby_stores", "web_search",
    "suggest_recipes", "area_trends", "plan_gathering", "add_gathering_to_list",
  ],
  pharmacy: [
    "add_pharmacy_item", "update_pharmacy_item", "delete_pharmacy_item",
    "log_pharmacy_dose", "find_nearby_stores", "web_search", "emergency_card",
    "set_life_circumstance", "end_life_circumstance",
  ],
  family: [
    "schedule_task", "query_family", "family_digest", "family_mediation", "emergency_card", "start_family_poll", "handover_card",
    "set_life_circumstance", "end_life_circumstance",
  ],
  home: [
    "app_command",
    "add_maintenance_item", "update_maintenance_item", "delete_maintenance_item",
    "save_document", "delete_document",
    "add_obligation", "update_obligation", "delete_obligation",
    "forward_ledger", "web_search", "home_health_score", "decision_impact", "log_decision",
    "set_life_circumstance", "end_life_circumstance",
  ],
};

/**
 * تقليل الأدوات المعروضة حسب الوكيل — سر سرعة الردود:
 * 39 أداة في كل طلب بتخلي الموديل يقرا أوصاف ضخمة ويتردد بين بدائل كتير قبل
 * ما يختار. لما نعرض بس أدوات نطاق الوكيل + الأدوات العامة، القرار بيبقى أسرع
 * وأدق. لو الرسالة عامة (general)، كل الأدوات متاحة زي ما هي — مفيش تغيير سلوك.
 *
 * بند 31.6 — لو فيه استشاري، أدواته بتتضاف لقايمة الأساسي (اتحاد مش استبدال):
 * "أطبخ إيه بـ٥٠ جنيه؟" (مطبخ أساسي، فلوس استشاري) لازم يقدر يستخدم check_price_online
 * *و* يشوف الميزانية من غير ما يفقد أدوات المخزون.
 */
/**
 * الأدوات اللي الرسالة العامة بتاخدها (تحية، سؤال، طلب سريع). قبل كده الرسالة العامة كانت
 * بتاخد الـ٦١ أداة كلها: ٣٣ ألف حرف تعريفات أدوات مع «مرحبا» — نص حمل كل رسالة (اختبار
 * القبول، ٢٠٢٦-١٠-٠١). الأداة اللي نية الرسالة بتشاور عليها بتنضاف فوقهم (extra).
 */
export const GENERAL_CORE_TOOLS: readonly string[] = [
  "read_house", "remember", "update_customer_profile", "web_search",
  "app_command", "add_appointment", "update_appointment",
  "log_transaction", "add_shopping_item", "add_inventory_item", "update_inventory_qty", "add_pharmacy_item",
  "log_pharmacy_dose",
];
// برّه الأساسي من ٢٠٢٦-١٠-٠٢ (تشخيص زاد ٢.١): الدهب، العملات، تذكير المكان، الشكوى، وضع الطوارئ،
// الشيف، المحلات القريبة — ٧ أدوات (~٣ آلاف حرف) كانت بتتبعت مع كل «مرحبا». بتيجي بنية الرسالة
// (intentToolHints) أو بالوكيل المتخصص، وقواعدها في البرومبت معاها (buildChatSystemPrompt).

export function scopeToolsForSpecialist<T extends { name: string }>(
  tools: T[],
  specialist: SpecialistId,
  secondary?: SpecialistId | null,
  extra: readonly string[] = [],
): T[] {
  if (specialist === "general") {
    const core = new Set([...GENERAL_CORE_TOOLS, ...extra]);
    return tools.filter((t) => core.has(t.name));
  }
  const allowed = new Set([
    ...(SPECIALIST_TOOL_SCOPE[specialist as Exclude<SpecialistId, "general">] ?? []),
    ...(secondary ? SPECIALIST_TOOL_SCOPE[secondary as Exclude<SpecialistId, "general">] ?? [] : []),
    // الأدوات العابرة للنطاقات — متاحة دايمًا
    "remember", "link_memory", "web_search", "set_market", "set_transaction_category",
    // أسعار النهارده: الدهب والعملات بيتسألوا في أي سياق، ومن غيرهم الموديل بيقول «مش لاقي».
    "gold_price", "fetch_current_exchange_rate",
    // الشكوى بتتقال في أي موضوع.
    "open_support_ticket",
    "update_emergency_fund_balance", "add_maintenance_item", "update_maintenance_item",
    "delete_maintenance_item", "app_command", "learn_skill", "home_health_score",
    // المواعيد عابرة للنطاقات: «ميعاد» بيتوجّه لوكيل العيلة، «دكتور» للصيدلية، «اجتماع بنك»
    // للمال — لو كانت في نطاق واحد، التذكير كان هيختفي في باقي الحالات.
    "add_appointment", "update_appointment",
    "add_place_reminder", "cancel_place_reminder",
    // «أنا مفلس» ممكن تتقال في أي سياق (أكل، شراء، فلوس) — لو في نطاق واحد كانت هتضيع.
    "set_broke_mode",
    "start_savings_challenge", "stop_savings_challenge",
    // العميل ممكن يقول عن نفسه حاجة في أي موضوع.
    "update_customer_profile",
    // بيانات البيت التقيلة (الحركات، صفوف المخزون…) بتتقري عند الحاجة، مش بتتبعت مع كل رسالة.
    "read_house",
    ...extra,
  ]);
  return tools.filter((t) => allowed.has(t.name));
}

// ── الرد اللي بيتهرب من التنفيذ ──────────────────────────────────────────────────────────────
// «أنا مش بعرف أشيل الأدوية بنفسي، ادخل على صفحة الصيدلية» و«فتحت لك تيكت» من غير ما أداة تتنادى:
// ده موديل الأداة ماكانتش معروضة عليه في اللفة دي (٢٠٢٦-١٠-٠٢). الرد ده مايوصلش للعميل — اللفة
// بتتعاد مرة بكل الأدوات (callAgentModel). الكلمات متطبّعة (normalize).
const DEFLECTS = /(مش بعرف|مبعرفش|مقدرش|ماقدرش|مش هقدر|مش قادر|ماعنديش صلاحي|مش من صلاحياتي|مش متاح ليا).{0,40}(اشيل|امسح|احذف|اعدل|اغير|اضيف|افتح|اسجل|الغي|انفذ)|ادخل (علي|على) (صفحه|شاشه)|(من|في) (صفحه|شاشه) .{0,30}(في|جوه) التطبيق/;
const CLAIMS_DONE = /(فتحت|فتحتلك|فتحت لك|سجلت|رفعت|بعت|بعتت|مسحت|شلت|حذفت|الغيت|ضفت|سجلتلك).{0,20}(تيكت|تيكيت|تذكره|شكوي|بلاغ|الدوا|الادويه|الميعاد|التذكير|المصروف|الصنف)/;

/** رد من غير أداة بيوجّه العميل لشاشة، أو بيدّعي تنفيذ ماحصلش ⇒ يتعاد بكل الأدوات. */
export function shouldWidenTools(reply: string): boolean {
  const norm = normalize(reply);
  return DEFLECTS.test(norm) || CLAIMS_DONE.test(norm);
}
