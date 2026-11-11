// معدل الاستهلاك (zad_consumption) زي ما العقل وتليجرام بيقروه — نفس قواعد SQL.
//
// الفجوة ٧ (20260930000000): معدل من دورة شرا واحدة بيتخزن rate_known = false و
// avg_daily_qty > 0. قبل كده الاتنين كانوا بيتجاهلوه لحد ٣ نزلات، والتعلّم كان
// بياخد شهور.

export type RateConfidence = "known" | "approximate" | "unknown";

/** known = ٣ نزلات على يومين · approximate = دورة أو اتنين · unknown = مفيش معدل. */
export function rateConfidence(avgDailyQty: number | null | undefined, rateKnown: boolean | null | undefined): RateConfidence {
  const hasRate = Number(avgDailyQty) > 0;
  if (!hasRate) return "unknown";
  return rateKnown ? "known" : "approximate";
}

/**
 * يستاهل سؤال «لسه موجود ولا خلص؟»: تحت حد العميل (٢ لو مش محطوط)، أو هيخلص خلال
 * يومين بأي معدل — المؤكد أو التقريبي، لأن السؤال نفسه هو التأكيد. نفس
 * `_inventory_needs_checkin` في SQL.
 */
export function needsCheckIn(
  quantity: number,
  threshold: number | null | undefined,
  avgDailyQty: number | null | undefined,
  createdAt?: string | null,
  now: number = Date.now(),
): boolean {
  // اللي كميته صفر خلص فعلاً — مكانه قايمة الشرا، مش «لسه عندك؟». المالك ١/١١: «بيسألني على حاجات
  // خلصانة من شهرين» — مياه نستله اتسألت ٣ مرات وهي صفر.
  if (!(quantity > 0)) return false;
  // المالك ٤/١١: لما معدل البيت معروف هو اللي بيحكم (يومين أو أقل)، مش الحد الثابت — لبن اتضاف بـ١٫٥
  // كان بيتسأل عنه من أول دقيقة. ومن غير معدل: الحد، بس مش على صنف اتضاف في آخر ٢٤ ساعة — العميل لسه
  // قايل عنده كام. نفس قاعدة الموبايل (shortage.dart) و_inventory_needs_checkin.
  const rate = Number(avgDailyQty);
  if (rate > 0) return quantity / rate <= 2;
  if (createdAt && now - Date.parse(createdAt) < 24 * 3600_000) return false;
  return quantity <= (threshold ?? 2);
}

/**
 * كام يوم الوحدة بتعيش عادة في بيت قبل ما يستاهل نسأل «لسه عندك؟»، لما مفيش معدل للبيت لسه. المقاس
 * (١١/١١، حساب المالك): القاعدة القديمة «الكمية ≤ ٢» سألت ٨ مرات في أسبوع عن حلاوة ومسحوق غسيل ورول أون
 * وسمن (كلهم كميتهم ١ وبيعيشوا أسابيع) ومسألتش ولا مرة عن لبن أو خضار أو عيش — فالأسئلة اتسابت، ومفيش
 * ولا نزلة اتسجلت، و`zad_consumption` فضل فاضي. الفئات دي هي اللي بيكتبها الماسح والتطبيق.
 * null = مابيتسألش عنه من غير معدل (شنط، حاجات مش بتتاكل ولا بتخلص).
 */
export const CATEGORY_CYCLE_DAYS: Record<string, number | null> = {
  "الألبان": 3,
  "الخضار": 4,
  "الفواكه": 4,
  "اللحوم": 4,
  "المشروبات": 5,
  "البقالة": 14,
  "العناية": 30,
  "أخرى": null,
};

/** فئة مش في الجدول (أو فاضية). */
const DEFAULT_CYCLE_DAYS = 10;

/**
 * الاسم بيغلب الفئة: الماسح بيحط التوست والجبنة واللانشون تحت «البقالة» (١٤ يوم) وهما بيخلصوا في أيام.
 * أول قاعدة تطابق هي اللي بتحكم.
 */
const NAME_CYCLE_DAYS: ReadonlyArray<[RegExp, number | null]> = [
  [/شنط|كيس|أكياس|اكياس/, null],
  [/عيش|خبز|توست|فينو|صمون/, 3],
  [/حليب|لبن|زبادي|رايب/, 3],
  [/جبن|لانشون|بسطرمة|مرتديلا|بيض/, 5],
  [/مياه|مية|ماء/, 4],
];

/**
 * أولوية سؤال «لسه عندك؟» لصنف واحد: ≥ ١ = يستاهل يتسأل الليلة، وكل ما تكبر يتسأل الأول. null = مايتسألش.
 *  • بمعدل البيت: الأيام اللي فاضلة للصنف؛ يومين أو أقل = ١ فأكتر (نفس قاعدة needsCheckIn).
 *  • من غير معدل: الأيام من آخر مرة الصنف اتشاف (شرا، رد، تعديل) ÷ عمر الفئة. لبن من ٣ أيام = ١، حلاوة
 *    من ٦ أيام = ٠٫٤.
 * [lastSeenAt] آخر قراية للصنف (zad_inventory_observations)، وإلا تاريخ إضافته.
 */
export function checkInPriority(
  name: string,
  quantity: number,
  category: string | null | undefined,
  avgDailyQty: number | null | undefined,
  lastSeenAt: string | null | undefined,
  now: number = Date.now(),
): number | null {
  if (!(quantity > 0)) return null;
  const rate = Number(avgDailyQty);
  if (rate > 0) {
    const daysLeft = quantity / rate;
    return 2 / Math.max(daysLeft, 0.1);
  }
  const seen = lastSeenAt ? Date.parse(lastSeenAt) : NaN;
  if (!Number.isFinite(seen)) return null;
  const ageDays = (now - seen) / 86_400_000;
  if (ageDays < 1) return null;
  const byName = NAME_CYCLE_DAYS.find(([re]) => re.test(name));
  const key = (category ?? "").trim();
  const cycle = byName ? byName[1] : key in CATEGORY_CYCLE_DAYS ? CATEGORY_CYCLE_DAYS[key] : DEFAULT_CYCLE_DAYS;
  if (cycle == null) return null;
  return ageDays / cycle;
}
