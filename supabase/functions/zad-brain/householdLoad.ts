// householdLoad.ts — «ضغط البيت» (ZAD_LIVING_BRAIN.md الشريحة ١٢).
//
// المالك (٢٠٢٦-١٠-٠٣) طلب «متجر مزاج»: زاد يقلل الإزعاج وقت الإجهاد، ويقترح خروجات وقت الفائض. اللي
// اترفض: استنتاج حالة العميل النفسية من نبرة صوته وسرعة كتابته وأوقات موبايله — بيانات حساسة مالهاش
// مصدر عندنا. اللي اتبنى: نفس الهدف من أرقام البيت نفسها، اللي العميل شايفها أصلاً — الفلوس خلصت ولا
// فايضة، وضع «مفلس»، والساعة متأخرة. الاسم «ضغط البيت» مش «مزاج العميل»، والعقل ممنوع يقول له
// «إنت متوتر».

export type HouseholdLoadLevel = "high" | "normal" | "easy";

export interface HouseholdLoad {
  level: HouseholdLoadLevel;
  /** ليه — بالكلام اللي العقل يقدر يبني عليه (مش بيتقال للعميل كده). */
  reasons: string[];
}

export function householdLoad(input: {
  threat: string | null | undefined;
  available: number | null | undefined;
  budget: number | null | undefined;
  brokeMode: boolean;
  /** الساعة المحلية بتوقيت سوق الحساب. */
  localHour: number;
  /** مواعيد النهارده (الشريحة ١٨، «يوم مزحوم»). */
  appointmentsToday?: number;
}): HouseholdLoad {
  const reasons: string[] = [];
  const available = Number(input.available);
  const budget = Number(input.budget);
  if (input.brokeMode) reasons.push("وضع «مفلس باقي الشهر» شغال");
  if (input.threat === "OVER") reasons.push("الصرف عدّى الرصيد");
  else if (input.threat === "DANGER") reasons.push("الصرف أسرع من الميزانية بكتير");
  if (Number.isFinite(available) && input.available !== null && input.available !== undefined && available < 0) {
    reasons.push("المتاح بالسالب");
  }
  if (input.localHour >= 0 && input.localHour < 5) reasons.push("الوقت متأخر بالليل");
  if ((input.appointmentsToday ?? 0) >= 3) reasons.push(`النهارده فيه ${input.appointmentsToday} مواعيد`);
  if (reasons.length > 0) return { level: "high", reasons };

  if (input.threat === "SAFE" && budget > 0 && Number.isFinite(available) && available >= 0.3 * budget) {
    return { level: "easy", reasons: [`المتاح ${Math.round(available)} — أكتر من ٣٠٪ من الميزانية`] };
  }
  return { level: "normal", reasons: [] };
}

/** مواعيد النهارده بتوقيت سوق الحساب، من صفوف المواعيد الجاية في السناب شوت. */
export function appointmentsOnLocalDay(
  rows: ReadonlyArray<{ starts_at?: string | null }>, timeZone: string, now = new Date(),
): number {
  const day = (iso: string) => new Intl.DateTimeFormat("en-CA", { timeZone, year: "numeric", month: "2-digit", day: "2-digit" })
    .format(new Date(iso));
  const today = day(now.toISOString());
  return rows.filter((r) => r.starts_at && Number.isFinite(Date.parse(r.starts_at)) && day(r.starts_at) === today).length;
}

/** قاعدة البرومبت — نفس الكلام في الشات والتحليل اليومي. "" لو مفيش household_load. */
export function householdLoadRule(snap: { household_load?: HouseholdLoad | null } | null | undefined): string {
  if (!snap?.household_load) return "";
  return "**household_load** = ضغط البيت من الأرقام (مش حالة العميل النفسية — عمرك ما تقوله «إنت متوتر» أو «شكلك مضغوط»): " +
    "high ⇒ ردود قصيرة وداعمة، حاجة واحدة في المرة، من غير اقتراحات شراء ولا أفكار جديدة، وأي تنبيه أو رؤية مش عاجلة تستنى؛ " +
    "easy ⇒ لو الكلام سمح، ممكن تقترح فكرة خروجة أو حاجة حلوة للبيت جوه المتاح (برقم available)؛ normal ⇒ عادي.";
}
