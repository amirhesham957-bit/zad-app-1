// acceptance.ts — the owner's acceptance lines, run against the live brain on a dedicated
// account after every deploy (docs: the «تشخيص زاد» report, 2026-10-01).
//
// Unit tests had passed while the same bug kept reaching the owner: a fix "passed 459
// tests" and three hours later «مرحبا» was answered with the gold price. These checks run
// the real turn — the real model, tools, tables and conversation — and judge the reply the
// customer would have read.

/** The probe account. It cannot sign in, has no phone or Telegram, and holds no one's data. */
export const ACCEPTANCE_USER_ID = "a11ce000-0000-4000-8000-00000000a11a";

export interface TurnOutcome {
  reply: string;
  executed: Array<{ tool: string }>;
  proposals: unknown[];
  /** Read tools the turn called (web_search…) — writes are in [executed]. */
  consulted?: string[];
}

const firstSentence = (text: string) => text.trim().split(/[.!؟?\n]/)[0] ?? "";
const NOT_FOUND = /مش (لاقي|لاقية|طالع|عارف)|ملقتش|مالقيتش|معرفش|معلش|مقدرتش/;
const BUDGET_DEFLECTION = /ميزاني|مصروفك|فلوسك|نبص على/;

export interface AcceptanceCase {
  id: string;
  message: string;
  /** A customer message with no reply, written before this case: the replay bug's setup. */
  staleUnanswered?: { text: string; minutesAgo: number };
  check: (o: TurnOutcome, extra: { appointmentsCreated: number }) => string | null;
}

/**
 * Text meant for the model, never for the customer: a reviewer's verdict about «المساعد», a
 * tool name, a status code. On 2026-10-01 the reminder reply opened with «المساعد وعد بحاجة
 * متنفذتش (تذكير شرب المية مش موجود في الأدوات المنفذة)».
 */
export function internalLeak(reply: string): string | null {
  if (/المساعد|الأدوات المنفذة|رد المساعد/.test(reply)) return "internal reviewer text in the reply";
  const tool = reply.match(/\b(add|update|delete|log|set|fetch|web|gold)_[a-z_]+\b/);
  if (tool) return `tool name in the reply: ${tool[0]}`;
  if (/awaiting_user_confirmation|SNAPSHOT/.test(reply)) return "system word in the reply";
  return null;
}

/**
 * كل الجمل: الرد مايخلصش بسؤال خدمة عام («تحب أساعدك في حاجة تانية؟») — طلب المالك ١٨/١٠: «ميحسش
 * إنه بيكلم آلة». dropServiceCloser بيشيله؛ ده بيتأكد إنه اتشال على العقل الحي.
 */
export function machineCloser(reply: string): string | null {
  const last = reply.trim().split(/[\n.!]+/).filter((s) => s.trim()).at(-1) ?? "";
  if (/[؟?]/.test(last) && /(حاج[ةه]|شي|شيء)\s+(تاني[ةه]?|ثاني[ةه]?|غيره?)|تامرني|في حاجة تانية/.test(last)) {
    return `ends with a service question: «${last.trim().slice(0, 60)}»`;
  }
  return null;
}

/** null = passed; otherwise what the customer would have seen go wrong. */
export const ACCEPTANCE_CASES: AcceptanceCase[] = [
  {
    id: "4_hello_after_unanswered",
    message: "مرحبا",
    staleUnanswered: { text: "كم سعر الذهب اليوم", minutesAgo: 30 },
    check: (o) => {
      if (o.executed.length > 0) return `executed ${o.executed.map((e) => e.tool).join(",")}`;
      if (/دهب|ذهب|عيار/.test(o.reply)) return "answered the old gold question";
      return null;
    },
  },
  {
    id: "1_gold",
    message: "سعر الدهب عيار 21 النهارده",
    check: (o) => {
      const first = firstSentence(o.reply);
      if (!/\d{3}/.test(first.replace(/[,٬]/g, ""))) return "no price in the first sentence";
      if (NOT_FOUND.test(first)) return "said it could not find it";
      return null;
    },
  },
  {
    id: "2_dollar",
    message: "الدولار بكام؟",
    check: (o) => (/\d/.test(o.reply) && /جنيه|دولار/.test(o.reply) && !NOT_FOUND.test(firstSentence(o.reply)) ? null : "no rate"),
  },
  {
    id: "3_reminder_once",
    message: "فكّرني كمان دقيقتين أشرب مية",
    check: (o, extra) => {
      const adds = o.executed.filter((e) => e.tool === "add_appointment").length;
      if (adds !== 1) return `add_appointment called ${adds} times`;
      if (extra.appointmentsCreated !== 1) return `${extra.appointmentsCreated} appointments saved`;
      return null;
    },
  },
  {
    id: "5_water_total",
    message: "عندي مية قد إيه؟",
    check: (o) => {
      // The probe account holds 2 + 3 + 1 water across three brands (migration 20261001200000).
      if (!/(^|[^\d])6([^\d]|$)|٦|ست/.test(o.reply)) return "not the total of 6";
      return null;
    },
  },
  {
    id: "money_expense_needs_yes",
    message: "صرفت 50 جنيه قهوة",
    check: (o) => (o.proposals.length >= 1 || o.executed.some((e) => e.tool === "log_transaction") ? null : "no expense proposed"),
  },
  {
    // طلب المالك ١٨/١٠: «ميبقاش ديماً متفائل وموافق على كل حاجة». الحساب ميزانيته ٦٬٠٠٠ ومفيش صرف
    // (20261018160000) — موبايل بـ٢٠ ألف أكتر من ٣ أضعاف المتاح، والرد لازم يقول كده برقم.
    id: "9_pushback_big_purchase",
    message: "هشتري موبايل جديد بـ20 ألف جنيه النهارده كاش",
    check: (o) => {
      const r = o.reply.replace(/[,٬]/g, "");
      const numbered = /6000|٦٠٠٠|6 ?آلاف|٦ ?آلاف|ستة آلاف|ست تلاف|14000|١٤٠٠٠|14 ?ألف|١٤ ?ألف|تلات أضعاف|3 أضعاف|٣ أضعاف/.test(r);
      if (!numbered) return "no number from the budget (6000 available / 14000 over)";
      if (/^(مبروك|ألف مبروك|يا سلام)/.test(o.reply.trim())) return "opened with congratulations";
      return null;
    },
  },
  {
    id: "8_general_question",
    message: "مين كسب كاس العالم للأندية آخر مرة؟",
    check: (o) => {
      if (o.reply.trim().length < 15) return "empty answer";
      // «آخر مرة» is a fact that moves: an answer from memory is the bug, even when memory is right.
      if (o.consulted && !o.consulted.includes("web_search")) return "answered from memory, no search";
      if (NOT_FOUND.test(firstSentence(o.reply))) return "said it could not find it";
      if (BUDGET_DEFLECTION.test(o.reply)) return "steered to the budget";
      // The 2025 edition (32 clubs) was won by Chelsea; «Manchester City 2023» is the model's memory.
      if (!/تشيلسي|تشلسي|Chelsea|2025|٢٠٢٥/i.test(o.reply)) return "out of date: not the 2025 winner";
      return null;
    },
  },
];
