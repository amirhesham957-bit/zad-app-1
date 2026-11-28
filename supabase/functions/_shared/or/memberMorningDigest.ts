// موجز الصبح لكل فرد (P2.8): لكل مستلم، بنفلتر البنود المرشحة بمصفوفة الرؤية الأول، وبعدين ميزانية الانتباه
// (planMessages) على اللي فضل. البند الحرج مابيصرفش من الميزانية بس برضه لازم يعدّي المصفوفة (الحرج مايكسرش الخصوصية).
// دالة نقية: مافيش I/O، ومش متوصّلة بكرون لسه.

import { planMessages } from "./attentionBudget.ts";
import { canSee, type Consent, type Domain, type Person, type Subject } from "./visibilityMatrix.ts";

export interface DigestItem {
  id: string;
  subject: Subject;
  domain: Domain;
  text: string;
  value: number;
  cost: number;
  critical?: boolean;
}

export interface MemberDigest {
  memberId: string;
  send: DigestItem[];
  deferred: string[];
  hidden: string[];
}

export function buildMemberDigest(
  to: Person,
  items: readonly DigestItem[],
  consentBy: Readonly<Record<string, Consent>>,
  budget: number,
): MemberDigest {
  const visible = items.filter((i) => canSee(to, i.subject, i.domain, consentBy[i.subject.id] ?? {}));
  const hidden = items.filter((i) => !visible.includes(i)).map((i) => i.id);
  const plan = planMessages(visible.map((i) => ({ id: i.id, value: i.value, cost: i.cost, critical: i.critical === true })), budget);
  const byId = new Map(visible.map((i) => [i.id, i]));
  return { memberId: to.id, send: plan.send.map((id) => byId.get(id)!), deferred: plan.deferred, hidden };
}

/** موجز كل أفراد البيت، كل واحد بميزانيته (budgets[id]، الافتراضي defaultBudget). */
export function buildHouseholdDigests(
  members: readonly Person[],
  items: readonly DigestItem[],
  consentBy: Readonly<Record<string, Consent>>,
  budgets: Readonly<Record<string, number>>,
  defaultBudget: number,
): MemberDigest[] {
  return members.map((m) => buildMemberDigest(m, items, consentBy, budgets[m.id] ?? defaultBudget));
}
