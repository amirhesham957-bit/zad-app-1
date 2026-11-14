import { cycleDays, dueAfterDays, isEssential, priorCycleDays } from "./restockCycle.ts";
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
 * أولوية سؤال «لسه عندك؟» لصنف واحد: ≥ ١ = يستاهل يتسأل الليلة، وكل ما تكبر يتسأل الأول. null = مايتسألش.
 *  • بمعدل البيت (zad_consumption): الأيام اللي فاضلة؛ يومين أو أقل = ١ فأكتر (نفس needsCheckIn).
 *  • من غير معدل، بالمعدل المبدئي لو السيرفر عنده رقم للصنف ([prior]): الأيام الباقية بنفس الحساب.
 *  • غير كده: دورة شرا الصنف في البيت ده (`restockCycle.ts`: البداية من نوعه، وبعدين وسيط المسافات بين مرات
 *    شراه، وتصحيح العميل لو قاله) — الأيام من آخر شرا ÷ dueAfterDays(الدورة)، نفس اللحظة اللي الحلم بيحطه فيها في
 *    قايمة الشرا. لبن البيت بيشتريه كل ٣ أيام = ١ بعد يومين ونص؛ حلاوة كل ٣٠ يوم = ٠٫٢ بعد ٦ أيام.
 * المقاس (١١/١١، حساب المالك): القاعدة القديمة «الكمية ≤ ٢» سألت ٨ مرات في أسبوع عن حلاوة ومسحوق ورول أون وسمن،
 * ولا مرة عن اللبن — مع إن الملف السلوكي كان عارف إن دورة اللبن ٣ أيام وإن عليه الدور.
 */
export function checkInPriority(
  item: { name: string; quantity: number; category?: string | null; restockMode?: string | null; cycleOverride?: number | string | null },
  avgDailyQty: number | null | undefined,
  purchaseDays: readonly string[],
  now: number = Date.now(),
  prior?: { daysLeft: number | string | null; held: boolean } | null,
  openedLeft?: number | null,
): number | null {
  if (!(item.quantity > 0)) return null;
  // مفتوح (20261114220000): اللي فاضل من عمره بعد الفتح بيقدّم السؤال لو أقرب من أي حساب تاني.
  const base = baseCheckInPriority(item, avgDailyQty, purchaseDays, now, prior);
  if (prior?.held) return base; // «لسه» من أقل من ٣ أيام بيسكّت الصنف، مفتوح أو لأ.
  if (openedLeft == null || !Number.isFinite(openedLeft) || openedLeft < 0) return base;
  const byOpen = 2 / Math.max(openedLeft, 0.1);
  return base == null ? byOpen : Math.max(base, byOpen);
}

/** «لسه عندك؟» من غير حساب الفتح. */
function baseCheckInPriority(
  item: { name: string; quantity: number; category?: string | null; restockMode?: string | null; cycleOverride?: number | string | null },
  avgDailyQty: number | null | undefined,
  purchaseDays: readonly string[],
  now: number,
  prior?: { daysLeft: number | string | null; held: boolean } | null,
): number | null {
  const rate = Number(avgDailyQty);
  if (rate > 0) return 2 / Math.max(item.quantity / rate, 0.1);
  if (item.restockMode === "occasional") return null;
  // المعدل المبدئي (zad_pantry_prior_days_for، 20261114200000): استهلاك الفرد × أفراد البيت ÷ العبوة، من آخر
  // قراية. السيرفر مابيرجّعهوش لصنف ليه عادة شرا (٣ أيام شرا أو أكتر) — دي بتفضل للدورة تحت. «لسه» في آخر ٣ أيام
  // = مايتسألش.
  if (prior) {
    if (prior.held) return null;
    const left = Number(prior.daysLeft);
    if (Number.isFinite(left) && left >= 0) return 2 / Math.max(left, 0.1);
  }
  const override = Number(item.cycleOverride);
  const cycle = Number.isInteger(override) && override >= 1 && override <= 365
    ? override
    : cycleDays(priorCycleDays(item.name, item.category), purchaseDays);
  if (cycle === null) return null;
  const last = purchaseDays.reduce((m, d) => Math.max(m, Date.parse(d) || 0), 0);
  if (last <= 0) return null;
  const since = (now - last) / 86_400_000;
  if (since < 1) return null;
  // الأساسي (#482) بيتسأل عنه بدري، في نفس اللحظة اللي بيدخل فيها قايمة الشرا.
  return since / dueAfterDays(cycle, isEssential(item.restockMode, purchaseDays, cycle));
}

/** كام يوم فاضل من عمر الصنف بعد فتحه (zad_inventory.opened_at + opened_life_days)، أو null. */
export function openedLeftDays(
  openedAt: string | null | undefined,
  lifeDays: number | string | null | undefined,
  now: number = Date.now(),
): number | null {
  const at = openedAt ? Date.parse(openedAt) : NaN;
  const life = Number(lifeDays);
  if (!Number.isFinite(at) || !(life > 0)) return null;
  return Math.max(0, life - (now - at) / 86_400_000);
}
