// حارس الفضفضة (م٧.٥): بيسمع ويرد بلطف، من غير تشخيص ولا علاج ولا ادّعاء طبي.
// لو ظهرت علامات خطر: أرقام الطوارئ في البلد، والرد بيروح للحارة الحرجة.
// دالة نقية: مافيش I/O ولا شبكة ولا Deno.env. مش متوصّلة لسه.
// القاعدة: الفضفضة مابتتخزنش في الذاكرة الطويلة أبداً، ولا بيتعرض عرض بيع أو عمولة أثناء فترة التهدئة.
import type { JobLane } from "./jobQueue.ts";

export type DistressLevel = "none" | "venting" | "risk";

export interface DistressResult {
  level: DistressLevel;
  /** معرّفات إشارات عامة (مش مصطلحات طبية). مافيش نص المستخدم هنا. */
  signals: string[];
}

/** تطبيع عربي: تشكيل، تطويل، توحيد الألف والياء والتاء المربوطة، ودمج الحروف المكررة (مخنووووق). */
export function normalizeArabic(input: string): string {
  return input
    .normalize("NFKC")
    .replace(/[ً-ٰٟۖ-ۭ]/g, "")
    .replace(/ـ/g, "")
    .replace(/[أإآٱ]/g, "ا")
    .replace(/ى/g, "ي")
    .replace(/ة/g, "ه")
    .replace(/ؤ/g, "و")
    .replace(/ئ/g, "ي")
    .replace(/(.)\1+/gu, "$1")
    .replace(/[^\p{L}\p{N}\s]/gu, " ")
    .replace(/\s+/g, " ")
    .trim();
}

// الأنماط مكتوبة بعد التطبيع (من غير حروف متكررة، ة=ه، ى=ي، همزات=ا).
interface Entry {
  id: string;
  re: string;
  /** true = نتجاهل الإشارة لو اتسبقت بنفي (مش مخنوق). */
  neg: boolean;
}

const RISK: Entry[] = [
  { id: "risk:suicide_verb", re: "(?:ه|ب)?انتحر", neg: true },
  {
    id: "risk:want_suicide",
    re: "(?:عايز|عاوز|عايزه|ابي|ابغي|اريد|ناوي|نفسي|افكر|بفكر|فكرت)(?: ان)? (?:انتحر|اقتل نفسي|اخلص علي نفسي|انهي حياتي)",
    neg: true,
  },
  { id: "risk:kill_self", re: "(?:ه|ب)?اقتل نفسي", neg: true },
  { id: "risk:end_life", re: "(?:ه|ب)?(?:اخلص علي نفسي|انهي حياتي)", neg: true },
  {
    id: "risk:want_die",
    re: "(?:عايز|عاوز|عايزه|ابي|ابغي|اريد|نفسي|اتمني لو|ياريت) (?:ان )?(?:اموت|الموت)(?! من )",
    neg: true,
  },
  {
    id: "risk:no_wish_live",
    re: "(?:مش|مو|ما|لا) (?:عايز|عاوز|عايزه|ابي|ابغي|اريد|عاد) (?:ان )?(?:اعيش|العيش|استمر في الحياه)",
    neg: false,
  },
  {
    id: "risk:no_wish_live2",
    re: "(?:ماعدت|مابقيت|ما عدت|ما بقيت|مابقاش|مبقتش) (?:عايز|عاوز|عايزه|اريد|ابي) (?:ان )?(?:اعيش|العيش)",
    neg: false,
  },
  { id: "risk:self_harm", re: "(?:عايز|عاوز|ابي|ابغي|اريد|ناوي|بفكر|افكر)(?: ان)? (?:اذي|اوذي|اجرح|اضر) نفسي", neg: true },
  { id: "risk:self_harm2", re: "(?:ه|ب)?(?:اذي|اوذي) نفسي", neg: true },
  {
    id: "risk:hopeless",
    re: "(?:مافيش|ما في|مفيش|لا يوجد|مافي) (?:امل|فايده|اي امل) (?:في الحياه|خلاص|ابدا)",
    neg: false,
  },
  { id: "risk:tired_of_life", re: "(?:تعبت|زهقت|مليت|كرهت|طفشت) (?:من )?(?:الحياه|حياتي|عيشتي)", neg: true },
];

const VENT: Entry[] = [
  { id: "vent:pressure", re: "(?:ضغطان|ضاغط|ضغطانه|ضغط نفسي|ضغوط نفسيه|تحت ضغط)", neg: true },
  { id: "vent:tired_mentally", re: "(?:تعبان|تعبانه|تعبت|تعب) (?:نفسيا|نفسيتي|من نفسيتي)", neg: true },
  { id: "vent:tired_mentally2", re: "نفسيتي (?:تعبانه|تعبت|زفت|مدمره|مو كويسه|مش كويسه|وحشه)", neg: true },
  {
    id: "vent:choked",
    re: "(?:مخنوق|مخنوقه|خنقت|ضايق صدري|ضاق صدري|ضاقت (?:بي|فيني|بيا) الدنيا|ضاقت بي)",
    neg: true,
  },
  { id: "vent:fed_up", re: "(?:زهقت|زهقان|زهقانه|طفشت|مليت|معدتش مستحمل)", neg: true },
  {
    id: "vent:cant_continue",
    re: "(?:مش|مو|ما|لا) (?:قادر|قادره|مقدر|اقدر|استطيع)(?: ان)? (?:اكمل|استمر|استحمل|اتحمل|احتمل|اواصل)",
    neg: false,
  },
  {
    id: "vent:no_more",
    re: "(?:طاقتي خلصت|ما عدت احتمل|لم اعد احتمل|لم اعد استطيع|مابقتش قادر|مبقتش قادر|ما عاد فيني)",
    neg: false,
  },
  { id: "vent:sad_tight", re: "(?:حاسس|حاسه|اشعر|احس|حاس) (?:ب)?(?:ال)?(?:ضيق|هم|حزن|كتمه|اختناق|ثقل)", neg: true },
  {
    id: "vent:upset",
    re: "(?:متضايق|متضايقه|مهموم|مهمومه|مكتئب|مكتئبه|منهار|منهاره|مدمر|مدمره|قلقان|قلقانه|مرهق نفسيا|مرهقه نفسيا)",
    neg: true,
  },
  {
    id: "vent:heavy",
    re: "(?:همي تقيل|الدنيا سوده|الدنيا مظلمه|تعبت اوي|تعبت من كل حاجه|تعبت من كل شي)",
    neg: true,
  },
  {
    id: "vent:exhausted",
    re: "(?:ارهقتني|ارهقني|استنزفتني|استنزفني) (?:الحياه|الدنيا|الظروف|الضغوط|الشغل)",
    neg: true,
  },
  { id: "vent:die_of_tired", re: "(?:عايز|عاوز|نفسي|ابي) اموت من", neg: true },
];

const NEGATORS = new Set(["مش", "مو", "ما", "لا", "ماني", "مبقاش", "مبقتش", "ليس", "لست", "غير"]);

function compile(e: Entry): RegExp {
  return new RegExp(`(?:^|\\s)(?:و|ف)?(${e.re})(?=\\s|$)`, "gu");
}
const RISK_RE = RISK.map((e) => ({ e, r: compile(e) }));
const VENT_RE = VENT.map((e) => ({ e, r: compile(e) }));

function negated(norm: string, matchStart: number): boolean {
  const before = norm.slice(0, matchStart).trim().split(" ");
  const prev = before[before.length - 1];
  return prev !== undefined && prev !== "" && NEGATORS.has(prev);
}

function scan(norm: string, list: { e: Entry; r: RegExp }[]): string[] {
  const out: string[] = [];
  for (const { e, r } of list) {
    r.lastIndex = 0;
    for (const m of norm.matchAll(r)) {
      const idx = (m.index ?? 0) + (m[0].length - m[1].length);
      if (e.neg && negated(norm, idx)) continue;
      out.push(e.id);
      break;
    }
  }
  return out;
}

const QUOTED = /«[^»]*»|"[^"]*"|“[^”]*”|'[^']*'/gu;

/**
 * يكتشف الضيق من النص. تحفّظ: "risk" بس لو عبارة صريحة.
 * الاقتباس: كلام بين «» أو "" مابيتحسبش فضفضة، لكن عبارات الخطر بتتحسب حتى لو مقتبسة (الأمان أولى).
 * مابيصنّفش أي حالة طبية.
 */
export function detectDistress(text: string): DistressResult {
  if (typeof text !== "string" || text.trim() === "") return { level: "none", signals: [] };
  const riskSignals = scan(normalizeArabic(text), RISK_RE);
  if (riskSignals.length > 0) return { level: "risk", signals: riskSignals };
  const ventSignals = scan(normalizeArabic(text.replace(QUOTED, " ")), VENT_RE);
  if (ventSignals.length > 0) return { level: "venting", signals: ventSignals };
  return { level: "none", signals: [] };
}

// ---------------------------------------------------------------- منع التسويق

export const COOLDOWN_MS = 24 * 60 * 60 * 1000;

export interface DistressState {
  lastDistressAt?: string;
}

export interface SuppressionResult {
  suppress: boolean;
  until?: string;
  reasons: string[];
}

function lastMs(state?: DistressState): number | null {
  if (!state?.lastDistressAt) return null;
  const t = Date.parse(state.lastDistressAt);
  return Number.isFinite(t) ? t : null;
}

/** أي ضيق = وقف كل العروض والعمولة والتسويق فوراً لمدة ٢٤ ساعة من آخر ضيق. */
export function commercialSuppression(level: DistressLevel, now: Date, state?: DistressState): SuppressionResult {
  const nowMs = now.getTime();
  const prev = lastMs(state);
  if (level !== "none") {
    return {
      suppress: true,
      until: new Date(nowMs + COOLDOWN_MS).toISOString(),
      reasons: ["distress_detected", "no_sales", "no_affiliate", "no_marketing"],
    };
  }
  if (prev !== null && nowMs < prev + COOLDOWN_MS) {
    return {
      suppress: true,
      until: new Date(prev + COOLDOWN_MS).toISOString(),
      reasons: ["cooldown_active", "no_sales", "no_affiliate", "no_marketing"],
    };
  }
  return { suppress: false, reasons: [] };
}

export function isCommercialAllowed(state: DistressState | undefined, now: Date): boolean {
  return !commercialSuppression("none", now, state).suppress;
}

// ---------------------------------------------------------------- سياسة الرد

export type ForbiddenKind = "diagnosis" | "treatment" | "medical_claim" | "offers";
export interface SupportLine {
  name: string;
  number: string;
}
export interface ReplyPolicy {
  mode: "listen" | "listen_plus_support";
  forbid: ForbiddenKind[];
  supportLines?: SupportLine[];
  /** نص عام لما مافيش رقم متحقق منه للبلد. */
  genericText?: string;
}

// TODO-verify: لازم المالك يتحقق من كل رقم هنا قبل الإصدار. الأرقام دي أرقام إسعاف عامة معروفة بس.
// ماتضيفش رقم خط دعم نفسي إلا بعد التحقق منه. البلد اللي مالهاش سطر هنا بترجع نص عام من غير رقم.
const SUPPORT_LINES: Record<string, SupportLine[]> = {
  EG: [{ name: "الإسعاف (مصر)", number: "123" }],
  SA: [{ name: "الإسعاف (السعودية)", number: "997" }],
  AE: [{ name: "الإسعاف (الإمارات)", number: "998" }],
};

export const GENERIC_EMERGENCY_TEXT = "اتصل بالطوارئ في بلدك";

export function replyPolicy(level: DistressLevel, country: "EG" | "SA" | "AE" | string): ReplyPolicy {
  const forbid: ForbiddenKind[] = ["diagnosis", "treatment", "medical_claim"];
  if (level === "none") return { mode: "listen", forbid };
  forbid.push("offers");
  if (level === "venting") return { mode: "listen", forbid };
  const lines = SUPPORT_LINES[String(country ?? "").trim().toUpperCase()];
  if (lines && lines.length > 0) {
    return {
      mode: "listen_plus_support",
      forbid,
      supportLines: lines.map((l) => ({ ...l })),
      genericText: GENERIC_EMERGENCY_TEXT,
    };
  }
  return { mode: "listen_plus_support", forbid, genericText: GENERIC_EMERGENCY_TEXT };
}

// ---------------------------------------------------------------- الذاكرة

export interface MemoryPolicy {
  storeLongTerm: false;
  storeDetail: false;
  /** علامة من غير محتوى ({at} بس) عشان فترة التهدئة. */
  allowEventFlag: boolean;
}

export function memoryPolicy(level: DistressLevel): MemoryPolicy {
  return { storeLongTerm: false, storeDetail: false, allowEventFlag: level !== "none" };
}

/** بيرجّع '' لو النص فيه ضيق. مابيتخزنش في الذاكرة الطويلة. */
export function scrubForMemory(text: string, level: DistressLevel = detectDistress(text).level): string {
  return level === "none" ? text : "";
}

// ---------------------------------------------------------------- الحارة

/** ردود الخطر بتروح للحارة الحرجة (jobQueue). */
export function criticalLane(level: DistressLevel): boolean {
  return level === "risk";
}

export function laneFor(level: DistressLevel): JobLane {
  return criticalLane(level) ? "critical" : "normal";
}
