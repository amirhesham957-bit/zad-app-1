// م٨.٢/م٨.٥: تغذية مكافأة الـbandit. خلف ZAD_BANDIT_TONE (مقفول = ولا قراية ولا كتابة).
// الإشارة الوحيدة المتاحة: الإشعار اتفتح (app_notifications.is_read=true، العميل بيحطها بلمسة).
// فتح = نجاح للقالب اللي اتعرض. مفيش فتح = مفيش تحديث (مش فشل). الكتابة بـrpc (security definer) بس.
// برا: الحارة الحرجة، الطفل، أقل من ١٨، وحساب فيه أكتر من فرد (الرسالة للحساب مش لفرد معروف).

import { isMinor as isMinorByAge } from "../_shared/or/banditTone.ts";
import { CRITICAL_KINDS } from "./banditWiring.ts";

export interface HouseholdMemberRow {
  id: string;
  kind: string;
  birth_year?: number | null;
  archived_at?: string | null;
}

export interface ShownChoice {
  memberId: string;
  kind: string;
  arm: string;
}

/** الفرد المعروف الوحيد في الحساب (صف self ومعاه مفيش حد تاني شغّال)، وإلا null = غامض. */
export function unambiguousMember(members: HouseholdMemberRow[]): HouseholdMemberRow | null {
  const active = members.filter((m) => !m.archived_at);
  if (active.length !== 1 || active[0].kind !== "self") return null;
  return active[0];
}

/** يستاهل مكافأة؟ نوع مش حرج، مش طفل، ومش أقل من ١٨. */
export function rewardEligible(
  kind: string,
  member: HouseholdMemberRow,
  accountHasChild: boolean,
  nowYear = new Date().getUTCFullYear(),
): boolean {
  if (!kind || CRITICAL_KINDS.has(kind)) return false;
  if (accountHasChild || member.kind === "child") return false;
  const age = typeof member.birth_year === "number" ? nowYear - member.birth_year : null;
  return !isMinorByAge({ memberId: member.id, age });
}

/** بعد ما الإشعار اتحط: سجّل القالب اللي اتعرض. أي فشل بيتبلع (الإشعار أهم). */
export async function noteShown(sb: any, userId: string, notificationId: string, choice: ShownChoice): Promise<boolean> {
  try {
    const { data, error } = await sb.rpc("zad_bandit_note_shown", {
      p_user: userId,
      p_member: choice.memberId,
      p_notification: notificationId,
      p_kind: choice.kind,
      p_arm: choice.arm,
    });
    return !error && data === true;
  } catch {
    return false;
  }
}

const OPEN_WINDOW_MS = 7 * 24 * 3600 * 1000;
const SWEEP_LIMIT = 50;

/**
 * يمرّ على الإشعارات المعروضة ولسه مااتحسبتش، وللي اتفتح منها يديها مكافأة. [enabled] مقفول = صفر.
 * مابيرميش أبداً: أي خطأ = بيتخطى.
 */
export async function settleOpenedNotifications(
  sb: any,
  enabled: boolean,
  now = Date.now(),
): Promise<{ rewarded: number; skipped: number }> {
  const out = { rewarded: 0, skipped: 0 };
  if (!enabled) return out;
  try {
    const { data: shown } = await sb.from("zad_bandit_shown")
      .select("notification_id,user_id,member_id,kind,arm")
      .is("settled_at", null)
      .gte("shown_at", new Date(now - OPEN_WINDOW_MS).toISOString())
      .order("shown_at", { ascending: true })
      .limit(SWEEP_LIMIT);
    const rows = (shown ?? []) as Array<{ notification_id: string; user_id: string; member_id: string; kind: string; arm: string }>;
    if (rows.length === 0) return out;
    const users = [...new Set(rows.map((r) => r.user_id))];
    const [{ data: notifs }, { data: mem }, { data: kids }] = await Promise.all([
      sb.from("app_notifications").select("id,is_read").in("id", rows.map((r) => r.notification_id)),
      sb.from("zad_household_members").select("id,user_id,kind,birth_year,archived_at").in("user_id", users),
      sb.from("family_members").select("user_id").eq("role", "child").in("user_id", users),
    ]);
    const read = new Set(
      ((notifs ?? []) as Array<{ id: string; is_read: boolean | null }>).filter((n) => n.is_read === true).map((n) => n.id),
    );
    const byUser = new Map<string, HouseholdMemberRow[]>();
    for (const m of (mem ?? []) as Array<HouseholdMemberRow & { user_id: string }>) {
      byUser.set(m.user_id, [...(byUser.get(m.user_id) ?? []), m]);
    }
    const withChild = new Set(((kids ?? []) as Array<{ user_id: string }>).map((k) => k.user_id));
    for (const r of rows) {
      if (!read.has(r.notification_id)) continue; // مافيش إشارة: مفيش تحديث
      const only = unambiguousMember(byUser.get(r.user_id) ?? []);
      if (!only || only.id !== r.member_id || !rewardEligible(r.kind, only, withChild.has(r.user_id))) {
        out.skipped++;
        continue;
      }
      const { data, error } = await sb.rpc("zad_bandit_settle_read", { p_user: r.user_id, p_notification: r.notification_id });
      if (!error && data === true) out.rewarded++;
      else out.skipped++;
    }
  } catch (e) {
    console.error("[bandit_reward] sweep failed:", (e as Error)?.message ?? e);
  }
  return out;
}

const FAILURE_AFTER_MS = 24 * 3600 * 1000;

/**
 * قاعدة الفشل: إشعار معروض من أكتر من ٢٤ ساعة ولسه غير مقروء ومااتحسبش = فشل للقالب (reward 0، failures+1).
 * الدالة في الداتابيز بتتأكد تاني من العمر وis_read، وبتقفل الصف فقراية متأخرة مابتكافئش. [enabled] مقفول = صفر.
 * نفس الاستثناءات بتاعة المكافأة. مابيرميش أبداً.
 */
export async function settleIgnoredNotifications(
  sb: any,
  enabled: boolean,
  now = Date.now(),
): Promise<{ failed: number; skipped: number }> {
  const out = { failed: 0, skipped: 0 };
  if (!enabled) return out;
  try {
    const { data: shown } = await sb.from("zad_bandit_shown")
      .select("notification_id,user_id,member_id,kind,arm")
      .is("settled_at", null)
      .lte("shown_at", new Date(now - FAILURE_AFTER_MS).toISOString())
      .gte("shown_at", new Date(now - OPEN_WINDOW_MS).toISOString())
      .order("shown_at", { ascending: true })
      .limit(SWEEP_LIMIT);
    const rows = (shown ?? []) as Array<{ notification_id: string; user_id: string; member_id: string; kind: string; arm: string }>;
    if (rows.length === 0) return out;
    const users = [...new Set(rows.map((r) => r.user_id))];
    const [{ data: notifs }, { data: mem }, { data: kids }] = await Promise.all([
      sb.from("app_notifications").select("id,is_read").in("id", rows.map((r) => r.notification_id)),
      sb.from("zad_household_members").select("id,user_id,kind,birth_year,archived_at").in("user_id", users),
      sb.from("family_members").select("user_id").eq("role", "child").in("user_id", users),
    ]);
    const unread = new Set(
      ((notifs ?? []) as Array<{ id: string; is_read: boolean | null }>).filter((n) => n.is_read === false).map((n) => n.id),
    );
    const byUser = new Map<string, HouseholdMemberRow[]>();
    for (const m of (mem ?? []) as Array<HouseholdMemberRow & { user_id: string }>) {
      byUser.set(m.user_id, [...(byUser.get(m.user_id) ?? []), m]);
    }
    const withChild = new Set(((kids ?? []) as Array<{ user_id: string }>).map((k) => k.user_id));
    for (const r of rows) {
      if (!unread.has(r.notification_id)) continue; // اتقرا (المكافأة بتتولاه) أو اتمسح: مفيش فشل
      const only = unambiguousMember(byUser.get(r.user_id) ?? []);
      if (!only || only.id !== r.member_id || !rewardEligible(r.kind, only, withChild.has(r.user_id))) {
        out.skipped++;
        continue;
      }
      const { data, error } = await sb.rpc("zad_bandit_settle_failure", { p_user: r.user_id, p_notification: r.notification_id });
      if (!error && data === true) out.failed++;
      else out.skipped++;
    }
  } catch (e) {
    console.error("[bandit_failure] sweep failed:", (e as Error)?.message ?? e);
  }
  return out;
}
