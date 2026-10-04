// engagement.ts — زاد بيتعلم من رد فعل العميل الصامت (ZAD_LIVING_BRAIN.md الشريحة ١٤).
//
// المالك (٢٠٢٦-١٠-٠٤): «يقيس رد فعلك تجاه اقتراحاته (تجاهل، فتح، تعديل): يقلل في اللي بتتجاهله، ويبادر
// أكتر في اللي بتوافق عليه». الرفض الصريح كان ليه حارس (dismissed_keys، وتسوية الكاش بتقف بعد رفضين)؛
// التجاهل الصامت مالوش: «بيتادرم قرب يخلص» اتبعت ٥ أيام ورا بعض (٢٩/٩ → ٣/١٠) والخمسة لسه pending
// (مقاس على الحي ٢٠٢٦-١٠-٠٤)، كل يوم بمفتاح جديد بتاريخه فمنع التكرار مامسكهوش.
//
// الموضوع = dedupe_key من غير التاريخ والأرقام والهاش («betaderm_low_stock_2026_09_30» و
// «betaderm_low_20261003» ⇒ «betaderm_low»). رؤية فضلت pending/seen أكتر من ٤٨ ساعة = اتجاهلت. ٣ تجاهلات
// ورا بعض في نفس الموضوع (آخر ٢١ يوم) ⇒ «ساكت»: emit_insight/ask_user بيترفضوا فيه إلا الحرج
// (validators.ts). العميل يتصرف في واحدة ⇒ السلسلة بتتكسر. وبعد ٢١ يوم القديم بيخرج من الحساب
// لوحده. اللي بيتعمل بيه دايماً ⇒ «مرحّب بيه»: العقل يقدر يبادر فيه أكتر — في الاقتراح بس؛ أدوات
// الفلوس بتفضل بتأكيد العميل زي ما هي.

const HOUR_MS = 3_600_000;
export const ENGAGEMENT_WINDOW_DAYS = 21;
/** وقت كفاية يرد فيه قبل ما نعدّها تجاهل. */
export const REACTION_GRACE_MS = 48 * HOUR_MS;
export const QUIET_AFTER_IGNORED = 3;

export interface InsightRow {
  dedupe_key: string | null;
  title?: string | null;
  status: string | null;
  created_at: string;
}

export interface Engagement {
  /** مواضيع اتجاهلت ٣ مرات ورا بعض — ماتتبعتش تاني إلا الحرج. */
  quiet_topics: Array<{ topic: string; ignored_in_a_row: number; last_title: string | null }>;
  /** مواضيع العميل بيتعامل معاها (مرتين على الأقل، ٦٠٪ أو أكتر). */
  welcomed_topics: string[];
}

const MONTHS = "jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec";

/** الموضوع من غير التاريخ والأرقام والهاش واللواحق اللي الموديل بيبدّل فيها. */
export function insightTopic(dedupeKey: string | null | undefined): string {
  let k = String(dedupeKey ?? "").toLowerCase().trim();
  k = k
    .replace(/_?\d{4}[_-]\d{2}[_-]\d{2}/g, "") // 2026_09_30
    .replace(/_?\d{4}[_-]?w\d{1,2}/g, "") // 2026_w40
    .replace(/_?\d{6,8}\b/g, "") // 20261003
    .replace(new RegExp(`_(?:${MONTHS})[a-z]*_?\\d{0,2}\\b`, "g"), "") // oct3, aug_2026 (بعد شيل السنة)
    .replace(/_[0-9a-f]{12,}\b/g, "") // هاش
    .replace(/_\d+\b/g, "") // _16
    .replace(/_(?:stock|alert|warning|reminder|notice|nudge)\b/g, "")
    .replace(/_+/g, "_")
    .replace(/^_|_$/g, "");
  return k || "other";
}

export function engagementFrom(rows: readonly InsightRow[], now = Date.now()): Engagement {
  const since = now - ENGAGEMENT_WINDOW_DAYS * 24 * HOUR_MS;
  const byTopic = new Map<string, InsightRow[]>();
  for (const r of rows) {
    const at = Date.parse(r.created_at);
    // مفتاح فيه «:» (txn_confirmed:<id>) إيصال من النظام مش اقتراح من العقل — مفاتيح العقل حروف
    // وأرقام و_ بس (DEDUPE_KEY_RE في validators.ts).
    if (!Number.isFinite(at) || at < since || !r.dedupe_key || r.dedupe_key.includes(":")) continue;
    const topic = insightTopic(r.dedupe_key);
    byTopic.set(topic, [...(byTopic.get(topic) ?? []), r]);
  }
  const quiet: Engagement["quiet_topics"] = [];
  const welcomed: string[] = [];
  for (const [topic, list] of byTopic) {
    const newest = [...list].sort((a, b) => Date.parse(b.created_at) - Date.parse(a.created_at));
    let ignored = 0;
    for (const r of newest) {
      const status = r.status ?? "";
      if (status === "acted" || status === "dismissed") break;
      // لسه في مهلة الرد: مش تجاهل ولا تفاعل.
      if (now - Date.parse(r.created_at) < REACTION_GRACE_MS) continue;
      if (status === "pending" || status === "seen") ignored++;
    }
    if (ignored >= QUIET_AFTER_IGNORED) {
      quiet.push({ topic, ignored_in_a_row: ignored, last_title: newest[0]?.title ?? null });
    }
    const acted = list.filter((r) => r.status === "acted").length;
    if (acted >= 2 && acted / list.length >= 0.6) welcomed.push(topic);
  }
  return { quiet_topics: quiet, welcomed_topics: welcomed };
}

/** null = مسموح؛ وإلا سبب الرفض للموديل. الحرج دايماً بيعدّي. */
export function quietTopicRejection(
  input: { dedupe_key?: string | null; priority?: string | null },
  engagement: Engagement | null | undefined,
): string | null {
  if (!engagement || input.priority === "critical") return null;
  const topic = insightTopic(input.dedupe_key);
  const hit = engagement.quiet_topics.find((q) => q.topic === topic);
  if (!hit) return null;
  return `العميل تجاهل آخر ${hit.ignored_in_a_row} تنبيهات عن الموضوع ده («${hit.last_title ?? topic}») — ماتبعتش تاني ` +
    "إلا لو بقى حرج؛ لو مهم اتكلم عنه مرة في الشات لما يجي سياقه.";
}
