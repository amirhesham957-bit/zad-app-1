// emergency.ts — كارت الطوارئ (ZAD_LIVING_BRAIN.md الشريحة ٢٠).
//
// المالك (٢٠٢٦-١٠-٠٤): «عند ظرف طارئ (وعكة مفاجئة)، زاد يستحضر فوراً التاريخ الطبي للطفل، جهات الاتصال، وأقرب
// خدمة — من غير توتر ولا بحث». الحاجات دي متفرقة على جداول: الأدوية (ولمين)، الجرعات اللي اتاخدت النهارده،
// المواعيد الطبية، والعيلة. هنا بتتجمع في كارت واحد للشخص — من بيانات العميل نفسه بس، ومن غير أي تشخيص
// ولا اقتراح دوا: زاد مش دكتور.
//
// رقم الإسعاف: من جدول صغير متأكدين منه بس. رقم غلط في طارئ أوحش من مفيش رقم — والبلد اللي مش هنا
// بيتقال فيه «اتصل بالإسعاف في بلدك» من غير رقم.

import { normalizeForPerson } from "./shared.ts";

/** الإسعاف — البلاد اللي الرقم فيها متأكد منه بس. */
export const AMBULANCE_NUMBERS: Readonly<Record<string, string>> = {
  EG: "123",
  SA: "997",
  AE: "998",
  KW: "112",
  QA: "999",
  JO: "911",
  TR: "112",
};

export interface EmergencyCard {
  person: string;
  ambulance: string | null;
  medicines: Array<{ name: string; dosage: string | null; dose_times: string | null; remaining: number | null }>;
  /** جرعات اتاخدت آخر ٢٤ ساعة — الدكتور هيسأل «خد إيه وإمتى؟». */
  doses_last_24h: Array<{ name: string; taken_at: string }>;
  medical_appointments: Array<{ title: string; starts_at: string }>;
  /** حاجات زاد عارفها عن الشخص (حساسية، حالة مزمنة) من الذاكرة. */
  notes: string[];
  family_to_call: string[];
}

interface Med { id: string; name: string; dosage: string | null; dose_times: string | null; remaining_quantity: number | null; for_person: string | null }
interface Dose { item_id: string; taken_at: string | null; status: string | null }
interface Appt { title: string; starts_at: string; kind: string | null; for_person: string | null }

/** «ماما» و«أمي» واحد — نفس التوحيد اللي أدوات الصيدلية بتستخدمه (normalizeForPerson). null = العميل نفسه. */
function samePerson(a: string | null, b: string | null): boolean {
  return (normalizeForPerson(a) ?? "").toLowerCase() === (normalizeForPerson(b) ?? "").toLowerCase();
}

/**
 * [person] = null ⇒ العميل نفسه (for_person فاضي)، وإلا اسم الشخص زي ما اتوحّد. نقي: كل البيانات داخلة.
 */
export function emergencyCard(input: {
  person: string | null;
  country: string | null;
  medicines: readonly Med[];
  doses: readonly Dose[];
  appointments: readonly Appt[];
  notes: readonly string[];
  family: ReadonlyArray<{ alias: string | null; role: string | null; is_me: boolean }>;
  now?: number;
}): EmergencyCard {
  const now = input.now ?? Date.now();
  const meds = input.medicines.filter((m) => samePerson(m.for_person, input.person));
  const byId = new Map(meds.map((m) => [m.id, m.name]));
  const code = String(input.country ?? "").trim().toUpperCase();
  return {
    person: input.person ?? "العميل نفسه",
    ambulance: AMBULANCE_NUMBERS[code] ?? null,
    medicines: meds.map((m) => ({ name: m.name, dosage: m.dosage, dose_times: m.dose_times, remaining: m.remaining_quantity })),
    doses_last_24h: input.doses
      .filter((d) => d.status === "taken" && d.taken_at && now - Date.parse(d.taken_at) <= 86_400_000 && byId.has(d.item_id))
      .map((d) => ({ name: byId.get(d.item_id) as string, taken_at: d.taken_at as string })),
    medical_appointments: input.appointments
      .filter((a) => a.kind === "medical" && samePerson(a.for_person, input.person))
      .map((a) => ({ title: a.title, starts_at: a.starts_at })).slice(0, 5),
    notes: input.notes.slice(0, 5),
    family_to_call: input.family.filter((f) => !f.is_me && (f.alias ?? "").trim())
      .map((f) => f.alias as string).slice(0, 6),
  };
}
