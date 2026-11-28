export const MIN_DAYS_BETWEEN_QUESTIONS = 7;

export interface CheckInCandidate {
  itemId: string;
  rate: number;
  low: number;
  high: number;
  onHand: number;
  essential: boolean;
  lastConfirmedDaysAgo: number;
}

export function infoValue(c: CheckInCandidate): number {
  if (
    !Number.isFinite(c.rate) || c.rate < 0 ||
    !Number.isFinite(c.low) || c.low < 0 ||
    !Number.isFinite(c.high) || c.high < 0 ||
    !Number.isFinite(c.onHand) || c.onHand < 0 ||
    !Number.isFinite(c.lastConfirmedDaysAgo) || c.lastConfirmedDaysAgo < 0
  ) {
    throw new RangeError("All numeric fields in CheckInCandidate must be non-negative finite numbers.");
  }

  if (c.rate === 0) return 0;

  const uncertainty = Math.min(3, (c.high - c.low) / c.rate);
  const urgency = 1 / (1 + (c.onHand / c.rate) / 7);
  const staleness = Math.min(1, c.lastConfirmedDaysAgo / 14);
  const weight = c.essential ? 2 : 1;

  const value = uncertainty * urgency * staleness * weight;
  return Math.round(value * 10000) / 10000;
}

export interface WeeklyQuestion {
  itemIds: string[];
  values: number[];
}

export function pickWeeklyQuestion(
  cands: readonly CheckInCandidate[],
  lastAskedDaysAgo: number | null,
  maxItems = 3,
  minValue = 0.05,
): WeeklyQuestion | null {
  if (lastAskedDaysAgo !== null && lastAskedDaysAgo < MIN_DAYS_BETWEEN_QUESTIONS) {
    return null;
  }

  const results = cands
    .map((c) => ({ itemId: c.itemId, value: infoValue(c) }))
    .filter((r) => r.value >= minValue)
    .sort((a, b) => {
      if (b.value !== a.value) return b.value - a.value;
      return a.itemId < b.itemId ? -1 : a.itemId > b.itemId ? 1 : 0; // not localeCompare: same order on every machine
    })
    .slice(0, maxItems);

  if (results.length === 0) return null;

  return {
    itemIds: results.map((r) => r.itemId),
    values: results.map((r) => r.value),
  };
}

// ── سؤال الحقيقة اليومي (P3.1) ──────────────────────────────────────────────
// حقيقة مستنتجة (zad_member_facts.source = inferred) بتتسأل مرة في اليوم بالكتير، والرد «آه»/«لأ» بيقفلها:
// «آه» = قالها (profile.fact_set source said)، «لأ» = profile.fact_deny (مايتسألش ولا يتستنتج ١٨٠ يوم). الكتابة من الباب.

export const FACT_QUESTION_MIN_HOURS = 20;
export const FACT_DENY_QUIET_DAYS = 180;
/** السؤال المفتوح بيتقبل رد «آه»/«لأ» لحد كام ساعة. */
export const FACT_ANSWER_WINDOW_HOURS = 36;
/** أقل ثقة تستاهل سؤال (تحتها إشارة ضعيفة). */
export const FACT_MIN_QUESTION_CONFIDENCE = 0.4;

export interface FactQuestionCandidate {
  key: string;
  value: string;
  confidence: number;
  askedAt: string | null;
  deniedAt: string | null;
}

/**
 * أحسن حقيقة تتسأل دلوقتي، أو null. الشروط: لسه ماتسألتش، ماتنفتش من أقل من ١٨٠ يوم، ثقتها كفاية،
 * ومفيش سؤال اتبعت في آخر ٢٠ ساعة (سؤال واحد في اليوم). الأعلى ثقة الأول، وعند التساوي المفتاح أبجدياً.
 */
export function pickDailyFactQuestion(
  cands: readonly FactQuestionCandidate[],
  lastAskedHoursAgo: number | null,
  nowMs: number,
): FactQuestionCandidate | null {
  if (lastAskedHoursAgo !== null && lastAskedHoursAgo < FACT_QUESTION_MIN_HOURS) return null;
  const quietMs = FACT_DENY_QUIET_DAYS * 86_400_000;
  const ok = cands.filter((c) => {
    if (c.askedAt) return false;
    if (c.confidence < FACT_MIN_QUESTION_CONFIDENCE) return false;
    const d = c.deniedAt ? Date.parse(c.deniedAt) : NaN;
    return !(Number.isFinite(d) && nowMs - d < quietMs);
  });
  ok.sort((a, b) => b.confidence - a.confidence || (a.key < b.key ? -1 : a.key > b.key ? 1 : 0));
  return ok[0] ?? null;
}

/** نص السؤال. القيمة جاية من الحقيقة نفسها (مستنتجة من حدث أو من كلام العميل)، مش من تأليف. */
export function factQuestionText(value: string): string {
  return `سؤال صغير: أنا لاحظت إنه ${value}. صح كده؟ ردّ «آه» أو «لأ».`;
}

const YES = new Set(["اه", "ايوه", "ايوا", "ايوة", "اهه", "صح", "صحيح", "بالظبط", "تمام", "طبعا", "اكيد", "yes", "ايوه صح", "اه صح", "صح كده", "ايوه كده", "اه كده"]);
const NO = new Set(["لا", "لاء", "لا لا", "لا خالص", "غلط", "مش كده", "مش صح", "لا مش كده", "لا مش صح", "no", "لا ابدا", "لا مش بالظبط"]);

/** رد «آه»/«لأ» لوحده (حتى ٤ كلمات، ومعاه «يا زاد»). غير كده null، والرسالة تكمل مسارها العادي. */
export function parseFactAnswer(message: string): "yes" | "no" | null {
  let m = String(message ?? "").replace(/[ً-ٰٟـ]/g, "").replace(/[أإآ]/g, "ا").replace(/ى/g, "ي").replace(/ة/g, "ه")
    .toLowerCase().replace(/[.!؟?،,؛:"'«»…\p{Extended_Pictographic}‍️]/gu, " ").replace(/\s+/g, " ").trim();
  m = m.replace(/\s*يا زاد$/, "").trim();
  if (!m || m.split(" ").length > 4) return null;
  if (YES.has(m)) return "yes";
  if (NO.has(m)) return "no";
  return null;
}
