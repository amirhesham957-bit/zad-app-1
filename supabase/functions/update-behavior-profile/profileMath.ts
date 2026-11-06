// profileMath.ts — كام أسبوع اتشاف فعلاً (المرحلة ٣، الملف السلوكي التراكمي، الشريحة ١).
//
// المقاس ٦/١١: متوسط الصرف الأسبوعي كان «المصروف في ٩٠ يوم ÷ ١٢٫٩ أسبوع» لأي حساب، حتى اللي عمره أيام. حساب المالك:
// مصروف واحد ٥٠ ⇒ ٣٫٨٩ في الأسبوع، والرقم ده بيدخل توقع صرف الأسبوع (zad_forecasts). القسمة لازم تبقى على اللي اتشاف.

export const PROFILE_WINDOW_DAYS = 90;
const DAY_MS = 86_400_000;

/**
 * الأسابيع اللي الملف بيتقسم عليها: من أول معاملة للحساب (أو أول يوم في النافذة لو أقدم) لحد دلوقتي، أسبوع واحد على
 * الأقل. [firstEverIso] = أقدم created_at للحساب كله، مش للنافذة — حساب قديم ماصرفش أول شهرين يتقسم على النافذة كلها.
 */
export function observedWeeks(firstEverIso: string | null | undefined, now = Date.now()): number {
  const windowStart = now - PROFILE_WINDOW_DAYS * DAY_MS;
  const first = firstEverIso ? Date.parse(firstEverIso) : NaN;
  const from = Number.isFinite(first) ? Math.max(first, windowStart) : windowStart;
  return Math.max(1, (now - from) / (7 * DAY_MS));
}
