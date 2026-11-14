// forcedConsume.ts — «فتحنا علبة لبن» والموديل رد «خصمت علبة» من غير ما ينادي consume_item.
//
// فحص ١٤/١١ على الإنتاج (حساب تجربة): ١ من ٤ محاولات الموديل (gemini-3.5-flash-lite) ادّعى الخصم والمخزون
// ماتغيّرش. نفس شكل forcedLog.ts: فعل استهلاك صريح، ومش سؤال، ومفيش كتابة على المخزن في اللفة ⇒ محاولة واحدة
// بأداة consume_item بس وإجبار النداء. الرد بيتبدل **بس** لو الكتابة حصلت فعلاً — «فتحت الباب» هتطلع
// «مش في المخزون» ومش هتغيّر حاجة.

const normalize = (text: string) =>
  text.replace(/[ً-ٰٟـ]/g, "").replace(/[أإآ]/g, "ا").replace(/ى/g, "ي").replace(/ة/g, "ه").toLowerCase();

/** نفس أفعال CONSUME_INTENT في specialists.ts. */
const CONSUME_VERB =
  /(^|\s)(شربنا|شربت|شربوا|اكلنا|اكلت|اكلوا|كلنا|طبخنا|طبخت|استعملنا|استعملت|استخدمنا|استخدمت|استهلكنا|فتحنا|فتحت)(\s|$)/;
/** سؤال أو نية مش حاجة حصلت: «نطبخ ايه؟»، «اكلت ايه امبارح؟»، «هل اللبن المفتوح يبوظ؟». */
const QUESTION = /[؟?]|(^|\s)(ازاي|ايه|هل|كام|كم|امتي|فين|ليه|ينفع|اعمل|نعمل|ناكل|نطبخ|نشرب)(\s|$)/;
/** أكل برّه مش من المخزن: «اكلنا برا»، «اتغدينا في مطعم». */
const OUTSIDE = /(برا|بره|مطعم|كافيه|ديليفري|دليفري|طلبنا|اوردر)/;

/** أدوات بتكتب في مخزن البيت — لو واحدة فيهم اتنفذت، الموديل عمل شغله. */
const PANTRY_WRITES = new Set(["consume_item", "update_inventory_qty", "add_inventory_item", "delete_inventory_item"]);

export function wantsForcedConsume(message: string): boolean {
  const m = normalize(message ?? "").trim();
  if (!m || m.length > 160) return false;
  return CONSUME_VERB.test(m) && !QUESTION.test(m) && !OUTSIDE.test(m);
}

/** بعد اللفة: مفيش اقتراح ولا كتابة على المخزن، والرسالة استهلاك صريح. */
export function shouldForceConsume(message: string, executedTools: readonly string[], proposals: number): boolean {
  return proposals === 0 && !executedTools.some((t) => PANTRY_WRITES.has(t)) && wantsForcedConsume(message);
}
