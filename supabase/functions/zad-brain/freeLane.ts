/**
 * حارة المجاني (خطة الدخل ٢٠٢٦-١٠-١١، «سيطرة الحشد»): الإعلانات هتجيب زحمة، والطبقة
 * المجانية لجيميناي مش هتستحملها. فلفة الشات بتتعامل حسب الباقة:
 *
 *   * المشترك: حارة "paid" — مفتاح محجوز ليه الأول (keyLanes.ts)، والسياق الكامل.
 *   * المجاني: حارة "free" — مايلمسش مفتاح المشتركين، وتاريخ محادثة أقصر.
 *   * المجاني بعد ما ميزانية اليوم تخلص (`ZAD_FREE_DAILY_BUDGET` لفة في اليوم على المشروع
 *     كله): حارة "free_busy" — جروك على طول (حصة مزوّد تاني)، أو رسالة صريحة لو مفيش جروك.
 *
 * والحارس اللي لكل عميل (zad_turn_begin): طلب واحد في نفس الوقت، وحد في الدقيقة — بيقفل
 * الضغط المتكرر على الزرار. الباقة بتتقري على السيرفر من zad_entitlements، مش من الطلب.
 */
import type { Lane } from "./keyLanes.ts";

/** لفات المجاني في اليوم على المشروع كله قبل ما يتحول لجروك. صفر = من غير ميزانية. */
export function freeDailyBudget(configured?: string | null): number {
  const v = configured != null && configured.trim() !== "" ? Number(configured) : NaN;
  return Number.isInteger(v) && v >= 0 ? v : 1500;
}

/** الحارة لـ لفة شات. [freeTurnsToday] العدد بعد ما اللفة دي اتحسبت؛ null لو العد فشل. */
export function chatLane(paid: boolean, freeTurnsToday: number | null, budget: number): Lane {
  if (paid) return "paid";
  if (budget > 0 && freeTurnsToday != null && freeTurnsToday > budget) return "free_busy";
  return "free";
}

/** كام رسالة من المحادثة بتدخل البرومبت: المشترك ٨ (زي ما كان)، والمجاني ٤. */
export function historyWindow(paid: boolean): number {
  return paid ? 8 : 4;
}

/** حد اللفات في الدقيقة للعميل الواحد. المكالمة الصوتية مشترك أو مجاني ممكن تعدي ٦. */
export function turnsPerMinute(paid: boolean): number {
  return paid ? 20 : 8;
}

/** رد الحارس، بنبرة زاد: مش رفض، استنى ثانية. */
export function gateReply(reason: string | undefined): string {
  return reason === "busy"
    ? "لسه بخلّص ردي على رسالتك اللي فاتت — ثانية واحدة وابعت تاني 🙏"
    : "بالراحة عليّ شوية 😅 رسايل كتير ورا بعض — ابعت تاني بعد دقيقة.";
}

/** المجاني وقت الزحمة ومفيش احتياطي. */
export const FREE_BUSY_REPLY =
  "زاد عليه ضغط كبير دلوقتي، فالردود المجانية واقفة لحد بكرة 🙏 " +
  "تقدر تسجّل مصاريفك عادي، والمشتركين ردودهم شغالة من غير انتظار.";
