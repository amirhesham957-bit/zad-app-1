// sensitiveMemory.ts — الحساس مايتحفظش غير بعد «صح؟» (ZAD_PLAN ٥.٣).
//
// زاد بيحفظ الحقايق اللي بتعدّي في الكلام من غير ما يسأل (قاعدة 5b في برومبت الشات، والاستخلاص بعد اللفة،
// والتأمل الليلي). ده صح لـ«عنده عيّلين» و«القبض يوم ٢٥»، وغلط لـ«مراتي حامل» أو «أخويا مسجون»: حاجة زي دي
// لو اتفهمت غلط أو اتقالت في وقت غلط بتجرح، ولو اتشاركت مع العيلة بتفضح. فالقاعدة:
//   • الشات (remember): الملاحظة الحساسة بتتركن في zad_memory_pending، والعقل بيسأل «أفتكر إن …؟ صح؟»،
//     ومابتتكتبش في zad_memory غير بجواب العميل في رسالة **بعدها** (pending_id + pending_yes).
//   • الاستخلاص بعد اللفة والتأمل الليلي: مفيش حد يتسأل، فالحساس بيتساب خالص.
// الكشف هنا قواعد ثابتة (مش موديل) عشان يبقى واحد في المسارات التلاتة، والموديل يقدر يزود عليه بـsensitive=true.
//
// «حساسية» (أكل/دوا) مش في القايمة عن قصد: دي أمان أكل البيت، وسؤال «صح؟» عليها كل مرة تقل من غير فايدة.
// والديون مش فيها برضه: زاد تطبيق فلوس، والالتزامات شغله اليومي.

export type SensitiveTopic = "health" | "mental_health" | "pregnancy" | "religion" | "marriage" | "legal" | "addiction";

/** اسم الموضوع زي ما العقل بيقوله للعميل. */
export const SENSITIVE_TOPIC_LABEL: Record<SensitiveTopic, string> = {
  health: "صحة",
  mental_health: "صحة نفسية",
  pregnancy: "حمل وإنجاب",
  religion: "دين",
  marriage: "خلافات جواز",
  legal: "قضايا",
  addiction: "إدمان",
};

// النص متطبّع (normalize): ة→ه، أ/إ/آ→ا، ى→ي، من غير تشكيل. الكلمة لازم تبقى كلمة لوحدها، أو بسوابقها
// («والسرطان»، «لدكتور»)، عشان «سني» (عمري) و«جنسيه» مايتمسكوش.
const W = (alts: string) => new RegExp(`(^|[\\s،,.؛:«(])(و|ف)?(ال|بال|لل|ب|ل|ك)?(${alts})(?=$|[\\s،,.؛:»)؟!])`);

const RULES: Array<[SensitiveTopic, RegExp]> = [
  ["mental_health", W("اكتئاب|مكتئب|مكتئبه|نوبات هلع|نوبه هلع|دكتور نفسي|دكتوره نفسيه|طبيب نفسي|علاج نفسي|مضاد اكتئاب|انتحار|اضطراب ثنائي")],
  ["pregnancy", W("حامل|اجهاض|عقم|حقن مجهري|اطفال انابيب|تاخر الانجاب")],
  ["health", W("سرطان|ورم|كيماوي|غسيل كلي|غسيل كلوي|سكري|مرض السكر|ضغط عالي|جلطه|زهايمر|صرع|ايدز|فيروس سي|كبد وبائي|اعاقه|معاق|معاقه|توحد|قلب مفتوح|عمليه جراحيه|مرض مزمن|مرض خطير")],
  ["religion", W("ملحد|ملحده|الحاد|مسيحي|مسيحيه|قبطي|قبطيه|شيعي|شيعيه|غير دينه|غيرت ديني|مابيصليش|مش بيصلي|مابصليش|مش بصلي")],
  ["marriage", W("طلاق|اتطلق|اتطلقت|اتطلقنا|منفصلين|انفصلنا|خيانه|بيخوني|بتخوني|بيضربني|بيضربها|بيضربهم|عنف اسري")],
  ["legal", W("قضيه|محكمه|محضر|سجن|مسجون|اتحبس|محبوس|مطلوب امنيا")],
  ["addiction", W("ادمان|مدمن|مدمنه|مخدرات|حشيش|ترامادول|خمره|كحول")],
];

function normalize(text: string): string {
  return text.replace(/[ً-ٰٟ]/g, "").replace(/[أإآ]/g, "ا").replace(/ى/g, "ي").replace(/ة/g, "ه");
}

/** موضوع الملاحظة لو حساسة، وإلا null. */
export function sensitiveTopic(note: string): SensitiveTopic | null {
  const norm = normalize(note);
  for (const [topic, re] of RULES) if (re.test(norm)) return topic;
  return null;
}

/** ملاحظة مستنية «صح؟» بتفضل قايمة الوقت ده بس — بعده العميل نسي السؤال، ومحدش يحفظها بجواب عن حاجة تانية. */
export const PENDING_TTL_MS = 3 * 86_400_000;

export interface PendingRow {
  created_at: string;
  resolved_at: string | null;
}

/**
 * ينفع العميل يأكد/يرفض الملاحظة دي في اللفة دي؟ «same_turn» = اتركنت في نفس اللفة، يعني العقل لسه
 * ماسألش ومحدش ردّ — ده الحارس اللي بيمنع الموديل يركن ويأكد في نفس النفس.
 */
export function pendingAnswerable(
  row: PendingRow, turnStartedMs: number, nowMs: number,
): "ok" | "same_turn" | "expired" | "resolved" {
  if (row.resolved_at) return "resolved";
  const created = Date.parse(row.created_at);
  if (!(created < turnStartedMs)) return "same_turn";
  if (nowMs - created > PENDING_TTL_MS) return "expired";
  return "ok";
}
