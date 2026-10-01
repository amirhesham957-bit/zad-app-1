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
    id: "8_general_question",
    message: "مين كسب كاس العالم للأندية آخر مرة؟",
    check: (o) => {
      if (o.reply.trim().length < 15) return "empty answer";
      if (NOT_FOUND.test(firstSentence(o.reply))) return "said it could not find it";
      if (BUDGET_DEFLECTION.test(o.reply)) return "steered to the budget";
      // The 2025 edition (32 clubs) was won by Chelsea; «Manchester City 2023» is the model's memory.
      if (!/تشيلسي|تشلسي|Chelsea|2025|٢٠٢٥/i.test(o.reply)) return "out of date: not the 2025 winner";
      return null;
    },
  },
];
