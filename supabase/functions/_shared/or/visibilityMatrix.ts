// مصفوفة الرؤية (P2.5): مين يشوف إيه عن مين. نسخة نقية من القواعد اللي في ميجريشن 20261128180000 (RLS ودوال العرض)،
// عشان البوت والـOR يقروا نفس القرار من غير ما يسألوا الداتابيز. لو الاتنين اختلفوا، الـSQL هو الصح.
// consent[domain] === true فقط لو صاحب البيانات وافق صراحةً (zad_family_shares). أي حاجة تانية = غير موافق (fail closed).
// دالة نقية: مافيش I/O.

export type Domain = "tasks" | "goals" | "spending" | "budget_total" | "medicines" | "inventory";

export interface Person {
  id: string;
  /** وضع الأطفال (family_members.role = 'child' أو فرد بيت kind = 'child' ليه حساب). */
  minor: boolean;
  /** admin في العيلة. */
  guardian: boolean;
  familyId: string | null;
}

export interface Subject extends Person {
  /** الدوا اللي صاحبه قفله (zad_pharmacy_items.is_private). */
  medicinePrivate?: boolean;
}

export type Consent = Readonly<Partial<Record<Domain, boolean>>>;

/** هل viewer يشوف تفاصيل domain بتاعة subject؟ */
export function canSee(viewer: Person, subject: Subject, domain: Domain, consent: Consent = {}): boolean {
  if (viewer.id === subject.id) {
    // القاصر: مهامه وأهدافه بس. لا ميزانية ولا صيدلية.
    if (viewer.minor) return domain === "tasks" || domain === "goals";
    return true;
  }
  // القاصر مايشوفش حد تاني أبداً.
  if (viewer.minor) return false;
  const sameFamily = viewer.familyId !== null && viewer.familyId === subject.familyId;
  if (!sameFamily) return false;
  // إجمالي الميزانية: رقم واحد للبالغين في العيلة، مش تفاصيل حد.
  if (domain === "budget_total") return !subject.minor;
  if (domain === "inventory") return true;
  // ولي الأمر والقاصر: وصاية كاملة على المهام والأهداف، والباقي بالموافقة (التلقائية للقاصر).
  if (subject.minor) {
    if (viewer.guardian && (domain === "tasks" || domain === "goals")) return true;
    return consent[domain] === true;
  }
  // بالغ ← بالغ: الصيدلية مفتوحة إلا الخاص (والموافقة الصريحة بتكشف الخاص)، والباقي بالموافقة.
  if (domain === "medicines") return consent.medicines === true || subject.medicinePrivate !== true;
  if (domain === "goals") return consent.tasks === true || consent.goals === true;
  return consent[domain] === true;
}
