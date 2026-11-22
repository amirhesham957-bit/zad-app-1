// وحدة الصحة (م٧.١١ + م٧.١٣): بيانات الصحة اختيارية بالكامل (opt-in).
// الشرط: العميل أعلن الحالة بنفسه أو ضاف دوا بنفسه، وعمل موافقة صريحة. مافيش أي استنتاج.
// م٧.١٢: ممنوع نستنتج حالة أو حمل من المشتريات أو السلوك. الدوال هنا ماتستقبلش أي مشتريات أصلاً.
// م٧.١٣: محتوى الصحة مايغذّيش إعلانات ولا توصيات عمولة. أي سطح صحي ياخد `isAdEligible` = false.
// المسح بضغطة واحدة: wipeHealthProfile.
// النصايح غذائية وعامة وبتتكلم على حاجة العميل نفسه، مش تشخيص ولا علاج.
// دوال صافية: مافيش I/O، ولا شبكة، ولا DB، ولا Deno.env.

export interface HealthMed {
  id: string;
  name: string;
  dosesPerDay: number;
  unitsLeft: number;
  startedAt?: string;
}

export interface HealthProfile {
  consent: boolean;
  consentedAt?: string;
  memberId: string;
  /** حالات يعلنها العميل بنفسه، زي 'حامل' و'أنيميا' و'سكر'. */
  conditions: string[];
  meds: HealthMed[];
}

export interface RefillReminder {
  medId: string;
  name: string;
  daysLeft: number;
  message: string;
}

/** جدول ثابت: حالة معلنة ⇒ نصيحة غذائية عامة (مش تشخيص). */
const CONDITION_TIPS: ReadonlyMap<string, string> = new Map([
  ["سكر", "قلّل السكر المضاف"],
  ["أنيميا", "زوّد الأكل الغني بالحديد"],
  ["حامل", "تجنب الأكل النيّ"],
]);

/** الموافقة لازم تكون صريحة: consent === true ومعاها وقت الموافقة. */
export function hasHealthConsent(p: HealthProfile): boolean {
  return p.consent === true && typeof p.consentedAt === "string" && p.consentedAt.length > 0;
}

/** نصايح غذائية من الحالات المعلنة بس. من غير موافقة، أو حالة مش في الجدول ⇒ مافيش. */
export function dietaryConstraints(p: HealthProfile): string[] {
  if (!hasHealthConsent(p)) return [];
  const out: string[] = [];
  for (const raw of p.conditions) {
    const tip = CONDITION_TIPS.get(raw.trim());
    if (tip !== undefined && !out.includes(tip)) out.push(tip);
  }
  return out;
}

/** عدد الأيام اللي باقية من الدوا بالأرقام اللي دخلها العميل. null لو مفيش معدل جرعات صالح. */
export function daysOfSupplyLeft(med: HealthMed): number | null {
  if (!Number.isFinite(med.dosesPerDay) || med.dosesPerDay <= 0) return null;
  return med.unitsLeft / med.dosesPerDay;
}

/**
 * تذكير التجديد: بيشتغل بالموافقة بس، وللأدوية اللي باقيلها `leadDays` يوم أو أقل.
 * بيرتّب من الأقرب للخلاص. الوقت (now) مابيأثرش على الحساب، لأن الحساب بيعتمد على الكمية اللي دخلها العميل.
 */
export function refillReminders(p: HealthProfile, _now: Date, leadDays = 5): RefillReminder[] {
  if (!hasHealthConsent(p)) return [];
  const out: RefillReminder[] = [];
  for (const med of p.meds) {
    const days = daysOfSupplyLeft(med);
    if (days === null) continue;
    const daysLeft = Math.max(0, Math.floor(days));
    if (daysLeft > leadDays) continue;
    const message = daysLeft === 0
      ? `${med.name} قربت تخلص، فكّر تجيب الكمية الجاية النهارده.`
      : `باقي ${daysLeft} ${daysLeft === 1 ? "يوم" : "أيام"} على ${med.name}، فكّر تجيب الكمية الجاية.`;
    out.push({ medId: med.id, name: med.name, daysLeft, message });
  }
  return out.sort((a, b) => a.daysLeft - b.daysLeft);
}

/** خصوصية فردية: الطالب يشوف ملفه هو بس. صحة أي فرد تاني مابتتعرضش له. */
export function scopedForMember(profiles: HealthProfile[], requesterMemberId: string): HealthProfile[] {
  if (!requesterMemberId) return [];
  return profiles.filter((p) => p.memberId === requesterMemberId);
}

/** م٧.١٣: مفيش إعلانات ولا عمولة على سطح الصحة. أي سطح تاني مسموح. */
export function isAdEligible(ctx: { surface: "health" | string }): boolean {
  return ctx.surface !== "health";
}

/** مسح كامل بضغطة واحدة: الموافقة بتتقفل، والحالات والأدوية بتتفضي. الـmemberId بيفضل. */
export function wipeHealthProfile(p: HealthProfile): HealthProfile {
  return { consent: false, memberId: p.memberId, conditions: [], meds: [] };
}
