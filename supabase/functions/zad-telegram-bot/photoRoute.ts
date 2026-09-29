// وين تروح صورة اتبعتت على تليجرام — دالة نقية، الاستعمال في index.ts (message:photo).
//
// قبل ٢٠٢٦-٠٩-٢٧ كان أي نوع غير الصيدلية وكارت الرصيد بيتعامل كفاتورة بقالة، فأصناف فاتورة
// مطعم أو بنزينة أو خدمة (receiptType = "general") كانت بتتضاف للمخزون: «2 شاورما» في
// التلاجة و«بنزين 92» صنف في البيت. والكابشن اللي العميل بيكتبه مع الصورة («دي روشتة»،
// «فاتورة المطعم») كان بيتجاهل خالص.
//
// القاعدة: الكابشن كلام العميل عن صورته — لو قال صراحة نوعها، ده اللي بيمشي. غير كده نوع
// القارئ. ومفيش أصناف بتدخل المخزون غير من فاتورة بقالة.

/** اللي هيحصل للصورة. */
export type PhotoRoute =
  /** كارت رصيد/راتب — مفيش أصناف ولا مصروف، بس توضيح. */
  | "budget_card"
  /** الأصناف للصيدلية، والإجمالي مصروف رعاية صحية يستنى التأكيد. */
  | "pharmacy"
  /** الأصناف للمخزون، والإجمالي مصروف يستنى التأكيد. */
  | "grocery"
  /** مطعم/بنزين/خدمة/فاتورة: الإجمالي مصروف يستنى التأكيد، ومفيش أصناف للمخزون. */
  | "expense_only";

// ⚠️ بيانات مطابقة مع كلام العميل — ماتترجمهاش (CLAUDE.md، قاعدة i18n).
const PHARMACY_WORDS = /روشت|دوا|دواء|أدوية|ادوية|علاج|صيدلي|حبوب|برشام|reçete|ilaç|eczane|pharmacy|medicine|prescription/i;
const EXPENSE_WORDS = /مطعم|كافيه|قهوة|أكل برا|اكل برا|دليفري|توصيل|بنزين|وقود|بنزينة|فاتورة (كهربا|كهرباء|مية|مياه|غاز|نت|انترنت|تليفون)|restaurant|cafe|fuel|petrol|restoran|benzin/i;
const GROCERY_WORDS = /مقاضي|بقالة|سوبر ?ماركت|هايبر|خضار|تموين|مخزون|تلاجة|تلاجه|market|grocery|bakkal/i;

/** نوع الصورة من كلام العميل، أو null لو الكابشن مابيقولش. */
export function captionIntent(caption: string | null | undefined): PhotoRoute | null {
  const c = (caption ?? "").trim();
  if (!c) return null;
  if (PHARMACY_WORDS.test(c)) return "pharmacy";
  if (EXPENSE_WORDS.test(c)) return "expense_only";
  if (GROCERY_WORDS.test(c)) return "grocery";
  return null;
}

/** المسار النهائي: كارت الرصيد مابيتغيّرش بكابشن، وبعده كلام العميل، وبعده نوع القارئ. */
export function routePhoto(receiptType: string | null | undefined, caption: string | null | undefined): PhotoRoute {
  if (receiptType === "budget_card") return "budget_card";
  const said = captionIntent(caption);
  if (said) return said;
  switch (receiptType) {
    case "pharmacy":
      return "pharmacy";
    case "grocery":
      return "grocery";
    default:
      // "general" وأي قيمة مش معروفة: مصروف بس. صنف مش بقالة في المخزون أسوأ من صنف ناقص.
      return "expense_only";
  }
}
