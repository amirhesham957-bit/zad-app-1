// restockCycle.ts — «ده خلص فعلاً ولا لسه شاريه؟» (ZAD_PLAN المرحلة ٣، الملف السلوكي التراكمي: المخزن والنواقص).
//
// بلاغ المالك ٦/١١ (بصور البوت): اشترى سمن وستر باور وحلاوة وفيبكس الصبح، وبالليل الحلم حطّهم في قايمة الشرا،
// وتنبيه «أنت جنب ماركت» عرضهم كـ«ناقص في البيت» مرتين. السبب: الفاتورة بتسجل الكمية ١ والحد الافتراضي ٢، و«ناقص» كان
// = الكمية ≤ الحد وبس. مفيش حاجة كانت بتعرف إن الصنف لسه متشري، ولا إنه بيتشرى كل شهر. ومعدل الاستهلاك
// (zad_consumption) بيتعلم بس من زرار «−» في المخزن، اللي محدش بيدوسه على العيش والسكر.
//
// القاعدة هنا: لكل صنف دورة شرا بالأيام — بداية معقولة حسب نوعه، وبعدين وسيط المسافات بين مرات شرا البيت نفسه
// لما يبقى فيه مرتين. الصنف «ناقص» لما يخلص (صفر)، أو لما معظم دورته يعدي من آخر شرا، أو لما كميته تحت الحد
// ونص دورته عدّى (العميل نقّصه بنفسه). من غير تاريخ شرا خالص = الحد القديم زي ما هو.
// الكلمات تحت بيانات مطابقة مع أسامي الأصناف — ممنوع تترجم (قاعدة i18n في CLAUDE.md).

const DAY_MS = 86_400_000;

/** نسبة الدورة اللي بعدها الصنف يتعرض كناقص (قبل ما يخلص بشوية). */
export const DUE_AT = 0.85;

/** التنبيه مايسبقش النفاد بأكتر من ٣ أيام (طلب المالك ٨/١١، ZAD_PLAN ٤.٢٦). */
export const WARN_DAYS = 3;

/**
 * بعد كام يوم من الشرا الصنف يتعرض كناقص. نسبة ٨٥٪ لوحدها كانت بتنبّه بدري في
 * الدورات الطويلة: ٣٠ يوم قبلها بـ٤٫٥، و٦٠ يوم قبلها بـ٩. والدورات القصيرة
 * (عيش كل يومين) بتفضل على النسبة لأن «٣ أيام قبل» معناها كل يوم.
 */
export function dueAfterDays(cycle: number): number {
  return Math.max(cycle * DUE_AT, cycle - WARN_DAYS);
}

const norm = (s: string) =>
  s.toLowerCase().replace(/[ًٌٍَُِّْـ]/g, "").replace(/[أإآ]/g, "ا").replace(/ة/g, "ه").replace(/ى/g, "ي").replace(/\s+/g, " ").trim();

/** null = مش صنف بيتعاد شراه (شنطة الكاشير). */
const PRIORS: ReadonlyArray<[RegExp, number | null]> = [
  [/شنط|شنطه|اكياس|كيس بلاستيك|bag/, null],
  [/عيش|خبز|صامولي|فينو|توست|بلدي|bread/, 2],
  [/لبن|حليب|زبادي|رايب|milk|yogh?urt/, 4],
  [/طماطم|خيار|بطاطس|بصل|خس|جزر|فلفل|كوسه|موز|برتقال|يوسفي|تفاح|فاكه|خضار|فواكه/, 5],
  [/فراخ|دجاج|لحم|لحمه|سمك|كفته|بانيه|chicken|meat/, 7],
  [/بيض|egg/, 7],
  [/مياه|ميه|مايه|ماء|water/, 7],
  [/جبن|جبنه|cheese/, 10],
  [/رز|ارز|مكرونه|معكرونه|باستا|عدس|فول|rice|pasta/, 21],
  [/زيت|سمن|زبده|oil|ghee|butter/, 30],
  [/سكر|ملح|شاي|قهوه|بن|نشا|دقيق|حلاوه|مربي|عسل|بهارات|sugar|salt|tea|coffee/, 30],
  [/مسحوق|صابون|منظف|كلور|ديتول|سائل|مطهر|اريال|تايد|برسيل|داوني|detergent/, 45],
  [/مزيل|رول اون|شامبو|معجون|فرشه|كريم|لوشن|عطر|كولونيا|بلسم|deodorant|shampoo|lotion/, 60],
];

const CATEGORY_PRIORS: ReadonlyArray<[RegExp, number]> = [
  [/الالبان|البان/, 5],
  [/الخضار|خضار|الفواكه|فواكه/, 5],
  [/اللحوم|لحوم|الدواجن/, 7],
  [/العنايه|عنايه|المنظفات|منظفات/, 45],
  [/البقاله|بقاله/, 21],
];

const DEFAULT_CYCLE = 21;

/** الدورة المبدئية للصنف من اسمه، وإلا من فئته. null = مايتعادش شراه. */
export function priorCycleDays(name: string, category?: string | null): number | null {
  const n = norm(name);
  for (const [re, days] of PRIORS) if (re.test(n)) return days;
  const c = norm(category ?? "");
  for (const [re, days] of CATEGORY_PRIORS) if (re.test(c)) return days;
  return DEFAULT_CYCLE;
}

/**
 * الدورة بعد ما البيت يتعلم: أيام الشرا المختلفة (يوم واحد لكل شرا) — مسافتين أو أكتر = وسيطهم، مسافة واحدة = نص
 * ونص مع البداية (لسه مش متأكدين)، أقل = البداية. مسافة أقل من يوم مابتتحسبش (نفس الفاتورة اتسجلت مرتين).
 */
export function cycleDays(prior: number | null, purchaseDays: readonly string[]): number | null {
  if (prior === null) return null;
  const days = [...new Set(purchaseDays.map((d) => d.slice(0, 10)).filter((d) => /^\d{4}-\d{2}-\d{2}$/.test(d)))].sort();
  const gaps: number[] = [];
  for (let i = 1; i < days.length; i++) {
    const g = (Date.parse(days[i]) - Date.parse(days[i - 1])) / DAY_MS;
    if (g >= 1) gaps.push(g);
  }
  if (gaps.length === 0) return prior;
  if (gaps.length === 1) return Math.round((prior + gaps[0]) / 2);
  const s = [...gaps].sort((a, b) => a - b);
  const mid = Math.floor(s.length / 2);
  return Math.max(1, Math.round(s.length % 2 ? s[mid] : (s[mid - 1] + s[mid]) / 2));
}

/**
 * كل كام يوم البيت بيشتري الصنف ده فعلاً (ZAD_PLAN ٤.٢٤): الوسيط من ٣ أيام شرا مختلفة
 * أو أكتر. أقل من كده = null: «بتجيبه كل ١٥ يوم» جملة عن عادة، ومسافة واحدة مش عادة.
 */
export function habitCycleDays(purchaseDays: readonly string[]): number | null {
  const days = [...new Set(purchaseDays.map((d) => d.slice(0, 10)).filter((d) => /^\d{4}-\d{2}-\d{2}$/.test(d)))];
  if (days.length < 3) return null;
  return cycleDays(1, days);
}

export interface RestockInput {
  name: string;
  category?: string | null;
  quantity: number | string | null;
  threshold?: number | string | null;
  /** «staple» / «occasional» لو العميل اختار بنفسه. */
  restockMode?: string | null;
  /** أيام شرا الصنف ده في البيت (ISO)، الأقدم الأول أو أي ترتيب. */
  purchaseDays: readonly string[];
  /** تصحيح العميل (zad_inventory.restock_cycle_days) — بيغلب البداية والمتعلّم. */
  cycleOverride?: number | string | null;
}

export interface RestockVerdict {
  due: boolean;
  cycleDays: number | null;
  daysSinceBought: number | null;
  reason: "empty" | "cycle" | "used_up" | "threshold" | "fresh" | "occasional" | "not_restocked" | "stocked";
}

/** الصنف ده يتعرض كناقص دلوقتي؟ */
export function restockVerdict(input: RestockInput, now = Date.now()): RestockVerdict {
  const qty = Number(input.quantity);
  const t = Number(input.threshold);
  const threshold = Number.isFinite(t) && t > 0 ? t : 1;
  const override = Number(input.cycleOverride);
  const cycle = Number.isInteger(override) && override >= 1 && override <= 365
    ? override
    : cycleDays(priorCycleDays(input.name, input.category), input.purchaseDays);
  const last = input.purchaseDays.reduce((m, d) => Math.max(m, Date.parse(d) || 0), 0);
  const since = last > 0 ? Math.max(0, (now - last) / DAY_MS) : null;
  const out = (due: boolean, reason: RestockVerdict["reason"]): RestockVerdict =>
    ({ due, cycleDays: cycle, daysSinceBought: since === null ? null : Math.floor(since), reason });

  if (cycle === null) return out(false, "not_restocked");
  if (input.restockMode === "occasional") return out(false, "occasional");
  if (Number.isFinite(qty) && qty <= 0) return out(true, "empty");
  if (since === null) return out(Number.isFinite(qty) && qty <= threshold, Number.isFinite(qty) && qty <= threshold ? "threshold" : "stocked");
  if (since >= dueAfterDays(cycle)) return out(true, "cycle");
  if (Number.isFinite(qty) && qty <= threshold && since >= cycle * 0.5) return out(true, "used_up");
  return out(false, "fresh");
}

/** أيام الشرا لكل صنف من zad_inventory_observations (الفاتورة/الإضافة من الشات/الشرا)، بالاسم المطبّع. */
export const PURCHASE_SOURCES = ["purchase", "camera_ocr", "chat_add"] as const;

export function purchaseDaysByItem(
  rows: ReadonlyArray<{ item_name: string | null; observed_at: string | null }> | null | undefined,
): Map<string, string[]> {
  const out = new Map<string, string[]>();
  for (const r of rows ?? []) {
    const key = norm(String(r.item_name ?? ""));
    if (!key || !r.observed_at) continue;
    (out.get(key) ?? out.set(key, []).get(key)!).push(r.observed_at);
  }
  return out;
}

/** مفتاح الصنف في [purchaseDaysByItem]. */
export const restockKey = norm;
