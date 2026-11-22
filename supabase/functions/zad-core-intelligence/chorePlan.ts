// م٥.٢: action=chore_plan — التطبيق بيطلب توزيع المهام المفتوحة على أفراد العيلة. حساب بس، من غير كتابة:
// التطبيق بيعرضه، والأدمن بيطبّقه بـzad_apply_chore_plan (تحت RLS وتريجر family_chores).
// الحساب في `_shared/choreDistribution.ts` (Hungarian في جولات).

import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.45.6";
import { DEFAULT_WEEK_MINUTES, distributeChores, type MemberRow } from "../_shared/choreDistribution.ts";

type Row = Record<string, unknown>;

export async function chorePlan(sb: SupabaseClient, callerId: string, familyId: unknown): Promise<{ status: number; body: Row }> {
  const fam = typeof familyId === "string" && /^[0-9a-f-]{36}$/i.test(familyId) ? familyId : null;
  if (!fam) return { status: 400, body: { ok: false, reason: "bad_family" } };

  const { data: members, error: memErr } = await sb.from("family_members")
    .select("id,user_id,alias,role").eq("family_id", fam).limit(30);
  if (memErr) return { status: 500, body: { ok: false, reason: "read_failed" } };
  const rows = (members ?? []) as Array<{ id: string; user_id: string | null; alias: string | null; role: string | null }>;
  // الفحص بالتوكن، مش بـfamily_id اللي جاي من العميل: لازم يكون فرد في العيلة دي.
  if (!rows.some((m) => m.user_id === callerId)) return { status: 403, body: { ok: false, reason: "not_in_family" } };

  const [{ data: chores, error: choreErr }, { data: prefs, error: prefErr }] = await Promise.all([
    sb.from("family_chores").select("id,title,minutes").eq("family_id", fam).eq("is_completed", false).limit(100),
    sb.from("family_chore_preferences").select("member_id,minutes_per_week,dislikes,likes").eq("family_id", fam),
  ]);
  if (choreErr || prefErr) return { status: 500, body: { ok: false, reason: "read_failed" } };

  const prefOf = new Map(((prefs ?? []) as Row[]).map((p) => [String(p.member_id), p]));
  const memberRows: MemberRow[] = rows.map((m) => {
    const p = prefOf.get(m.id);
    return {
      id: m.id, name: m.alias ?? "",
      minutesPerWeek: p ? Number(p.minutes_per_week) : null,
      dislikes: Array.isArray(p?.dislikes) ? (p!.dislikes as string[]) : [],
      likes: Array.isArray(p?.likes) ? (p!.likes as string[]) : [],
    };
  });
  const choreRows = ((chores ?? []) as Array<{ id: string; title: string | null; minutes: number | null }>)
    .map((c) => ({ id: c.id, title: c.title ?? "", minutes: c.minutes }));
  const plan = distributeChores(choreRows, memberRows);
  const title = new Map(choreRows.map((c) => [c.id, c.title]));
  const name = new Map(memberRows.map((m) => [m.id, m.name]));

  return {
    status: 200,
    body: {
      ok: true,
      assignments: plan.assignments.map((a) => ({
        chore_id: a.choreId, member_id: a.memberId, minutes: a.minutes, title: title.get(a.choreId), member_name: name.get(a.memberId),
      })),
      unassigned: plan.unassigned.map((id) => ({ chore_id: id, title: title.get(id) })),
      load: memberRows.map((m) => ({
        member_id: m.id, member_name: m.name, minutes: plan.load[m.id] ?? 0, week: m.minutesPerWeek ?? DEFAULT_WEEK_MINUTES,
      })),
    },
  };
}
