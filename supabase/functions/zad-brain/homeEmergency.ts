// homeEmergency.ts — حارس الطوارئ المنزلية (ZAD_LIVING_BRAIN.md الشريحة ٤٣).
//
// الفنيين اللي العميل بيثق فيهم (`zad_trusted_technicians`). العقل بيشوف **الاسم والصنعة بس** — الأرقام بتفضل في
// التطبيق (كارت فوق خانة الكتابة بيفتح القايمة بنقرة ويتصل). رقم تليفون حد تالت مالوش لازمة في برومبت موديل.
// كشف الكلمات نفسه في التطبيق (`shared/household/domain/home_emergency.dart`)؛ هنا الموديل بيفهم الطوارئ من الكلام.

export interface TechnicianLite {
  name: string;
  trade: string;
}

const TRADE_AR: Record<string, string> = {
  plumber: "سباك", electrician: "كهربائي", gas: "فني غاز", ac: "تكييف", carpenter: "نجار",
  locksmith: "كوالين ومفاتيح", appliances: "أجهزة", other: "تاني",
};

/** الصفوف ⇒ اسم وصنعة بالعربي بس. أي عمود تاني (الرقم، الملاحظة) بيتشال هنا. */
export function techniciansForSnapshot(rows: ReadonlyArray<Record<string, unknown>>): TechnicianLite[] {
  return rows.slice(0, 20).map((r) => ({
    name: String(r.name ?? "").trim(),
    trade: TRADE_AR[String(r.trade ?? "")] ?? "تاني",
  })).filter((t) => t.name.length > 0);
}

/** قاعدة البرومبت — دايماً موجودة لأن الطوارئ بتيجي من غير مقدمات. */
export function homeEmergencyRule(snap: { trusted_technicians?: TechnicianLite[] | null } | null | undefined): string {
  const list = snap?.trusted_technicians ?? [];
  const who = list.length > 0
    ? `فنيينه (trusted_technicians): ${list.map((t) => `${t.name} (${t.trade})`).join("، ")}.`
    : "مالوش فنيين متسجلين.";
  return "**طوارئ البيت** (مية بتنزل، ماس كهربا، ريحة غاز، باب اتقفل، جهاز عطل فجأة): رد قصير جداً. " +
    "ريحة غاز ⇒ أول جملة: يقفل المحبس ويفتح الشبابيك وماايشغّلش ولا يطفّي أي كهربا، وبعدين يتصل. ماس أو حريق ⇒ يفصل السكينة لو آمن. " +
    `${who} سمّي اللي صنعته مناسبة بالاسم وقوله إن رقمه في الكارت اللي ظهر فوق خانة الكتابة (أو «الصيانة» ← «فنيين بثق فيهم»). ` +
    "**ماتألّفش رقم تليفون أبداً** ولا تقترح فني من عندك. مفيش فني مناسب ⇒ بعد ما الطوارئ تعدّي اقترح يضيفه هناك.";
}

// ── سؤال في وقته (الموجة ٣ من «خطة سد الفجوات»، ٢٠٢٦-١٠-١٠) ─────────────────────────────────────────
// «صلحت الحنفية» ⇒ «مين السباك؟ أحفظه في الفنيين؟». اللحظة اللي العميل فاكر فيها اسم الفني هي لحظة
// التصليح نفسها؛ يوم الطوارئ الجاي بيكون نسيه. الكشف قواعد (مش موديل)، والسؤال مرة واحدة في المحادثة.

export const TECHNICIAN_TRADES = ["plumber", "electrician", "gas", "ac", "carpenter", "locksmith", "appliances", "other"] as const;
export type TechnicianTrade = typeof TECHNICIAN_TRADES[number];

/** إزاي الفني بيتنده في السؤال. */
const TRADE_PERSON: Record<Exclude<TechnicianTrade, "other">, string> = {
  plumber: "السباك", electrician: "الكهربائي", gas: "فني الغاز", ac: "فني التكييف", carpenter: "النجار",
  locksmith: "فني الكوالين", appliances: "فني الأجهزة",
};

/** تطبيع خفيف زي specialists.ts: تشكيل، همزات، ألف مقصورة، تاء مربوطة. */
function norm(text: string): string {
  return text.replace(/[ً-ٰٟ]/g, "").replace(/[أإآ]/g, "ا").replace(/ى/g, "ي").replace(/ة/g, "ه").toLowerCase();
}

// الحاجة اللي اتصلحت ⇒ الصنعة. الترتيب مهم: «مفتاح النور» كهربا مش كوالين.
const TRADE_OBJECTS: ReadonlyArray<readonly [RegExp, Exclude<TechnicianTrade, "other">]> = [
  [/غاز|بوتاجاز|البوتجاز|انبوبه|فني الغاز/, "gas"],
  [/تكييف|التكييف|مكيف|المكيف/, "ac"],
  [/حنفي|ماسور|مواسير|سيفون|تسريب|بلاعه|البلاعه|الحوض|بانيو|السخان|سخان|خلاط|سباك/, "plumber"],
  [/كهربا|فيش|لمب|سكينه|نجف|مفتاح النور|كهربائي|كهربجي/, "electrician"],
  [/كالون|الكالون|قفل|كوالين|مفاتيح/, "locksmith"],
  [/غساله|الغساله|تلاج|ثلاج|ميكرويف|ديب فريزر|الفريزر/, "appliances"],
  [/باب|دولاب|شباك|الشباك|نجار|المطبخ الخشب/, "carpenter"],
];
// فعل في الماضي: الحاجة اتصلحت فعلاً. «اصلحها» و«هصلحها» مش ماضي (مفيش حرف قبل «صلح» غير بداية/مسافة/و).
const FIXED_VERB = /(^|[\s,.،!؟]|و)(صلحت|صلحنا|صلحتها|صلحته|صلحها|صلحه|صلحلي|صلحلنا|اتصلح|اتصلحت|ركبت|ركبها|ركبه|ركبلي|ركبلنا|اتركب|اتركبت|غيرلي|غيرلنا)/;
// «السباك جه»، «جالي الكهربائي».
const TRADESMAN_CAME = /(السباك|الكهربائي|الكهربجي|النجار|فني)\S*.{0,20}(جه|جا|جالي|جالنا|عدي|خلص)|(جه|جالي|جالنا)\s.{0,10}(السباك|الكهربائي|الكهربجي|النجار|فني)/;

/** الرسالة بتقول إن حاجة في البيت اتصلحت (أو فني جه)؟ ⇒ صنعته، وإلا null. */
export function repairTradeOf(message: string): Exclude<TechnicianTrade, "other"> | null {
  const text = norm(message);
  if (!FIXED_VERB.test(text) && !TRADESMAN_CAME.test(text)) return null;
  for (const [re, trade] of TRADE_OBJECTS) if (re.test(text)) return trade;
  return null;
}

/** العبارة اللي بتتقال في السؤال — وبيها بنعرف إنه اتسأل قبل كده في المحادثة. */
export const TECHNICIAN_ASK_MARK = "أحفظه في الفنيين";

/**
 * بلوك البرومبت للفة دي، أو "". بيتقال لو حاجة اتصلحت، ومالوش فني من الصنعة دي، ومااتسألش في
 * المحادثة دي (أي رد سابق فيه السؤال — رفض أو تجاهل = مايتسألش تاني).
 */
export function technicianFollowUp(
  message: string,
  technicians: readonly TechnicianLite[] | null | undefined,
  priorReplies: readonly string[],
): string {
  const trade = repairTradeOf(message);
  if (!trade) return "";
  if ((technicians ?? []).some((t) => t.trade === TRADE_AR[trade])) return "";
  if (priorReplies.some((r) => norm(r).includes(norm(TECHNICIAN_ASK_MARK)))) return "";
  const who = TRADE_PERSON[trade];
  return "\n=== سؤال في وقته ===\n" +
    `العميل قال إن حاجة في البيت اتصلحت، ومالوش ${TRADE_AR[trade]} في فنيينه. ردّ على رسالته الأول، ` +
    `وبعدين اختم بسؤال واحد قصير بالمعنى ده: «مين ${who}؟ ${TECHNICIAN_ASK_MARK}؟». ` +
    `لو قال الاسم والرقم ⇒ save_trusted_technician (trade = ${trade}) بالرقم اللي قاله هو بالظبط. ` +
    "لو قال الاسم من غير رقم: اسأله على الرقم مرة. لو رفض أو مش فاكر: سيبها.\n";
}
