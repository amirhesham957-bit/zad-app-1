// منسّق الرسايل (ZAD_DREAM_PLAN.md، طلب المالك ٢٠٢٦-١٠-١٧: «بيبعت كل حاجة مرة واحدة زي الآلة»):
// ذاكرة واحدة لكل اللي طلع للعميل، مهما كان اللي بعته. قبل كده كل مُرسِل كان بيبعّد رسايله عن
// نفسه بس: اللحظات الصوتية عن اللحظات، مهام العقل عن المهام، وسؤال المخزون مابيشوفش حد — فجرعة
// ٩ بالليل وسؤال المخزون كانوا بيوصلوا في نفس الدقيقة ٨ ليالي من ١٤.
//
// المصادر الثلاثة:
//   zad_voice_moments  status=sent        → kind «moment:<اسم اللحظة>»، at = sent_at
//   agent_tasks        مبادرة اتبعتت       → kind النوع نفسه، at = updated_at (وقت الإرسال)
//   telegram_checkin_prompts               → kind «checkin»، at = sent_at

// deno-lint-ignore no-explicit-any
type Sb = any;

export interface Outbound {
  kind: string;
  at: string;
}

/**
 * اللي اتبعت للعميل من [sinceIso]. [skipMoments] = لحظات مابتتعدّش (ردود الشات الصوتية مثلاً —
 * العميل هو اللي سأل). مهام العميل نفسه (`reminder`) مابتتعدّش: ردود على طلبه مش مبادرات.
 * قراية فاشلة بترجع اللي اتقرا بس، ومابترميش — عمرها ما توقف رسالة.
 */
export async function recentOutbound(
  sb: Sb,
  userId: string,
  sinceIso: string,
  skipMoments: readonly string[] = [],
): Promise<Outbound[]> {
  const skip = new Set(skipMoments);
  // كل قراية لوحدها: مصدر واقع (حتى لو رمى على طول) مايمسحش التانيين، ومايرميش للمنادي.
  const read = async (q: () => PromiseLike<{ data?: unknown }>) => {
    try {
      return await q();
    } catch {
      return { data: [] };
    }
  };
  const [moments, tasks, checkins] = await Promise.all([
    read(() => sb.from("zad_voice_moments").select("moment,sent_at")
      .eq("user_id", userId).eq("status", "sent").gte("sent_at", sinceIso)),
    read(() => sb.from("agent_tasks").select("kind,updated_at")
      .eq("user_id", userId).in("status", ["done", "done_with_issue"]).gte("updated_at", sinceIso)),
    read(() => sb.from("telegram_checkin_prompts").select("sent_at")
      .eq("user_id", userId).gte("sent_at", sinceIso)),
  ]);
  const out: Outbound[] = [];
  for (const m of (moments?.data ?? []) as Array<{ moment: string; sent_at: string | null }>) {
    if (m.sent_at && !skip.has(m.moment)) out.push({ kind: `moment:${m.moment}`, at: m.sent_at });
  }
  for (const t of (tasks?.data ?? []) as Array<{ kind: string | null; updated_at: string | null }>) {
    const k = (t.kind ?? "").trim();
    if (t.updated_at && k !== "" && k !== "reminder") out.push({ kind: k, at: t.updated_at });
  }
  for (const c of (checkins?.data ?? []) as Array<{ sent_at: string | null }>) {
    if (c.sent_at) out.push({ kind: "checkin", at: c.sent_at });
  }
  return out;
}

/** آخر رسالة في [rows]، أو null. */
export function latestOutboundMs(rows: readonly Outbound[]): number | null {
  let latest: number | null = null;
  for (const r of rows) {
    const t = Date.parse(r.at);
    if (Number.isFinite(t) && (latest === null || t > latest)) latest = t;
  }
  return latest;
}
