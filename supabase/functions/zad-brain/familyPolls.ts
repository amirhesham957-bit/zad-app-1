// familyPolls.ts — تصويت العيلة في عقل زاد (ZAD_LIVING_BRAIN.md الشريحة ٢٤).
//
// التصويت في الشات (رسالة POLL) والصوت من zad_family_poll_vote والقفل من zad_family_poll_close
// (20261004130000). هنا: (١) ملخص التصويتات المفتوحة واللي اتقفلت قريب للسناب شوت — السؤال، العدّ، صوتك،
// مين لسه ماصوّتش، والنتيجة؛ (٢) شكل تصويت جديد صحيح لأداة start_family_poll (نفس حدود السيرفر).
//
// الموافقة (الشريحة ٣): تصويت فتحه فرد بيدخل العقل بس لو صاحبه موافق إن زاد يقرا رسايله؛ تصويت زاد نفسه دايماً.
// الأصوات نفسها (مين اختار إيه) بتتلخص أعداد — اللي العيلة شايفاه أصلاً في الشات.

export interface PollRow {
  id: string;
  sender_id: string | null;
  metadata: string | null;
  created_at: string;
}

export interface PollMember {
  id: string;
  alias: string | null;
  user_id: string | null;
  role: string | null;
}

export interface PollSummary {
  id: string;
  question: string;
  options: Array<{ text: string; votes: number }>;
  by: string;
  my_vote: number | null;
  waiting_for: string[];
  closes_at: string | null;
  closed: boolean;
  winner: string | null;
  consensus: boolean;
}

export function pollSummaries(input: {
  rows: readonly PollRow[];
  members: readonly PollMember[];
  me: string;
  consentingUserIds: ReadonlySet<string>;
}): PollSummary[] {
  const byId = new Map(input.members.map((m) => [m.id, m]));
  const mine = input.members.find((m) => m.user_id === input.me)?.id ?? null;
  const out: PollSummary[] = [];
  for (const r of input.rows) {
    const sender = r.sender_id === "zad_ai" ? null : byId.get(r.sender_id ?? "");
    if (r.sender_id !== "zad_ai" && !(sender?.user_id && input.consentingUserIds.has(sender.user_id))) continue;
    let meta: Record<string, unknown>;
    try {
      meta = JSON.parse(r.metadata ?? "{}");
    } catch {
      continue;
    }
    const options = Array.isArray(meta.options) ? (meta.options as unknown[]).map((o) => String(o)) : [];
    const question = String(meta.question ?? "").trim();
    if (!question || options.length < 2) continue;
    const votes = (meta.votes && typeof meta.votes === "object" ? meta.votes : {}) as Record<string, unknown>;
    const counts = options.map(() => 0);
    for (const [member, v] of Object.entries(votes)) {
      const i = Number(v);
      if (byId.has(member) && Number.isInteger(i) && i >= 0 && i < options.length) counts[i]++;
    }
    const result = (meta.result && typeof meta.result === "object" ? meta.result : {}) as Record<string, unknown>;
    const winner = Number.isInteger(result.winner) ? options[result.winner as number] ?? null : null;
    out.push({
      id: r.id,
      question: question.slice(0, 200),
      options: options.map((text, i) => ({ text: text.slice(0, 60), votes: counts[i] })),
      by: r.sender_id === "zad_ai" ? "زاد" : (sender?.alias ?? "حد من العيلة"),
      my_vote: mine && Number.isInteger(Number(votes[mine])) ? Number(votes[mine]) : null,
      waiting_for: meta.closed === true ? [] : input.members
        .filter((m) => !(m.id in votes) && m.alias)
        .map((m) => m.alias as string),
      closes_at: typeof meta.closes_at === "string" ? meta.closes_at : null,
      closed: meta.closed === true,
      winner,
      consensus: result.consensus === true,
    });
  }
  return out.slice(0, 5);
}

/** شكل تصويت جديد لأداة start_family_poll — نفس zad_family_poll_shape_ok. null = مش صحيح. */
export function newPollMetadata(
  input: { question?: unknown; options?: unknown; closes_in_hours?: unknown },
  now = Date.now(),
): { question: string; options: string[]; votes: Record<string, never>; closes_at: string } | null {
  const question = typeof input.question === "string" ? input.question.replace(/\s+/g, " ").trim() : "";
  if (question.length < 1 || question.length > 200) return null;
  const options = (Array.isArray(input.options) ? input.options : [])
    .map((o) => (typeof o === "string" ? o.replace(/\s+/g, " ").trim() : ""))
    .filter((o) => o.length >= 1 && o.length <= 60);
  const unique = [...new Set(options)];
  if (unique.length < 2 || unique.length > 6) return null;
  const hours = Number(input.closes_in_hours);
  const h = Number.isFinite(hours) && hours >= 1 ? Math.min(Math.round(hours), 24 * 14) : 48;
  return { question, options: unique, votes: {}, closes_at: new Date(now + h * 3_600_000).toISOString() };
}
