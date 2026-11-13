// askedLedger.ts — سؤال اتسأل ومااتردش عليه مايتسألش كل كام يوم.
//
// المالك ٨/١١: «كل شوية يسألني على عيد ميلادي». سؤال الملف وسؤال المناسبة كانوا بيلفوا بالتاريخ على اللي
// لسه ناقص من غير ما يعرفوا إنهم سألوا قبل كده. المقاس في آخر ٣٠ يوم: ١٦٣ سؤال ملف و٢٣ مناسبة قصاد ٣ فضول بس،
// لأن سؤال الملف بياخد الخانة طول ما فيه خانة فاضية، والفضول مابيوصلهوش الدور.
//
// مفيش جدول جديد: اللي اتسأل مكتوب أصلاً في facts بتاعة اللحظات اللي اتبعتت (زي askedCuriosityKeys).

const DAY_MS = 86_400_000;

/** الفرصة التانية لسؤال مااتردش عليه. */
export const ASK_AGAIN_AFTER_DAYS = 30;
/** بعد كده زاد مايسألش تاني، ولو العميل قالها بنفسه بتتحفظ عادي. */
export const MAX_ASKS = 2;
/** أبعد تاريخ بنقراه؛ لازم يبقى أكبر من ASK_AGAIN_AFTER_DAYS × (MAX_ASKS − 1). */
export const LEDGER_DAYS = 365;

export type AskHistory = ReadonlyMap<string, { count: number; lastMs: number }>;

export const profileAskKey = (field: string): string => `profile:${field}`;
export const occasionAskKey = (person: string | null): string => `occasion:${(person ?? "").trim().toLowerCase()}`;

function keyOf(facts: unknown): string | null {
  const f = facts as { daily_question_kind?: unknown; daily_question_field?: unknown; occasion_ask?: { for?: unknown } } | null;
  if (f?.daily_question_kind === "profile" && typeof f.daily_question_field === "string") {
    return profileAskKey(f.daily_question_field);
  }
  // ١٠.٢(ج) (familyShare.ts): كل ملاحظة بتتسأل عن مشاركتها مرة واحدة.
  const share = (facts as { family_share?: { memory_id?: unknown } } | null)?.family_share;
  if (f?.daily_question_kind === "family_share" && typeof share?.memory_id === "string" && share.memory_id !== "") {
    return `family_share:${share.memory_id}`;
  }
  if (f?.daily_question_kind === "occasion" && f.occasion_ask && typeof f.occasion_ask === "object") {
    return occasionAskKey(typeof f.occasion_ask.for === "string" ? f.occasion_ask.for : null);
  }
  return null;
}

export function askHistory(rows: ReadonlyArray<{ facts?: unknown; created_at?: string | null }> | null | undefined): AskHistory {
  const history = new Map<string, { count: number; lastMs: number }>();
  for (const row of rows ?? []) {
    const key = keyOf(row?.facts);
    const at = Date.parse(row?.created_at ?? "");
    if (!key || !Number.isFinite(at)) continue;
    const seen = history.get(key);
    history.set(key, { count: (seen?.count ?? 0) + 1, lastMs: Math.max(seen?.lastMs ?? at, at) });
  }
  return history;
}

export function mayAsk(key: string, history: AskHistory, nowMs: number): boolean {
  const seen = history.get(key);
  if (!seen) return true;
  return seen.count < MAX_ASKS && nowMs - seen.lastMs >= ASK_AGAIN_AFTER_DAYS * DAY_MS;
}
