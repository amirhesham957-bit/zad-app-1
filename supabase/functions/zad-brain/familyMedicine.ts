// familyMedicine.ts — «دا دوا مامتي»: الدوا يروح صيدلية مين؟ (قرار المالك ١٣/١١/٢٠٢٦)
//
// قبل كده كل دوا كان بيتسجل على حساب اللي بعته، و«لماما» مجرد for_person. فالتذكير كان بيوصل الابن،
// ومامته — اللي عندها حساب في نفس العيلة — ماكانتش بتعرف حاجة. قرار المالك: لو اللي الدوا ليه
// فرد في عيلتك عنده حساب ووافق إنك تتابع أدويته (zad_family_shares, scope = medicines, granted)،
// الدوا يتسجل في صيدليته هو: التذكير يوصله، ولو جرعة فاتته تنبيه family_dose_missed يوصلك.
// غير كده (مالوش حساب، أو ماوافقش) ⇒ زي الأول: على حسابك و for_person باسمه.
//
// الموافقة هي الشرط الوحيد للكتابة في حساب حد تاني، وبتتقري من zad_family_share_granted (نفس الدالة
// اللي بتفتح الرؤية) — اللي بيتأكد كمان إن الاتنين لسه في نفس العيلة.

import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { normalizeForPerson } from "./shared.ts";
import { type FamilyCandidate, familyMedicineCandidates, pickKinMember } from "../_shared/familyMembers.ts";

export interface MedicineHolder {
  /** الحساب اللي الدوا هيتكتب في صيدليته. */
  ownerId: string;
  /** for_person على الصف — null لما الدوا في حساب صاحبه. */
  forPerson: string | null;
  /** اسم الفرد لما الدوا راح حسابه. */
  memberName: string | null;
}

/**
 * صيدلية مين. `memberId` (من زرار في البوت) لازم يكون فرد موافق، وإلا مرفوض — الزرار ممكن يكون قديم
 * والموافقة اتلغت. `forPerson` (من الكلام أو الكابشن) بيروح لفرد موافق لو صلة القرابة بتشاور عليه
 * لوحده، وإلا بيفضل for_person على حساب اللي بيسجّل زي الأول.
 */
export async function medicineHolder(
  sb: SupabaseClient,
  senderId: string,
  input: { for_person?: unknown; for_member_id?: unknown },
): Promise<MedicineHolder | { refused: string }> {
  const forPerson = normalizeForPerson(input.for_person);
  const memberId = typeof input.for_member_id === "string" ? input.for_member_id.trim() : "";
  if (!memberId && !forPerson) return { ownerId: senderId, forPerson: null, memberName: null };

  let candidates: FamilyCandidate[];
  try {
    candidates = await familyMedicineCandidates(sb, senderId);
  } catch (e) {
    console.warn("[family_medicine] candidates read failed:", (e as Error)?.message);
    candidates = [];
  }

  if (memberId) {
    const member = candidates.find((c) => c.userId === memberId);
    if (!member || !member.granted) {
      return { refused: "الفرد ده مش في عيلتك أو مش موافق إنك تتابع أدويته — سجّل الدوا باسمه على حسابك (for_person) بدل كده." };
    }
    return { ownerId: member.userId, forPerson: null, memberName: member.name };
  }

  const member = pickKinMember(forPerson, candidates);
  return member
    ? { ownerId: member.userId, forPerson: null, memberName: member.name }
    : { ownerId: senderId, forPerson, memberName: null };
}

/** أقصى عدد أسماء في رسالة الفرد — الفاتورة الواحدة ممكن تبقى ١٠ أدوية. */
const NOTICE_NAMES_MAX = 8;

/**
 * رسالة الفرد اللي اتسجلّه دوا: مين سجّل وإيه، وسؤال المواعيد **مرة واحدة** لكل الأدوية اللي من غير
 * مواعيد (مش سؤال لكل دوا). نص محايد من غير تذكير/تأنيث — مانعرفش مين بيقرا.
 */
export function memberNoticeText(senderName: string, names: readonly string[], untimed: readonly string[]): { title: string; body: string } {
  const list = names.slice(0, NOTICE_NAMES_MAX).map((n) => `«${n}»`).join("، ") +
    (names.length > NOTICE_NAMES_MAX ? ` و${names.length - NOTICE_NAMES_MAX} كمان` : "");
  const what = names.length === 1 ? `دوا في صيدليتك: ${list}` : `${names.length} أدوية في صيدليتك: ${list}`;
  const ask = untimed.length === 0
    ? "هفكّرك بمواعيدها."
    : untimed.length === 1
    ? `«${untimed[0]}» بيتاخد الساعة كام؟ قولّي وأنا أفكّرك في ميعاده.`
    : "قولّي كل واحد فيهم بيتاخد الساعة كام، وأنا أفكّرك في ميعاده.";
  return { title: "💊 أدوية جديدة في صيدليتك", body: `${senderName} سجّل ${what}.\n${ask}` };
}

/**
 * الفرد بيعرف إن حد سجّله دوا: إشعار في التطبيق، تليجرام، وسطر في محادثته — عشان لما يرد «٨ الصبح»
 * العقل يبقى عارف بيتكلم عن إيه (من غير السطر ده الرد كان هيوصل عقل مش فاهم السؤال).
 * عمره ما يرمي: الدوا اتسجل خلاص.
 */
export async function tellMemberMedicineAdded(
  sb: SupabaseClient,
  memberId: string,
  senderId: string,
  names: string[],
  untimed: string[],
  deps: {
    recordConversation: (sb: SupabaseClient, userId: string, turns: Array<{ role: "assistant"; text: string }>) => Promise<void>;
    proactiveTurn: (title: string, body: string) => string;
    pushToTelegram: (userId: string, title: string, body: string) => Promise<unknown>;
    pushToDevice: (sb: SupabaseClient, userId: string, title: string, body: string) => Promise<unknown>;
  },
): Promise<void> {
  if (names.length === 0) return;
  try {
    // الأسماء جاية من اللي بيسجّل (member_notice) وبتتكتب في محادثة الفرد — يعني نص بيوصل عقله. اللي
    // مش دوا فعلاً في صيدلية الفرد مابيتكتبش، فمفيش طريق لنص حر يدخل محادثة حد تاني.
    const { data: meds } = await sb.from("zad_pharmacy_items").select("name").eq("user_id", memberId);
    const have = new Set(((meds ?? []) as Array<{ name: string | null }>).map((m) => (m.name ?? "").trim()));
    names = names.filter((n) => have.has(n.trim()));
    untimed = untimed.filter((n) => names.includes(n));
    if (names.length === 0) return;
    const [{ data: profile }, { data: member }] = await Promise.all([
      sb.from("zad_customer_profile").select("preferred_name").eq("user_id", senderId).maybeSingle(),
      sb.from("family_members").select("alias").eq("user_id", senderId).limit(1).maybeSingle(),
    ]);
    const senderName = ((profile as { preferred_name?: string | null } | null)?.preferred_name ?? "").trim() ||
      ((member as { alias?: string | null } | null)?.alias ?? "").trim() || "حد من العيلة";
    const msg = memberNoticeText(senderName, names, untimed);
    await deps.recordConversation(sb, memberId, [{ role: "assistant", text: deps.proactiveTurn(msg.title, msg.body) }]);
    const { error } = await sb.from("app_notifications").insert({ user_id: memberId, title: msg.title, message: msg.body });
    if (error) console.warn("[family_medicine] app notification failed:", error.message);
    await Promise.all([
      deps.pushToTelegram(memberId, msg.title, msg.body),
      deps.pushToDevice(sb, memberId, msg.title, msg.body),
    ]);
  } catch (e) {
    console.warn("[family_medicine] member notice failed:", (e as Error)?.message);
  }
}

/**
 * `member_notice` في add_pharmacy_item: من غيره الفرد بيتبلّغ بالدوا ده لوحده. البوت بيسجّل الفاتورة كلها
 * دوا دوا، فبيبعت false لكلهم ماعدا الأخير، والأخير بقايمة الفاتورة كلها — رسالة واحدة مش سبعة.
 */
export function memberNoticeNames(raw: unknown, medName: string): { names: string[]; untimed: string[] } | null {
  if (raw === false) return null;
  if (raw && typeof raw === "object" && !Array.isArray(raw)) {
    const r = raw as { names?: unknown; untimed?: unknown };
    const clean = (v: unknown) => Array.isArray(v)
      ? v.filter((x): x is string => typeof x === "string").map((x) => x.trim().slice(0, 80)).filter(Boolean).slice(0, 20)
      : [];
    const names = clean(r.names);
    if (names.length > 0) return { names, untimed: clean(r.untimed).filter((n) => names.includes(n)) };
  }
  return { names: [medName], untimed: [] };
}
