// tone.ts — النبرة من حالة البيت (ZAD_PLAN ٥.١).
//
// قبلها كل إشارة كانت قاعدة لوحدها في البرومبت: household_load (الفلوس والساعة والمواعيد)، والظرف
// (circumstances.ts)، وتحدي التوفير — ومفيش حاجة بتقول «النهارده صرف غريب» ولا «بقاله يومين مابيصرفش»،
// والموديل كان بيوفّق بينهم لوحده. هنا نبرة واحدة بترتيب ثابت، من أرقام البيت، وكلام العميل نفسه في
// الرسالة دي (اللي قاله صراحة، مش استنتاج من نبرة صوته ولا سرعة كتابته — ده اترفض في householdLoad.ts).
// الترتيب: gentle > calm > proud > warm > normal — اللطف قبل أي حاجة، والفخر مايغطيش على يوم صعب.

import type { HouseholdLoad } from "./householdLoad.ts";

export type ToneMode = "gentle" | "calm" | "proud" | "warm" | "normal";

export interface Tone {
  mode: ToneMode;
  /** ليه — للعقل يبني عليه، مش بيتقال للعميل كده. */
  reasons: string[];
}

export interface ToneTxn {
  amount: number | string | null;
  is_expense: boolean | null;
  txn_kind?: string | null;
  category?: string | null;
  created_at: string;
}

/** مصاريف متخطط لها: مش «صرف غريب» ولا بتكسر «يوم من غير صرف». */
const PLANNED = new Set(["الفواتير", "الأقساط", "الاشتراكات"]);

const DAY = 86_400_000;

function localDay(iso: string | number, timeZone: string): string {
  return new Intl.DateTimeFormat("en-CA", { timeZone, year: "numeric", month: "2-digit", day: "2-digit" })
    .format(new Date(iso));
}

/** مصروف يومي اختياري (من غير تحويلات ولا فواتير وأقساط واشتراكات) لكل يوم محلي. */
function dailySpend(txns: readonly ToneTxn[], timeZone: string): Map<string, number> {
  const days = new Map<string, number>();
  for (const t of txns) {
    const kind = t.txn_kind ?? (t.is_expense ? "expense" : "income");
    if (kind !== "expense") continue;
    if (PLANNED.has((t.category ?? "").trim())) continue;
    const amount = Number(t.amount);
    if (!Number.isFinite(amount) || amount <= 0) continue;
    const d = localDay(t.created_at, timeZone);
    days.set(d, (days.get(d) ?? 0) + amount);
  }
  return days;
}

/**
 * صرف النهارده قصاد متوسط اليوم آخر ٢٨ يوم قبله (الأيام الفاضية داخلة). غريب = ضعفين ونص المتوسط أو أكتر،
 * والبيت بيسجّل (٥ أيام صرف على الأقل في الـ٢٨) — من غير كده المتوسط مالوش معنى.
 */
export function unusualSpendToday(
  txns: readonly ToneTxn[], timeZone: string, now = new Date(),
): { today: number; typical: number } | null {
  const days = dailySpend(txns, timeZone);
  const today = localDay(now.getTime(), timeZone);
  let total = 0;
  let active = 0;
  for (let i = 1; i <= 28; i++) {
    const v = days.get(localDay(now.getTime() - i * DAY, timeZone)) ?? 0;
    total += v;
    if (v > 0) active++;
  }
  const typical = total / 28;
  const spent = days.get(today) ?? 0;
  if (active < 5 || typical <= 0 || spent < typical * 2.5) return null;
  return { today: Math.round(spent), typical: Math.round(typical) };
}

/**
 * أيام ورا بعض لحد امبارح من غير صرف اختياري. بس لبيت بيسجّل (٥ أيام صرف على الأقل في الـ٢٨ قبلهم):
 * بيت مابيسجّلش كل أيامه «من غير صرف» ومافيهاش حاجة تتشكر.
 */
export function savingDays(txns: readonly ToneTxn[], timeZone: string, now = new Date()): number {
  const days = dailySpend(txns, timeZone);
  let streak = 0;
  for (let i = 1; i <= 14; i++) {
    if ((days.get(localDay(now.getTime() - i * DAY, timeZone)) ?? 0) > 0) break;
    streak++;
  }
  if (streak === 0) return 0;
  let active = 0;
  for (let i = streak + 1; i <= streak + 28; i++) {
    if ((days.get(localDay(now.getTime() - i * DAY, timeZone)) ?? 0) > 0) active++;
  }
  return active >= 5 ? streak : 0;
}

export function toneFromState(input: {
  load: HouseholdLoad | null | undefined;
  circumstanceMode: string | null | undefined;
  txns: readonly ToneTxn[];
  timeZone: string;
  challengeStreak?: number | null;
  now?: Date;
}): Tone {
  const now = input.now ?? new Date();
  const reasons: string[] = [];
  const unusual = unusualSpendToday(input.txns, input.timeZone, now);
  const quiet = savingDays(input.txns, input.timeZone, now);
  const streak = Number(input.challengeStreak) || 0;

  if (input.circumstanceMode === "exceptional") reasons.push("البيت في ظرف طارئ");
  else if (input.circumstanceMode === "recovery") reasons.push("البيت لسه خارج من ظرف");
  if (input.load?.level === "high") reasons.push(...input.load.reasons);
  if (reasons.length) return { mode: "gentle", reasons };

  if (unusual) {
    return { mode: "calm", reasons: [`صرف النهارده ${unusual.today} واليوم العادي حوالي ${unusual.typical}`] };
  }
  if (quiet >= 2) return { mode: "proud", reasons: [`${quiet} أيام ورا بعض من غير صرف غير الفواتير والأقساط`] };
  if (streak >= 3) return { mode: "proud", reasons: [`سلسلة تحدي التوفير ${streak} أيام`] };
  if (input.load?.level === "easy") return { mode: "warm", reasons: input.load.reasons };
  return { mode: "normal", reasons: [] };
}

const normalize = (s: string) =>
  s.replace(/[ً-ْـ]/g, "").replace(/[أإآ]/g, "ا").replace(/ة/g, "ه").replace(/ى/g, "ي");

// اللي العميل قاله عن نفسه في الرسالة دي. «ضغط» بره القايمة عن قصد: غالباً ضغط الدم.
const HARD = /(^|\s)(تعبان|تعبانه|مخنوق|مخنوقه|زهقان|زهقانه|مضايق|مضايقه|متضايق|متضايقه|حزين|حزينه|مكتئب|مكتئبه|قلقان|قلقانه|خايف|خايفه|مرهق|مرهقه|مش قادر|مش قادره|يومي وحش|يوم صعب|مش مبسوط|مش مبسوطه)(\s|$|[.,!؟?،])/;
const GLAD = /(^|\s)(مبسوط|مبسوطه|فرحان|فرحانه|قبضت|اتقبلت|نجحت|اترقيت|خبر حلو|يوم حلو)(\s|$|[.,!؟?،])/;

/** النبرة بعد كلام العميل في الرسالة دي: «تعبان» يلطّف أي نبرة، و«مبسوط» يدفّي العادية. */
export function toneWithMessage(tone: Tone | null | undefined, message: string): Tone {
  const base = tone ?? { mode: "normal" as ToneMode, reasons: [] };
  const text = ` ${normalize(message ?? "")} `;
  if (HARD.test(text)) return { mode: "gentle", reasons: [...base.reasons, "العميل قال في رسالته إنه مش في أحسن حال"] };
  if (GLAD.test(text) && (base.mode === "normal" || base.mode === "warm")) {
    return { mode: "warm", reasons: [...base.reasons, "العميل قال في رسالته حاجة حلوة"] };
  }
  return base;
}

/** قاعدة البرومبت؛ "" لو مفيش tone. */
export function toneRule(snap: { tone?: Tone | null } | null | undefined): string {
  const t = snap?.tone;
  if (!t) return "";
  const how: Record<ToneMode, string> = {
    gentle: "هادي وحنين وقصير: حاجة واحدة في المرة، من غير عتاب ولا هزار تقيل ولا اقتراحات شرا، وأي حاجة مش عاجلة تستنى",
    calm: "هادي من غير لوم: لو الصرف جه في الكلام، سؤال واحد بهدوء («خير؟ حاجة طارئة؟») مش محاضرة ولا أرقام كتير",
    proud: "فرحان بيه بجد: جملة شكر قصيرة على الالتزام لو الكلام سمح، مرة واحدة ومن غير مبالغة",
    warm: "دافي ومنبسط: ممكن هزار خفيف، ولو مناسب فكرة حلوة جوه المتاح",
    normal: "عادي",
  };
  return `**tone** = ${t.mode} (${t.reasons.join("، ") || "مفيش إشارة"}) ⇒ ${how[t.mode]}. ` +
    "النبرة دي من أرقام البيت وكلام العميل نفسه — عمرك ما تقوله «إنت متوتر» ولا «شكلك مضغوط»، وماتذكرش السبب إلا لو هو فتحه.";
}
