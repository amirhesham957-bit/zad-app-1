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

/**
 * الصنف اللي الموديل اختاره تحت الإجبار لازم يكون في كلام العميل. فحص ١٤/١١ بعد النشر: «شربنا علبة عصير» ومفيش
 * عصير في المخزن، فالموديل المجبور اختار «لبن» (الصنف الوحيد) واتخصم. كلمة واحدة من اسم الصنف (من غير «ال»)
 * موجودة في الرسالة تكفي: «لبن لتر» ⇐ «فتحنا علبة لبن».
 */
export function itemSaidInMessage(item: string, message: string): boolean {
  const words = (t: string) =>
    normalize(t ?? "").split(/[^\p{L}\p{N}]+/u).map((w) => w.replace(/^(بال|وال|لل|ال)/, "")).filter((w) => w.length >= 2);
  const said = new Set(words(message));
  return words(item).some((w) => said.has(w));
}

/** بعد اللفة: مفيش اقتراح ولا كتابة على المخزن، والرسالة استهلاك صريح. */
export function shouldForceConsume(message: string, executedTools: readonly string[], proposals: number): boolean {
  return proposals === 0 && !executedTools.some((t) => PANTRY_WRITES.has(t)) && wantsForcedConsume(message);
}
