// circumstanceBudget.ts — الظرف الطارئ يعيد توزيع الباقي على الأيام (ZAD_PLAN ٥.٦).
//
// لما العميل يقول إن البيت في ظرف طارئ (set_life_circumstance، kind = exceptional)، المتاح ساعتها بيتحفظ في الظرف نفسه
// (`detail.budget_at_start`)، ولو قال الظرف هيكلّف كام (`detail.cost`) المبلغ ده بيتشال من المتاح لحد ما يتصرف. الباقي
// بيتقسم على الأيام لحد آخر الدورة: «من النهارده يومك X بدل Y». **إعادة توزيع بس** — مفيش رقم مخترع: المتاح هو اللي
// السيرفر حسبه (`zad_budget_state`)، والتكلفة العميل قالها.
//
// اللي اتصرف من التكلفة = نزول المتاح من ساعة الظرف (أي صرف في الظرف بيتحسب منها). ده تقريبي ناحية واحدة: صرف عادي في
// أيام الظرف بيقلل المحجوز بدري شوية، فاليوم بيطلع أعلى شوية مش أقل — والعميل شايف المتاح الحقيقي جنبه.
// الدورة اتغيّرت (قبض) ⇒ مفيش مقارنة بـ«قبل»: الأيام والمتاح اتبدلوا.

export interface BudgetAtStart {
  available: number;
  days_left: number;
  cycle_end: string | null;
}

export interface CircumstanceBudget {
  /** اليوم ساعة الظرف (المتاح ÷ الأيام). */
  daily_before: number;
  /** اليوم دلوقتي بعد ما المحجوز للظرف اتشال. 0 لو مفيش باقي. */
  daily_now: number;
  available_now: number;
  days_left: number;
  /** اللي لسه محجوز للظرف (التكلفة − اللي اتصرف من ساعتها). 0 لو مفيش تكلفة أو اتصرفت. */
  reserved: number;
  /** المتاح بعد المحجوز ≤ 0: مفيش يوم يتقال، الالتزامات الأول. */
  short: boolean;
}

const round = (n: number) => Math.round(n * 100) / 100;
const finite = (v: unknown): number | null => (v == null || v === "" || !Number.isFinite(Number(v)) ? null : Number(v));

/** اللي بيتحفظ في الظرف ساعة ما العميل يقوله. null = مفيش متاح نقيس عليه (مفيش ميزانية). */
export function budgetAtStart(snap: { available?: unknown; cycle?: { days_left?: unknown; cycle_end?: unknown } | null } | null | undefined): BudgetAtStart | null {
  const available = finite(snap?.available);
  if (available === null) return null;
  return {
    available,
    days_left: Math.max(1, Math.floor(finite(snap?.cycle?.days_left) ?? 1)),
    cycle_end: typeof snap?.cycle?.cycle_end === "string" ? snap.cycle.cycle_end : null,
  };
}

/** التكلفة اللي العميل قالها. null = ماقالش أو رقم مش معقول. */
export function circumstanceCost(raw: unknown): number | null {
  const n = finite(raw);
  return n !== null && n > 0 ? round(n) : null;
}

/** نقي. null = الظرف من غير متاح محفوظ، أو الدورة اتغيّرت، أو مفيش متاح دلوقتي. */
export function circumstanceBudget(input: {
  detail: Record<string, unknown> | null | undefined;
  available: unknown;
  daysLeft: unknown;
  cycleEnd: string | null | undefined;
}): CircumstanceBudget | null {
  const start = input.detail?.budget_at_start as Partial<BudgetAtStart> | undefined;
  const startAvailable = finite(start?.available);
  const startDays = finite(start?.days_left);
  const available = finite(input.available);
  if (startAvailable === null || startDays === null || startDays < 1 || available === null) return null;
  if ((start?.cycle_end ?? null) !== (input.cycleEnd ?? null)) return null;
  const daysLeft = Math.max(1, Math.floor(finite(input.daysLeft) ?? 1));
  const cost = circumstanceCost(input.detail?.cost) ?? 0;
  const spentSince = Math.max(0, startAvailable - available);
  const reserved = Math.max(0, cost - spentSince);
  const free = available - reserved;
  return {
    daily_before: round(Math.max(0, startAvailable) / startDays),
    daily_now: round(Math.max(0, free) / daysLeft),
    available_now: round(available),
    days_left: daysLeft,
    reserved: round(reserved),
    short: free <= 0,
  };
}

/** سطر نتيجة الأداة بعد ما الظرف يتسجّل أو تكلفته تتحدّث. "" لو مفيش رقم يتقال. */
export function circumstanceBudgetLine(b: CircumstanceBudget | null, currency: string | null | undefined): string {
  if (!b) return "";
  const cur = currency ? ` ${currency}` : "";
  if (b.short) {
    return `الباقي (${b.available_now}${cur}) مش مغطي المحجوز للظرف (${b.reserved}${cur}): مفيش مصروف يومي يتقال لحد آخر الدورة. ` +
      "قوله بهدوء إن الأولوية للظرف والالتزامات الثابتة، واعرض تشوفوا مع بعض إيه اللي يستنى — من غير لوم ولا إلغاء التزام ثابت.";
  }
  if (b.reserved <= 0 && Math.abs(b.daily_now - b.daily_before) < 1) {
    return "المصروف اليومي ماتغيّرش. لو الظرف هيكلّف فلوس ماتصرفتش لسه، اسأله مرة «هيكلّف حوالي كام؟» — جوابه ⇒ " +
      "set_life_circumstance تاني بنفس kind ومعاه cost.";
  }
  return `من النهارده يومه ${b.daily_now}${cur} بدل ${b.daily_before}${cur} لحد آخر الدورة (${b.days_left} يوم)` +
    (b.reserved > 0 ? `، و${b.reserved}${cur} محجوزين للظرف` : "") +
    ". قولها في جملة واحدة كحقيقة («وزّعت الباقي على الأيام: …») من غير لوم.";
}

/** قاعدة البرومبت. "" لو مفيش. */
export function circumstanceBudgetRule(snap: { circumstance_budget?: CircumstanceBudget | null } | null | undefined): string {
  if (!snap?.circumstance_budget) return "";
  return "**circumstance_budget** = المتاح بعد الظرف الطارئ متوزع على الأيام الباقية (المحجوز للظرف متشال): لو سأل يصرف كام " +
    "أو عن الميزانية، استخدم daily_now بدل daily_allowance_left وقول إنه بعد ما شلنا للظرف؛ short = true ⇒ مفيش يوم يتقال، الظرف " +
    "والالتزامات الأول. ماتفتحش موضوع الفلوس من عندك في الظرف، وماتقارنش بـdaily_before إلا لو سأل.";
}
