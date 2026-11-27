// م٤.٥ تمريرة ٣ج: جولة العيلة من buildSnapshot (نقل صافي، بدون تغيير سلوك). الكود بالحرف من index.ts؛
// الداتا بتتمرر كـparams: العضوية (famRes)، ومصفوفة dataErrors بتتعدّل بالـpush زي ما كانت، وSOURCE_LABELS.

import { sharedFromCurrentMembers } from "./familyShare.ts";
import { markOwn } from "./familyPersona.ts";
import { type PollMember, type PollRow, type PollSummary, pollSummaries } from "./familyPolls.ts";
import { familyChat, kidsPlaces } from "./snapshotFields.ts";
import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";

/** صف ذاكرة زي ما zad_memory_live_notes / zad_memory_recall_entities بيرجّعوه. */
export type MemoryRow = {
  id: string; scope: string; note: string; confidence: number; evidence_count: number;
  last_seen: string | null; valid_until?: string | null; about?: string[] | null;
  /** ١٠.٢(ج): ملاحظة شاركها فرد تاني في العيلة — اسمه، و«العميل» فيها = هو. */
  shared_by?: string;
  /** م٩.٢ (20261122150000): العادة متوقفة لحد، والفرد اللي الحقيقة عنه. */
  paused_until?: string | null; member?: string | null;
};

export async function buildFamilySnapshot(
  sb: SupabaseClient,
  userId: string,
  famRes: { data: unknown },
  dataErrors: Array<{ source: string }>,
  SOURCE_LABELS: Record<string, string>,
) {
  // ─── جولة العيلة: المهام والأهداف والتسبيحة كلها family-scoped ───
  // الموديل لازم يشوفها دايمًا (مش بس لما يسأل query_family) عشان يتابع أطفال
  // العميل ومهامهم وأشجارهم بنفسه. لو مفيش عيلة → family block بيبقى null ببساطة.
  const famMembership = (famRes.data ?? null) as { family_id: string; role: string; alias: string; balance: number; savings_goal: number; daily_limit: number | null; weekly_limit: number | null; last_seen_at: string | null } | null;
  let family: {
    mine: { role: string; alias: string; balance: number; savings_goal: number };
    members: Array<{ alias: string; role: string; balance: number; savings_goal: number; online_now: boolean }>;
    chores: Array<{ title: string; due: string | null; reward: number; done: boolean }>;
    goals: Array<{ target: number; current: number; month: string; reward: string | null }>;
    tasbiha: Array<{ name: string; level: number; score: number; clicks: number; streak: number; mature: boolean }>;
  } | null = null;
  // بند 34.2 — ملاحظات شاركها فرد تاني في العيلة (remember(share_with_family=true)).
  // مستبعد ملاحظات العميل نفسه (neq user_id) عشان ما تتكررش — دي أصلاً بترجع من
  // memRes العادية تحت.
  let familySharedMemory: MemoryRow[] = [];
  let familyPollList: PollSummary[] = [];
  if (famMembership?.family_id) {
    const familyId = famMembership.family_id;
    const [membersRes, choresRes, goalsRes, tasRes, sharedMemRes, kidsPlacesRes, familyChatRes] = await Promise.all([
      sb.from("family_members").select("role,alias,balance,savings_goal,last_seen_at").eq("family_id", familyId).limit(20),
      sb.from("family_chores").select("title,assigned_to,due_date,reward_amount,is_completed")
        .eq("family_id", familyId).order("created_at", { ascending: false }).limit(40),
      sb.from("family_goals").select("target_amount,current_amount,month_year,reward_suggestion")
        .eq("family_id", familyId).order("created_at", { ascending: false }).limit(12),
      sb.from("family_tasbiha").select("user_id,tree_name,level,score,total_clicks,streak_days,is_mature,last_tasbih_at")
        .eq("family_id", familyId).order("last_tasbih_at", { ascending: false, nullsFirst: false }).limit(10),
      sb.from("zad_memory").select("id,user_id,scope,note,confidence,evidence_count,last_seen,valid_until")
        .eq("family_id", familyId).neq("user_id", userId)
        .is("superseded_by", null).or(`valid_until.is.null,valid_until.gt.${new Date().toISOString()}`)
        .limit(20),
      // «الولد فين؟» — نطاقات الأولاد اللي وافقوا (20261003110000): آخر دخول/خروج بس، مش مكان.
      sb.rpc("zad_family_zone_status", { p_viewer: userId }),
      // شات العيلة (20261003120000): آخر ٢٤ ساعة من اللي وافقوا إن زاد يقرا رسايلهم بس.
      sb.rpc("zad_family_chat_for_brain", { p_viewer: userId }),
    ]);
    // تصويت العيلة: صفوف التصويت، والأفراد بمعرّفاتهم (الأصوات بالمعرّف)، ومين موافق إن زاد يقرا رسايله.
    const [pollRowsRes, pollMembersRes, pollConsentRes] = await Promise.all([
      sb.from("chat_messages").select("id,sender_id,metadata,created_at")
        .eq("family_id", familyId).eq("message_type", "POLL")
        .gte("created_at", new Date(Date.now() - 14 * 86_400_000).toISOString())
        .order("created_at", { ascending: false }).limit(8),
      sb.from("family_members").select("id,alias,user_id,role").eq("family_id", familyId).limit(20),
      sb.from("zad_family_chat_consent").select("user_id").eq("family_id", familyId),
    ]);
    // ١٠.٢(ج): ملاحظة متشاركة بتبان بس لو كاتبها لسه في العيلة (الخروج = الموافقة خلصت؛ نفس شرط السياسة
    // family_shared_memory_select في 20261113060000). الأفراد ماتقروش ⇒ ولا ملاحظة.
    familySharedMemory = sharedFromCurrentMembers(
      (sharedMemRes.data ?? []) as Array<MemoryRow & { user_id?: string }>,
      pollMembersRes.error ? null : (pollMembersRes.data ?? []) as Array<{ user_id?: string | null; alias?: string | null }>,
    );
    familyPollList = pollRowsRes.error ? [] : pollSummaries({
      rows: (pollRowsRes.data ?? []) as PollRow[],
      members: (pollMembersRes.data ?? []) as PollMember[],
      me: userId,
      consentingUserIds: new Set(((pollConsentRes.data ?? []) as Array<{ user_id: string }>).map((c) => c.user_id)),
    });
    for (const [name, res] of [["family_chores", choresRes], ["family_goals", goalsRes], ["family_tasbiha", tasRes]] as const) {
      const err = (res as any)?.error;
      if (err) {
        console.error(`[zad-brain] SNAPSHOT SOURCE FAILED: ${name} — ${String((err as any).message ?? err)}`);
        dataErrors.push({ source: SOURCE_LABELS[name] ?? name });
      }
    }
    const isOnline = (ls: string | null) => {
      if (!ls) return false;
      const t = Date.parse(ls);
      return Number.isFinite(t) && (Date.now() - t) < 5 * 60000;
    };
    family = {
      mine: {
        role: famMembership.role, alias: famMembership.alias,
        balance: famMembership.balance ?? 0, savings_goal: famMembership.savings_goal ?? 0,
      },
      members: ((membersRes.data ?? []) as any[]).map((m) => ({
        alias: m.alias ?? "", role: m.role ?? "member",
        balance: m.balance ?? 0, savings_goal: m.savings_goal ?? 0, online_now: isOnline(m.last_seen_at),
      })),
      chores: ((choresRes.data ?? []) as any[]).map((c) => ({
        title: c.title, due: c.due_date ?? null, reward: c.reward_amount ?? 0, done: !!c.is_completed,
      })),
      goals: ((goalsRes.data ?? []) as any[]).map((g) => ({
        target: g.target_amount ?? 0, current: g.current_amount ?? 0,
        month: g.month_year ?? "", reward: g.reward_suggestion ?? null,
      })),
      tasbiha: ((tasRes.data ?? []) as any[]).map((t) => markOwn({
        name: t.tree_name ?? "", level: t.level ?? 1, score: t.score ?? 0,
        clicks: t.total_clicks ?? 0, streak: t.streak_days ?? 0, mature: !!t.is_mature,
      }, t.user_id === userId)),
      ...kidsPlaces(kidsPlacesRes),
      ...familyChat(familyChatRes),
      // تصويت العيلة (familyPolls.ts، 20261004130000): المفتوح واللي اتقفل آخر ١٤ يوم.
      ...(familyPollList.length ? { polls: familyPollList } : {}),
    };
  }

  return { family, familySharedMemory, familyPollList };
}
