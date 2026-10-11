// newcomer.ts — أول ٧٢ ساعة (الموجة ٣ من «خطة سد الفجوات»، ٢٠٢٦-١٠-١٠).
//
// قبل كده الحساب الجديد كان بياخد سؤال واحد الصبح من أول يوم، بيلف على خانات الملف بالتاريخ
// (dailyQuestion) — فـ«بتشتغل إيه؟» ممكن تيجي قبل «بتقبض يوم كام؟». والنواقص اللي بتشغّل
// حارس هي اللي بتفرق في الأيام الأولى: من غير يوم القبض دورة الميزانية غلط، ومن غير مواعيد
// الدوا مفيش تذكير ولا «فاتتك الجرعة»، ومن غير البلد العملة واللهجة والتوقيت غلط، ومن غير
// عيد ميلاد مفيش هدية تتحجز.
//
// الشكل: الحساب اللي عمره أقل من ٧٢ ساعة ياخد سؤالين في اليوم — الصبح (خانة سؤال اليوم في
// تحية الصبح) وبعد الضهر (لحظة newcomer_question، ٤ العصر بتوقيته) — من النواقص دي بس، وبعدها
// يرجع لسؤال الصبح العادي. قواعد مش موديل (الكوتة: ٢٠ طلب/يوم/مفتاح)، والسؤال اللي اتسأل
// مايتسألش تاني جوه الـ٧٢ ساعة.
//
// الجواب بيرجع لفة شات عادية والسؤال بيوصل للعقل في asked_this_morning بنفس الأنواع الموجودة
// (profile / occasion / curiosity) — مفيش نوع جديد يتعلمه البرومبت.

export const NEWCOMER_HOURS = 72;
const HOUR_MS = 3_600_000;

export function isNewcomer(createdAt: string | null | undefined, now: number): boolean {
  const at = createdAt ? Date.parse(createdAt) : NaN;
  return Number.isFinite(at) && now - at >= 0 && now - at < NEWCOMER_HOURS * HOUR_MS;
}

export type NewcomerGap = "dose_times" | "pay_day" | "country" | "birthday";

export interface NewcomerMed {
  name: string;
  for_person: string | null;
}

export interface NewcomerQuestion {
  /** ثابت لنفس الناقصة — عليه بيتعمل منع التكرار (facts.newcomer.key). */
  key: string;
  gap: NewcomerGap;
  question: string;
  /** نفس الحقول اللي askedThisMorning بيقراها — الجواب بيتسجل بنفس الطريق. */
  facts: Record<string, unknown>;
}

function blank(v: unknown): boolean {
  return v === null || v === undefined || (typeof v === "string" && v.trim() === "");
}

/**
 * أهم ناقصة لسه ماتسألتش، أو null. الترتيب: مواعيد الدوا (صحة)، يوم القبض (الميزانية كلها)،
 * البلد (العملة والتوقيت)، عيد الميلاد.
 */
export function newcomerQuestion(input: {
  profile: Record<string, unknown> | null;
  country: string | null;
  medsWithoutTimes: readonly NewcomerMed[];
  /** occasionQuestion(...) — العميل نفسه الأول، وبعده الناس اللي الذاكرة عارفاهم. */
  birthday: { for: string | null; question: string } | null;
  askedKeys: ReadonlySet<string>;
}): NewcomerQuestion | null {
  const candidates: NewcomerQuestion[] = input.medsWithoutTimes
    .map(doseTimesQuestion).filter((q): q is NewcomerQuestion => q !== null);
  if (blank(input.profile?.pay_day)) {
    candidates.push({
      key: "newcomer:pay_day",
      gap: "pay_day",
      question: "بتقبض يوم كام في الشهر؟ عشان أحسب شهرك صح",
      facts: { daily_question_kind: "profile", daily_question_field: "pay_day" },
    });
  }
  if (blank(input.country)) {
    candidates.push({
      key: "newcomer:country",
      gap: "country",
      question: "إنت عايش في أنهي بلد؟ عشان العملة والمواعيد تبقى صح",
      facts: {
        daily_question_kind: "curiosity",
        curiosity: {
          key: "newcomer:country",
          kind: "newcomer",
          tool: "set_market",
          record: "set_market بكود البلد (حرفين) وعملته (٣ حروف) من البلد اللي قاله. " +
            "لو قال بلد مش واضحة أو مش عايز يقول: سيبها.",
        },
      },
    });
  }
  if (input.birthday) {
    candidates.push({
      key: `newcomer:birthday:${(input.birthday.for ?? "").trim().toLowerCase()}`,
      gap: "birthday",
      question: input.birthday.question,
      facts: { daily_question_kind: "occasion", occasion_ask: { for: input.birthday.for } },
    });
  }
  return candidates.find((c) => !input.askedKeys.has(c.key)) ?? null;
}

/**
 * سؤال مواعيد دوا مالوش مواعيد. نفس السؤال في أول ٧٢ ساعة، وبعدها مرة واحدة لكل دوا لأي حساب (الموجة ٣،
 * بند ٧: التطبيق بيقول وبيسمح بالتحديد من الموجة ١، والبوت ماكانش بيسأل) — تحية الصبح بتوصل تليجرام.
 */
export function doseTimesQuestion(med: NewcomerMed): NewcomerQuestion | null {
  const name = med.name.trim();
  if (!name) return null;
  const whose = med.for_person?.trim() ? ` بتاع ${med.for_person.trim()}` : "";
  const key = `newcomer:dose_times:${name.toLowerCase()}`;
  return {
    key,
    gap: "dose_times",
    question: `«${name}»${whose} بيتاخد الساعة كام؟ عشان أفكّرك في ميعاده`,
    facts: {
      daily_question_kind: "curiosity",
      curiosity: {
        key,
        kind: "newcomer",
        tool: "update_pharmacy_item",
        record: `update_pharmacy_item بالاسم «${name}» وdose_times بالساعات اللي قالها بالظبط (times_explicit = true). ` +
          "لو قال «مش عارف» أو «لما أفتكر»: سيبها. ماتخمّنش ساعات.",
      },
    },
  };
}

/** مفاتيح النواقص اللي اتسألت (facts.newcomer.key) في الصبح أو بعد الضهر. */
export function askedNewcomerKeys(rows: ReadonlyArray<{ facts?: unknown }> | null | undefined): Set<string> {
  const keys = new Set<string>();
  for (const row of rows ?? []) {
    const key = (row?.facts as { newcomer?: { key?: unknown } } | null | undefined)?.newcomer?.key;
    if (typeof key === "string" && key) keys.add(key);
  }
  return keys;
}

/** الحقول اللي بتتحط في facts اللحظة: السؤال + طريقة تسجيل الجواب + مفتاح منع التكرار. */
export function newcomerFacts(q: NewcomerQuestion): Record<string, unknown> {
  return { daily_question: q.question, ...q.facts, newcomer: { key: q.key, gap: q.gap } };
}
