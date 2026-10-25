// يتعلم من النتيجة (ZAD_PLAN ٣.٦): لكل بيت ولكل نوع مبادرة — اتبعت كام، اترد كام، اتعمل بيه كام.
//
// المصدر zad_guardian_outcomes (20261011230000 / 20261019100000): كل مبادرة اتبعتت بيتحكم عليها بعد ٢٤ ساعة
// (رد خلال يوم، فعل خلال ساعتين، رفض صريح). zad_kind_outcomes بيجمعهم لكل نوع لبيت واحد.
//
//   • نوع اتبعت LEARN_MIN_SENT مرة أو أكتر واتعمل بيه أقل من LEARN_QUIET_PCT٪ ⇒ «بيتهدّى» للبيت ده لوحده:
//     مرة كل LEARNED_QUIET_GAP_DAYS يوم بالكتير، والتأجيل بيتسجل بسببه (learned_quiet، «اللي سكتّ عنه»).
//     مش كتم: لو العميل رجع يتعامل معاه النسبة بتطلع والهدوء بيتشال لوحده.
//   • نوع اتبعت LEARN_WELCOME_MIN مرة أو أكتر واتعمل بيه LEARN_WELCOME_PCT٪ أو أكتر ⇒ «بينجح»: بياخد الخانة
//     قبل اللي في نفس أهميته لما السقف يتزحم.
// الحارة الحرجة برّه ده كله: المعالج بيسأل بس عن المبادرات (agentTaskNotice.proactive).

export const LEARN_WINDOW_DAYS = 60;
export const LEARN_MIN_SENT = 10;
export const LEARN_QUIET_PCT = 10;
export const LEARN_WELCOME_MIN = 5;
export const LEARN_WELCOME_PCT = 50;
export const LEARNED_QUIET_GAP_DAYS = 7;

export interface KindOutcome {
  kind: string;
  sent: number;
  replied: number;
  acted: number;
  dismissed: number;
  last_at: string | null;
}

export type Stance = "quiet" | "welcomed" | "normal";

/** «اتعمل بيه» = فعل خلال ساعتين من غير رفض صريح (zad_kind_outcomes بيحسبه كده). */
export function stanceOf(o: KindOutcome | null | undefined): Stance {
  if (!o || !(o.sent > 0)) return "normal";
  const pct = (100 * o.acted) / o.sent;
  if (o.sent >= LEARN_MIN_SENT && pct < LEARN_QUIET_PCT) return "quiet";
  if (o.sent >= LEARN_WELCOME_MIN && pct >= LEARN_WELCOME_PCT) return "welcomed";
  return "normal";
}

/** ترتيب الخانات: الناجح قبل اللي في نفس أهميته، والهادي بعده. الأهمية نفسها مابتتغيرش. */
export function learnedPriority(base: number, stance: Stance): number {
  // ربع درجة بس: عمرها ما توصّل نوع لأهمية اللي جنبه (الأهميات أرقام صحيحة).
  return base + (stance === "welcomed" ? -0.25 : stance === "quiet" ? 0.25 : 0);
}

/**
 * نوع هادي اتبعت من أقل من LEARNED_QUIET_GAP_DAYS ⇒ يستنى لحد ما الأسبوع يكمل (ISO)، وإلا null.
 * [lastSentMs] = آخر مرة النوع ده وصل البيت ده (المحكوم عليه أو اللي لسه طالع النهارده).
 */
export function learnedQuietUntil(stance: Stance, lastSentMs: number | null, nowMs: number): string | null {
  if (stance !== "quiet" || lastSentMs === null || !Number.isFinite(lastSentMs)) return null;
  const next = lastSentMs + LEARNED_QUIET_GAP_DAYS * 86_400_000;
  return next > nowMs ? new Date(next).toISOString() : null;
}

/** صفوف zad_kind_outcomes ⇒ خريطة بالنوع. الأرقام بتتقري كأرقام حتى لو جت نص. */
export function outcomesByKind(rows: ReadonlyArray<Record<string, unknown>> | null | undefined): Map<string, KindOutcome> {
  const map = new Map<string, KindOutcome>();
  for (const r of rows ?? []) {
    const kind = String(r.kind ?? "").trim();
    if (!kind) continue;
    map.set(kind, {
      kind,
      sent: Number(r.sent) || 0,
      replied: Number(r.replied) || 0,
      acted: Number(r.acted) || 0,
      dismissed: Number(r.dismissed) || 0,
      last_at: typeof r.last_at === "string" ? r.last_at : null,
    });
  }
  return map;
}
