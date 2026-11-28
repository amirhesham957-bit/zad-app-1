// jokeFilter.ts — فلتر الهزار والمبالغة (P3.1، بلاغ المالك ٢٠٢٦-١١-٢٨).
//
// «اشتريت السوق كله هههه» مش مصروف، و«بشرب ميت لتر شاي في اليوم 😂» مش عادة استهلاك. الرد عليها بمرح، ومفيش حاجة
// تتكتب في المخزن ولا المصاريف ولا مدخلات التنبؤ ولا الحقائق المستخلصة.
//
// دالة صافية، من غير موديل. **التحفظ هنا عمداً**: غلطة «اعتبرنا الجد هزار» بتضيّع تسجيل حقيقي، فمجرد ضحكة جنب
// مصروف عادي («سجل ٥٠ قهوة 😂») مش هزار. الهزار = تصريح بالهزار، أو مبالغة صريحة، أو ضحكة + رقم خيالي.

export type JokeKind = "explicit" | "hyperbole" | "laugh_absurd";
export interface JokeVerdict { joke: boolean; kind: JokeKind | null }

const normalize = (t: string) =>
  t.replace(/[ً-ٰٟـ]/g, "").replace(/[أإآ]/g, "ا").replace(/ى/g, "ي").replace(/ة/g, "ه").toLowerCase();

const AR_DIGITS = "٠١٢٣٤٥٦٧٨٩";
const digits = (t: string) => t.replace(/[٠-٩]/g, (c) => String(AR_DIGITS.indexOf(c))).replace(/[,،٬]/g, "");

/** تصريح بالهزار: «بهزر»، «هزار»، «بمزح»، «كدبة»، «ببالغ»، «نكتة». */
const EXPLICIT = /(^|\s)(بهزر|بهزار|بتهزر|بتهزار|هزار|هزارا|بمزح|بتمزح|مزح|مزاح|نكته|نكت|افيه|ببالغ|مبالغه|بكدب|كدبه|كذبه|بسخر|ساخر|سخريه|sarcasm|joking|kidding|jk)(\s|$|[.!؟?،,])/;
/** مبالغة معروفة: «اشتريت السوق كله»، «صرفت الدنيا»، «مليار جنيه». */
const HYPERBOLE = /(اشتري(ت)?\s+(السوق|الدنيا|المحل|الكوكب|مصر)\s*(كله|كلها)?|صرفت\s+(الدنيا|ثروه|الكوكب)|(الدنيا|السوق|العالم)\s+(كله|كلها)\s+(اشتريت|صرفت)|مليار(ات)?|تريليون|مليون\s+مليون|ملايين\s+الملايين)/;
/** ضحك: «هههه»، 😂، 🤣. لوحده مش دليل. */
const LAUGH = /(ه{3,}|ahah|haha|lol|😂|🤣|😹|😆)/;
/** رقم خيالي: «مليون» بالكلام، أو رقم ≥ ١٠٠ مليون. */
function absurdAmount(m: string): boolean {
  if (/(^|\s|ب)(مليون|ملايين)(\s|$)/.test(m)) return true;
  for (const n of m.match(/\d+(?:\.\d+)?/g) ?? []) if (Number(n) >= 100_000_000) return true;
  return false;
}

export function jokeVerdict(message: string): JokeVerdict {
  const m = normalize(digits(String(message ?? "")));
  if (!m.trim()) return { joke: false, kind: null };
  if (EXPLICIT.test(m)) return { joke: true, kind: "explicit" };
  if (HYPERBOLE.test(m)) return { joke: true, kind: "hyperbole" };
  if (LAUGH.test(m) && absurdAmount(m)) return { joke: true, kind: "laugh_absurd" };
  return { joke: false, kind: null };
}

export const isJoke = (message: string): boolean => jokeVerdict(message).joke;

/** أدوات الكتابة اللي الهزار مايلمسهاش: مخزن، مصاريف، ميزانية، تسوق، أهداف، تفضيلات، وحقائق. */
export const JOKE_BLOCKED_TOOLS: ReadonlySet<string> = new Set([
  "log_transaction", "allocate_income", "update_transaction", "delete_transaction", "set_monthly_limit",
  "set_category_budget", "mark_subscription_paid", "update_emergency_fund_balance", "reconcile_cash_balance",
  "add_inventory_item", "update_inventory_qty", "consume_item", "delete_inventory_item",
  "add_shopping_item", "complete_shopping_item", "delete_shopping_item", "add_shortages_to_shopping",
  "add_debt", "update_debt", "add_obligation", "update_obligation", "add_subscription", "update_subscription",
  "add_goal_progress", "set_life_goal", "report_price", "set_item_preference",
  "remember", "update_customer_profile", "learn_skill",
]);

/** نتيجة الأداة للموديل: حالة، مش رد للعميل. */
export const JOKE_TOOL_RESULT = "مرفوض: الرسالة هزار أو مبالغة، مفيش حاجة اتسجلت. رد عليه بمرح من غير ما تسجل.";

/** قاعدة البرومبت (لهجة مصرية). قصيرة عشان ميتقلش البرومبت. */
export const JOKE_RULE =
  "4ب. **هزار/مبالغة** («اشتريت السوق كله هههه»، «بهزر») ⇒ رد بمرح و**ممنوع أي أداة كتابة** (مخزن/مصاريف/تسوق/أهداف/remember) ولا تحسب الرقم في توقع. مش متأكد ⇒ سؤال خفيف. ضحكة جنب طلب عادي مش هزار.\n";
