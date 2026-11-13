// familyMembers.ts — أفراد عيلة العميل اللي ممكن الدوا يروح صيدليتهم (قرار المالك ١٣/١١/٢٠٢٦).
// مشترك بين العقل (add_pharmacy_item، zad-brain/familyMedicine.ts) والبوت (أزرار «لمين؟» تحت فاتورة الصيدلية).
// الشرط الوحيد للكتابة في صيدلية حد تاني: zad_family_share_granted(viewer = اللي بيسجّل، owner = الفرد،
// 'medicines') — نفس الدالة اللي بتفتح الرؤية، وبتتأكد إن الاتنين لسه في نفس العيلة.

import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";

/** صلة القرابة (بعد normalizeForPerson في zad-brain/shared.ts) ⇐ household_role في ملف الفرد. */
export const KIN_ROLES: Record<string, readonly string[]> = {
  "ماما": ["mother"],
  "بابا": ["father"],
  // بالظبط، من غير «أم البيت»: ابن بيقول «مراتي» وأمه دورها mother ⇒ الدوا كان هيروح حساب أمه.
  "مراتي": ["wife"],
  "جوزي": ["husband"],
};

export interface FamilyCandidate {
  userId: string;
  role: string | null;
  name: string;
  /** وافق إن اللي بيسجّل يتابع أدويته. */
  granted: boolean;
}

/**
 * الفرد اللي صلة القرابة دي بتشاور عليه: واحد بس في العيلة بالدور ده وموافق. اتنين بنفس الدور (أو
 * مفيش موافقة) ⇒ null، والدوا يفضل على حساب اللي بيسجّل — التخمين هنا معناه دوا في حساب غلط.
 */
export function pickKinMember(forPerson: string | null, candidates: readonly FamilyCandidate[]): FamilyCandidate | null {
  if (!forPerson) return null;
  const roles = KIN_ROLES[forPerson];
  const byName = candidates.filter((c) => c.name.trim() && c.name.trim() === forPerson);
  const matches = byName.length > 0 ? byName : roles ? candidates.filter((c) => c.role && roles.includes(c.role)) : [];
  if (matches.length !== 1 || !matches[0].granted) return null;
  return matches[0];
}

/** أفراد عيلة اللي بيسجّل (غيره)، بدورهم واسمهم وهل وافقوا على متابعة الأدوية. */
export async function familyMedicineCandidates(sb: SupabaseClient, senderId: string): Promise<FamilyCandidate[]> {
  const { data: mine } = await sb.from("family_members").select("family_id").eq("user_id", senderId);
  const families = ((mine ?? []) as Array<{ family_id: string }>).map((m) => m.family_id);
  if (families.length === 0) return [];
  const { data: members } = await sb.from("family_members").select("user_id,alias").in("family_id", families)
    .neq("user_id", senderId);
  const rows = (members ?? []) as Array<{ user_id: string; alias: string | null }>;
  if (rows.length === 0) return [];
  const ids = [...new Set(rows.map((r) => r.user_id))];
  const { data: profiles } = await sb.from("zad_customer_profile").select("user_id,household_role,preferred_name")
    .in("user_id", ids);
  const profileOf = new Map(((profiles ?? []) as Array<{ user_id: string; household_role: string | null; preferred_name: string | null }>)
    .map((p) => [p.user_id, p]));
  const out: FamilyCandidate[] = [];
  for (const id of ids) {
    const { data: granted } = await sb.rpc("zad_family_share_granted", { p_viewer: senderId, p_owner: id, p_scope: "medicines" });
    const p = profileOf.get(id);
    const alias = rows.find((r) => r.user_id === id)?.alias ?? "";
    out.push({
      userId: id,
      role: p?.household_role ?? null,
      name: (p?.preferred_name ?? "").trim() || alias.trim() || "فرد من العيلة",
      granted: granted === true,
    });
  }
  return out;
}

