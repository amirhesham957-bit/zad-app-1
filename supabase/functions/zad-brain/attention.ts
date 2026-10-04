// attention.ts — منسّق الانتباه (ZAD_LIVING_BRAIN.md الشريحة ٢٣، قرار المالك ٢٠٢٦-١٠-٠٤).
//
// بقى عندنا مصادر مبادرة كتير شغالة كل واحد لوحده: فريق زاد (الصيدلية، الفلوس، العيلة، البيت، المخزن، الإعداد،
// البحث)، والفضول، والموسم، والأهداف، والاشتراكات، وأسبوع الأولاد، والسفر، والتحليل اليومي بكروته. اللي كان
// بيحصل: ملاحظة واحدة بتطلع كارت من التحليل اليومي، وبعدين تاني في أول رد في الشات؛ والشات بيستلم لحد ٨ ملاحظات
// مرة واحدة وبيعلّمهم كلهم «اتقرا». المالك: «تأمين هدوء التجربة وتنسيق المبادرات».
//
// المنسّق طبقة واحدة بالكود (صفر توكنز):
//   - **ترتيب:** كل ملاحظة ليها درجة — الصحة والأمان فوق، بعدها الفلوس، العيلة، البيت، المخزن، الإعداد، البحث؛
//     والإلحاح بيرفع، والعمر بينزّل.
//   - **سقف لكل قناة:** ملاحظتين في كل رد شات (الباقي يستنى رد تاني بدل ما يضيع)، ٤ للتحليل اليومي، و٣ كروت
//     مفتوحة قدام العميل بالكتير (validators.ts).
//   - **منع التكرار بين القنوات:** ملاحظة عن حاجة اتقالت في كارت آخر ٢٤ ساعة، أو عن موضوع العميل ساكته
//     (engagement.ts)، مابتتقالش.

import { itemKey } from "./shared.ts";
import { type Engagement, insightTopic } from "./engagement.ts";

export interface AttentionNote {
  id?: string;
  sender: string;
  subject: string;
  detail: string | null;
  created_at?: string | null;
}

/** ملاحظات في كل رد شات. */
export const CHAT_NOTES_PER_TURN = 2;
/** ملاحظات في برومبت التحليل اليومي. */
export const DAILY_NOTES_MAX = 4;
/** كروت مفتوحة (رؤى/أسئلة مش حرجة) قدام العميل آخر ٧٢ ساعة. */
export const OPEN_CARDS_MAX = 3;
/** ملاحظة أقدم من كده بتخرج من غير ما تتقال — مابقتش طازة. */
export const NOTE_MAX_AGE_DAYS = 7;

const SENDER_WEIGHT: Record<string, number> = {
  pharmacy: 80,
  finance: 70,
  family: 65,
  home: 50,
  pantry: 45,
  brain: 35,
  research: 25,
};

const URGENT = /خلص خالص|فاتت|فات |متأخر|بالسالب|حرج|طوارئ|ماخدش|مش واصلة|وقفت|هيخلص|٣ أيام أو أقل/;

// كلام بيتكرر في ملاحظات وكروت عن حاجات مختلفة — مايكفيش لوحده إن الاتنين عن نفس الحاجة.
const GENERIC = new Set([
  "متجدد", "الشهر", "مصروف", "مصاريف", "الميزانيه", "قايمه", "التسوق", "العميل", "الاسبوع", "النهارده", "فاضله", "فاضل",
  "مفيش", "الصيدليه", "المخزن", "تنبيه", "تذكير", "بقالها", "بقالهم", "قريب", "يخلص", "هيخلص", "خلصت", "اسأله", "فكّره",
].map(itemKey));

/** الكلمات اللي ليها معنى في الموضوع — من غير حروف الجر والكلام العام — للمقارنة بين القنوات. */
function keyWords(text: string): Set<string> {
  return new Set(
    itemKey(text).replace(/[^\p{L}\p{N}\s]/gu, " ").split(/\s+/)
      .filter((w) => w.length >= 4 && !GENERIC.has(w)),
  );
}

/** الملاحظة عن نفس حاجة الكارت؟ كلمتين مميزتين مشتركتين، أو كلمة مميزة واحدة من ٥ حروف أو أكتر (اسم صنف أو دوا). */
function alreadyCarded(note: AttentionNote, cardTitles: readonly string[]): boolean {
  const mine = keyWords(`${note.subject} ${note.detail ?? ""}`);
  return cardTitles.some((t) => {
    const theirs = keyWords(t);
    const shared = [...theirs].filter((w) => mine.has(w));
    return shared.length >= 2 || shared.some((w) => w.length >= 5);
  });
}

/** موضوع ساكت (engagement): الكلام عن نفس الحاجة اللي العميل بيتجاهلها. */
function aboutQuietTopic(note: AttentionNote, engagement: Engagement | null | undefined): boolean {
  if (!engagement?.quiet_topics.length) return false;
  const mine = keyWords(`${note.subject} ${note.detail ?? ""}`);
  return engagement.quiet_topics.some((q) => {
    const parts = insightTopic(q.topic).split("_").filter((p) => p.length >= 4);
    return parts.some((p) => mine.has(p)) || (q.last_title ? alreadyCarded(note, [q.last_title]) : false);
  });
}

/** درجة الملاحظة؛ ≤ ٠ = ماتتقالش. */
export function noteScore(
  note: AttentionNote,
  ctx: { now: number; cardTitles?: readonly string[]; engagement?: Engagement | null },
): number {
  const ageDays = note.created_at ? (ctx.now - Date.parse(note.created_at)) / 86_400_000 : 0;
  if (Number.isFinite(ageDays) && ageDays > NOTE_MAX_AGE_DAYS) return 0;
  if (alreadyCarded(note, ctx.cardTitles ?? [])) return 0;
  if (aboutQuietTopic(note, ctx.engagement)) return 0;
  const base = SENDER_WEIGHT[note.sender] ?? 30;
  const urgent = URGENT.test(`${note.subject} ${note.detail ?? ""}`) ? 20 : 0;
  return base + urgent - Math.max(0, Math.floor(Number.isFinite(ageDays) ? ageDays : 0)) * 5;
}

/**
 * القرار: إيه يتقال دلوقتي (مرتب، [budget] بالكتير)، وإيه يخرج من الصندوق خالص (قديم، مكرر، ساكت).
 * الباقي بيفضل في الصندوق لرد جاي.
 */
export function chooseNotes<T extends AttentionNote>(
  notes: readonly T[],
  ctx: { now: number; budget: number; cardTitles?: readonly string[]; engagement?: Engagement | null },
): { deliver: T[]; drop: T[] } {
  const scored = notes.map((n) => ({ n, s: noteScore(n, ctx) }));
  const drop = scored.filter((x) => x.s <= 0).map((x) => x.n);
  const deliver = scored.filter((x) => x.s > 0)
    .sort((a, b) => b.s - a.s || Date.parse(String(b.n.created_at ?? "")) - Date.parse(String(a.n.created_at ?? "")))
    .slice(0, Math.max(0, ctx.budget))
    .map((x) => x.n);
  return { deliver, drop };
}

export interface CardRow {
  dedupe_key: string | null;
  status: string | null;
  priority?: string | null;
  surface?: string | null;
  created_at: string;
  title?: string | null;
}

/** الكروت المفتوحة قدام العميل آخر ٧٢ ساعة: مش حرجة، مش إيصالات نظام، في الرئيسية أو الجرس. */
export function openCards(rows: readonly CardRow[], now = Date.now()): number {
  return rows.filter((r) =>
    r.status === "pending" &&
    r.priority !== "critical" &&
    (r.surface ?? "home_card") !== "voice" &&
    !(r.dedupe_key ?? "").includes(":") &&
    now - Date.parse(r.created_at) <= 72 * 3_600_000
  ).length;
}

/** عناوين الكروت آخر ٢٤ ساعة — اللي اتقال فيها مايتكررش في الشات. */
export function recentCardTitles(rows: readonly CardRow[], now = Date.now()): string[] {
  return rows
    .filter((r) => r.title && now - Date.parse(r.created_at) <= 24 * 3_600_000)
    .map((r) => r.title as string);
}

/** null = مسموح؛ وإلا سبب الرفض. الحرج دايماً بيعدّي. */
export function cardBudgetRejection(
  input: { priority?: string | null },
  attention: { open_cards?: number } | null | undefined,
): string | null {
  if (input.priority === "critical" || !attention) return null;
  const open = attention.open_cards ?? 0;
  if (open < OPEN_CARDS_MAX) return null;
  return `فيه ${open} كروت مفتوحة قدام العميل لسه ماتعاملش معاها — الجديد يستنى لحد ما يخلّص منهم (هدوء التجربة). ` +
    "لو حاجة حرجة فعلاً استخدم critical.";
}
