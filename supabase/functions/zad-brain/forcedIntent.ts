// forcedIntent.ts — «فكرني بكرة الساعة 9 الصبح اكلم الدكتور» والموديل رد «سويت لك تذكير» من غير أداة (ZAD_PLAN ٣.٣).
//
// التقييم ٢٥/١٠–٢/١١: log_reminder وdia_gulf_reminder فشلوا كل ليلة، وlog_appointment_relative وdia_saudi_reminder
// أغلب الليالي — وكيل العيلة (gemini-3.5-flash-lite) ردّ بكلام في اللفة الأولى وفي إعادة النية بأدوات المواعيد بس
// (callAgentModel مش بيجبر النداء)، فحارس unbackedReminderClaim بدّل الرد بـ«لسه ماسجلتش». الإعادة الإجبارية هنا
// زي forcedLog.ts: تذكير جديد صريح (كلمة تذكير أو ميعاد + وقت أو يوم)، مش سؤال ولا تعديل ولا مسح ⇒ محاولة واحدة
// بأداة add_appointment بس والنداء إجباري. الأداة نفسها بتتحقق من الوقت (validateTool) زي أي نداء.

const normalize = (text: string) =>
  text.replace(/[ً-ٰٟـ]/g, "").replace(/[أإآ]/g, "ا").replace(/ى/g, "ي").replace(/ة/g, "ه")
    .replace(/چ/g, "ج").toLowerCase();

/** طلب تذكير أو ميعاد جديد. */
const NEW_REMINDER = /(فكر|ذكر|نبه|صحي)(ني|يني|نى)|عندي (ميعاد|موعد|اجتماع|مشوار)|\bremind me\b/;
/** وقت أو يوم: «الساعة ٩»، «٧ الصبح»، «بكرة»، «باجر»، «الخميس»، «بعد ساعتين». */
const WHEN = /الساعه\s*[0-9٠-٩]|[0-9٠-٩]{1,2}(:[0-9٠-٩]{2})?\s*(الصبح|الظهر|العصر|المغرب|بالليل|صباحا|مساء|ص|م)(\s|$)|(^|\s)(بكره|بكرا|باكر|باجر|بعد بكره|النهارده|اليوم|الليله|السبت|الحد|الاحد|الاتنين|الاثنين|التلات|الثلاثاء|الاربع|الاربعاء|الخميس|الجمعه)(\s|$)|(بعد|كمان)\s*([0-9٠-٩]+|ساعه|ساعتين|نص ساعه|ربع ساعه)|\b(tomorrow|tonight|at \d)/;
/** سؤال، أو تعديل/إلغاء ميعاد موجود — مكانه find/update/delete مش add. */
const NOT_NEW = /[؟?]|(^|\s)(امتي|امتى|ايه|كام|هل|فين)(\s|$)|الغي|امسح|احذف|شيل|اجل|غير|عدل|بدل|خليه|خليها|كنسل/;

/** اللفة دي تستاهل محاولة إجبار add_appointment؟ */
export function wantsForcedReminder(message: string): boolean {
  const m = normalize(message ?? "").trim();
  if (!m || m.length > 160 || NOT_NEW.test(m)) return false;
  return NEW_REMINDER.test(m) && WHEN.test(m);
}

/** «ضيف شراب كحة لبنتي في الصيدلية»، «زود عيش ع اللسته» (التقييم ٢/١١): نفس النمط — الوكيل ادّعى الإضافة من غير أداة. */
const ADD_REQUEST = /(^|\s)(ضيف|ضف|اضف|اضيف|زود|حط|سجل)(\s|$)/;

/** الأدوات اللي بتتجبر، والرد لو اتنفذت — الإيصال (✅) تحته بيقول اللي اتسجل بالظبط. */
export const FORCED_REPLIES = {
  add_appointment: "تمام 👌 هفكّرك في وقته.",
  add_pharmacy_item: "تمام 👌 ضفته.",
  add_shopping_item: "تمام 👌 ضفته للقايمة.",
} as const;
export type ForcedTool = keyof typeof FORCED_REPLIES;

/**
 * الأداة اللي تتجبر لو اللفة خلصت من غير ولا كتابة، أو null. [hints] = intentToolHints للرسالة: الصيدلية والقايمة
 * بييجوا منها (MEDICINE_ADD_INTENT / SHOPPING_ADD_INTENT)، بشرط طلب إضافة صريح ومش سؤال ولا مسح.
 */
export function forcedIntentTool(message: string, hints: readonly string[]): ForcedTool | null {
  if (wantsForcedReminder(message)) return "add_appointment";
  const m = normalize(message ?? "").trim();
  if (!m || m.length > 160 || NOT_NEW.test(m) || !ADD_REQUEST.test(m)) return null;
  if (hints.includes("add_pharmacy_item")) return "add_pharmacy_item";
  if (hints.includes("add_shopping_item")) return "add_shopping_item";
  return null;
}
