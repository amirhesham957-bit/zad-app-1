// v2-3: بيرسونا العيلة. خلف ZAD_FAMILY_PERSONA (مقفول افتراضياً: مفيش بلوك ومفيش تغيير في اللقطة = صفر توكن).
// خصوصية البيت (م٧.٩، قرار المالك ٢٧/١١): كل فرد يشوف مصروفاته وأهدافه بالتفصيل، والباقي يشوف
// إجمالي ميزانية البيت بس. المشاركة الصريحة (zad_family_shares) بتتعرض من أدواتها (familyAccess.visibleSpenders)، مش من اللقطة.

export const FAMILY_PERSONA_FLAG = "ZAD_FAMILY_PERSONA";

export function familyPersonaEnabled(get: (k: string) => string | undefined): boolean {
  const v = (get(FAMILY_PERSONA_FLAG) ?? "").trim().toLowerCase();
  return v === "1" || v === "true" || v === "on";
}

interface FamilyMemberView { alias?: string; role?: string; balance?: number; savings_goal?: number; online_now?: boolean }
interface FamilySnap { mine?: unknown; members?: FamilyMemberView[]; [k: string]: unknown }

/** أفراد العيلة بدون أي رقم فردي: الاسم والدور وحالة الاتصال بس. أرقام «أنا» (`mine`) والإجماليات بتفضل. */
export function redactFamilyForPersona<T extends FamilySnap | null | undefined>(family: T): T {
  if (!family || !Array.isArray(family.members)) return family;
  const members = family.members.map((m) => ({ alias: m.alias, role: m.role, online_now: m.online_now }));
  return { ...family, members } as T;
}

/** "" لو الفلاج مقفول، أو مفيش عيلة، أو الحساب طفل (له بلوكه)، أو العيلة فرد واحد. */
export function familyPersonaBlock(
  snap: { family?: FamilySnap | null } | null | undefined,
  get: (k: string) => string | undefined,
): string {
  if (!familyPersonaEnabled(get)) return "";
  const fam = snap?.family;
  if (!fam || !fam.mine || (fam.members ?? []).length < 2) return "";
  if ((fam.mine as { role?: string }).role === "child") return "";
  return "\n=== بيرسونا العيلة ===\n"
    + "إنت واحد من البيت. اتكلم عن «احنا» و«البيت» في الحاجات المشتركة، وعن العميل باسمه في حاجته هو.\n"
    + "- مصروفات العميل وأهدافه (family.mine): بالتفصيل.\n"
    + "- أي فرد تاني: الاسم والدور بس. ماتقولش رصيده ولا مصروفه ولا هدفه ولا بنوده، ولا تقارن بينه وبين حد.\n"
    + "- من أرقام البيت قول إجمالي ميزانية البيت والمهام والأهداف المشتركة بس.\n"
    + "- تفاصيل فرد تاني بتتقال لو هو شاركها صراحة (من نتيجة أداة العيلة بس)؛ غير كده اعتذر بلطف.\n"
    + "=== نهاية ===\n";
}
