// ملف العميل عند زاد (zad_customer_profile، 20260914012000) — تنضيف التعديلات وبناء «كارت العميل»
// اللي بيدخل سياق العقل كل مرة. صافي عشان يتختبر من غير داتابيز.

export const HOUSEHOLD_ROLES = ["father", "mother", "husband", "wife", "son", "daughter", "single", "student", "grandparent", "other"] as const;
export const AGE_RANGES = ["under_18", "18_24", "25_34", "35_44", "45_54", "55_plus"] as const;
export const PAY_FREQUENCIES = ["monthly", "biweekly", "weekly", "daily", "irregular"] as const;
export const PROFILE_DIALECTS = ["EG", "SA", "GULF", "LEVANT", "IQ", "MA", "TN", "DZ", "LY", "SD", "YE", "TR", "EN"] as const;

/** نوع الدور في البيت بيحدد النوع لو مش مذكور صراحة: «أنا أم» = أنثى. */
const ROLE_GENDER: Record<string, "male" | "female"> = {
  father: "male", husband: "male", son: "male",
  mother: "female", wife: "female", daughter: "female",
};

export interface CustomerProfileRow {
  preferred_name?: string | null;
  gender?: string | null;
  household_role?: string | null;
  age_range?: string | null;
  occupation?: string | null;
  work_schedule?: string | null;
  pay_day?: number | null;
  pay_frequency?: string | null;
  income_source?: string | null;
  household_size?: number | null;
  kids_count?: number | null;
  city?: string | null;
  dialect?: string | null;
  interests?: string[] | null;
  notes?: string | null;
}

const text = (v: unknown, max: number): string | null => {
  if (typeof v !== "string") return null;
  const t = v.replace(/[\u0000-\u001f\u007f\u00ab\u00bb=]/g, " ").replace(/\s+/g, " ").trim();
  return t ? t.slice(0, max) : null;
};
const oneOf = <T extends string>(v: unknown, list: readonly T[]): T | null =>
  typeof v === "string" && (list as readonly string[]).includes(v) ? (v as T) : null;
const intIn = (v: unknown, min: number, max: number): number | null => {
  const n = Number(v);
  return Number.isInteger(n) && n >= min && n <= max ? n : null;
};

/**
 * تعديل جاي من العقل أو التطبيق → الأعمدة اللي تتكتب بس (المبعوت وصالح). الغلط بيرجع في
 * `rejected` بالاسم عشان الموديل يعرف يصلّح، مش يتبلع. `null` صريح = امسح الحقل.
 */
export function sanitizeProfilePatch(input: Record<string, unknown>): { patch: CustomerProfileRow; rejected: string[] } {
  const patch: Record<string, unknown> = {};
  const rejected: string[] = [];
  const set = (key: string, value: unknown, clean: (v: unknown) => unknown) => {
    if (!(key in input)) return;
    if (value === null) { patch[key] = null; return; }
    const c = clean(value);
    if (c === null || c === undefined) rejected.push(key);
    else patch[key] = c;
  };
  set("preferred_name", input.preferred_name, (v) => text(v, 40));
  set("gender", input.gender, (v) => oneOf(v, ["male", "female"] as const));
  set("household_role", input.household_role, (v) => oneOf(v, HOUSEHOLD_ROLES));
  set("age_range", input.age_range, (v) => oneOf(v, AGE_RANGES));
  set("occupation", input.occupation, (v) => text(v, 80));
  set("work_schedule", input.work_schedule, (v) => text(v, 120));
  set("pay_day", input.pay_day, (v) => intIn(v, 1, 31));
  set("pay_frequency", input.pay_frequency, (v) => oneOf(v, PAY_FREQUENCIES));
  set("income_source", input.income_source, (v) => text(v, 80));
  set("household_size", input.household_size, (v) => intIn(v, 1, 30));
  set("kids_count", input.kids_count, (v) => intIn(v, 0, 20));
  set("city", input.city, (v) => text(v, 60));
  set("dialect", input.dialect, (v) => oneOf(typeof v === "string" ? v.toUpperCase() : v, PROFILE_DIALECTS));
  set("interests", input.interests, (v) => {
    if (!Array.isArray(v)) return null;
    const list = [...new Set(v.map((x) => text(x, 30)).filter((x): x is string => !!x))].slice(0, 12);
    return list.length ? list : null;
  });
  set("notes", input.notes, (v) => text(v, 500));
  // «أنا أم» من غير نوع صريح = أنثى — مابنسيبش النوع مجهول والدور بيقوله.
  const role = patch.household_role as string | undefined;
  if (role && !("gender" in patch) && ROLE_GENDER[role]) patch.gender = ROLE_GENDER[role];
  return { patch: patch as CustomerProfileRow, rejected };
}

/** أهم حاجات لو ناقصة يسأل عنها بلطف — مرتبة بالأهمية. */
const IMPORTANT: Array<keyof CustomerProfileRow> = ["preferred_name", "gender", "household_role", "pay_day", "occupation"];

export function customerCard(
  row: CustomerProfileRow | null,
  fallbacks: { name?: string | null; gender?: string | null; familyRole?: string | null },
): Record<string, unknown> {
  const r = row ?? {};
  const card: Record<string, unknown> = {
    preferred_name: r.preferred_name ?? text(fallbacks.name, 40),
    gender: r.gender ?? oneOf(fallbacks.gender, ["male", "female"] as const),
    household_role: r.household_role ?? null,
    family_app_role: fallbacks.familyRole ?? null,
    age_range: r.age_range ?? null,
    occupation: r.occupation ?? null,
    work_schedule: r.work_schedule ?? null,
    pay_day: r.pay_day ?? null,
    pay_frequency: r.pay_frequency ?? null,
    income_source: r.income_source ?? null,
    household_size: r.household_size ?? null,
    kids_count: r.kids_count ?? null,
    city: r.city ?? null,
    dialect: r.dialect ?? null,
    interests: r.interests ?? [],
    notes: r.notes ?? null,
  };
  card.missing_important = IMPORTANT.filter((k) => card[k] === null || card[k] === undefined);
  return card;
}

/** ملاحظات الذاكرة اللي بتوصف العميل نفسه — بتدخل السياق دايماً، مش بس لو قريبة من الرسالة. */
export const IDENTITY_MEMORY_SCOPES = new Set(["household_profile", "salary_plan", "housing_commitments", "primary_bank", "financial_persona", "customer_identity"]);
