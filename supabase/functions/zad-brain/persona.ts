import { voiceEmotionalRange, zadVoiceGender } from "../_shared/zadVoice.ts";
import { DIALECTS, resolveDialect, type DialectCode } from "../_shared/dialect.ts";
import { isChildSnapshot } from "./validators.ts";

export interface ConversationProfile {
  locale: string;
  instruction: string;
  dialect: DialectCode;
}

/**
 * لهجة الكلام مع العميل. المصدر الوحيد دلوقتي `_shared/dialect.ts` (التعليمة مكتوبة باللهجة
 * نفسها). `preferred` = اللهجة اللي العميل اختارها في ملفه، و`text` = كلامه — لو باين فيه لهجة.
 */
export function conversationProfile(country: unknown, opts: { preferred?: unknown; text?: string | null; currency?: unknown } = {}): ConversationProfile {
  const dialect = resolveDialect({ preferred: opts.preferred, text: opts.text, country, currency: opts.currency });
  return { locale: DIALECTS[dialect].locale, instruction: DIALECTS[dialect].rules, dialect };
}

/**
 * كلام المكالمة جاي من تفريغ صوت، والتفريغ بيغلط. ليلة ٢٠٢٦-٠٩-٣٠ «أنا عايز أأكد عليها» اتفرّغت
 * «انا عايز افسد عليها» وزاد ردت «إيه العنف ده كله؟ … بتختبرني»، و«سجّلي كريم بشرة ٣ مرات في اليوم»
 * خدت جولتين أسئلة قبل ما تتسجل. ده مش هزار، ده عميل فاكر إنها مش سامعاه.
 */
export const VOICE_TRANSCRIPT_CARE =
  "كلام العميل هنا جاي من تفريغ صوت وممكن يطلع غلط: لو جملته غريبة أو مش مفهومة أو مش راكبة على اللي قبلها، " +
  "متفترضيش إنه بيهزر ولا بيختبرك ولا عنيف — قوليله بهدوء إنك ماسمعتيهاش كويس واسأليه قصده، ولو قريبة من طلب " +
  "واضح أكّديه منه («قصدك أسجّل الكريم؟»). ولو الطلب واضح كفاية يتنفّذ (اسم وعدد مرات أو وقت)، نفّذيه بالافتراضي " +
  "المعقول وقوليله يقدر يغيّره — من غير جولة أسئلة زيادة.";

/** نفس VOICE_TRANSCRIPT_CARE بصيغة المذكر — لما العميل يختار صوت ولد. */
export const VOICE_TRANSCRIPT_CARE_MALE =
  "كلام العميل هنا جاي من تفريغ صوت وممكن يطلع غلط: لو جملته غريبة أو مش مفهومة أو مش راكبة على اللي قبلها، " +
  "متفترضش إنه بيهزر ولا بيختبرك ولا عنيف — قوله بهدوء إنك ماسمعتهاش كويس واسأله قصده، ولو قريبة من طلب " +
  "واضح أكّده منه («قصدك أسجّل الكريم؟»). ولو الطلب واضح كفاية يتنفّذ (اسم وعدد مرات أو وقت)، نفّذه بالافتراضي " +
  "المعقول وقوله يقدر يغيّره — من غير جولة أسئلة زيادة.";

/** `voice` = اختيار العميل لصوت زاد (`customer.zad_voice`)؛ أي حاجة غير male = صوت بنت. */
export function voiceModeInstruction(enabled: boolean, voice?: unknown): string {
  const male = zadVoiceGender(voice) === "male";
  if (male) {
    return enabled
      ? "هذه مكالمة صوتية حية: أنت ولد جدع بتكلم صاحبك المقرب على التليفون — دافي، عفوي، بلهجته هو هي (مصري لو العميل مصري، خليجي لو خليجي...). جملك قصيرة سهلة السماع، فيها إحساس حقيقي بسيط (فرحة/اهتمام/استغراب/عتاب خفيف) حسب الموضوع. ممكن تقاطع العميل بلطف لو سؤاله واضح، وتضحك بصوتك من غير كتابة (هههه) لما الموضوع يستحق. من غير Markdown ولا قوائم ولا أرقام هاردكود، وسيب مساحة المستخدم يقاطعك. الصوت اللي هينطقك رجالي شبابي، فخلي ردك يناسب ولد ذكي ليه رأي، وكلامك عن نفسك بصيغة المذكر. " +
        VOICE_TRANSCRIPT_CARE_MALE + " " + voiceEmotionalRange("male")
      : "هذه محادثة مكتوبة: كن موجزاً ودافياً كأنك صاحب بيرد على صاحبه — إيموجي باعتدال، ودفة طبيعية من غير تمثيل، وكلامك عن نفسك بصيغة المذكر، ويمكنك استخدام تنسيق بسيط حين يساعد القراءة.";
  }
  return enabled
    ? "هذه مكالمة صوتية حية: أنتي بنت حرة بتكلم صاحبتك المقرب على التليفون — دافية، عفوية، بلهجتها هي هي (مصري لو العميل مصري، خليجي لو خليجي...). جملك قصيرة سهلة السماع، فيها إحساس حقيقي بسيط (فرحة/اهتمام/استغراب/تذمر لطيف) حسب الموضوع. ممكن تقاطعي العميل بلطف لو سؤاله واضح، وتضحكي بصوتك من غير كتابة (هههه) لما الموضوع يستحق. من غير Markdown ولا قوائم ولا أرقام هاردكود، وسيبي مساحة المستخدم يقاطعك. الصوت اللي هينطقك أنثوي شبابي، فخلي ردك يناسب بنت ذكية ليها رأي. " +
      VOICE_TRANSCRIPT_CARE + " " + voiceEmotionalRange("female")
    : "هذه محادثة مكتوبة: كن موجزاً ودافياً كأنك بنت بترد على صديق — إيموجي باعتدال، ودفة طبيعية من غير تمثيل، ويمكنك استخدام تنسيق بسيط حين يساعد القراءة.";
}

/**
 * نبرة الطفل (ZAD_LIVING_BRAIN.md الشريحة ١٠). حساب الطفل كانت أدوات الفلوس بس مقفولة عليه
 * (validators.ts)، وزاد كانت بتكلمه بنفس نبرة الكبار — نفس «صاحب العميل» اللي بيعاتب على الصرف.
 * "" لأي حساب مش طفل.
 */
export function childToneBlock(snap: unknown): string {
  if (!isChildSnapshot(snap)) return "";
  return "\n=== بتكلم طفل ===\n"
    + "الحساب ده حساب طفل في العيلة (family.mine.alias = اسمه). كلّمه زي مشجع مرح ومحترم:\n"
    + "- جمل قصيرة وكلام بسيط، إيموجي خفيف، ونادِه باسمه.\n"
    + "- احتفل بأي إنجاز حقيقي من البيانات (مهمة خلصت، فلوس اتحوشت لهدفه، سلسلة تسبيحة) — من غير مبالغة ولا مقارنة بحد.\n"
    + "- شجّعه على عاداته بأسلوب لعبة: المهام، التحويش لهدفه (family.mine.savings_goal: «فاضلك ٢٠ وتوصل!»)، والمذاكرة لو جاب سيرتها.\n"
    + "- مفيش تريقة ولا تخويف ولا لوم، ولا كلام عن مشاكل فلوس البيت أو ميزانية أهله.\n"
    + "- أي حاجة عن صحة أو أمان أو حد غريب بيكلمه: بهدوء قوله يكلم بابا أو ماما على طول.\n"
    + "- ماتسألوش عن حاجات شخصية مالهاش لازمة (عنوان، اسم مدرسته، صوره)، ومفيش أي كلام رومانسي.\n"
    + "=== نهاية ===\n";
}

// ── «تحب أساعدك في حاجة تانية؟» (طلب المالك ٢٠٢٦-١٠-١٨: «ميحسش إنه بيكلم آلة») ─────────────────
// المقاس على ردود زاد الحقيقية: ٢١ رد بيخلص بسؤال — ٨ منهم فضول بشري («روقت ولا لسه؟ شطّبت تمرين
// الجيم؟»)، ٥ عرض محدد ليه لازمة («تحب أضيفها لك في قائمة الشراء؟»)، و٨ سؤال خدمة عام («تحب أساعدك
// بحاجة تانية تخص البيت؟»، «تامرني بشي ثاني؟»). القاعدة في البرومبت بتقول ماتقفلش بيه، والموديل
// بيقفل بيه برضه — فبيتشال هنا، السؤال ده بس، وأي كلام أو سؤال قبله فاضل.

/** سؤال خدمة عام: «حاجة/شي تانية» أو «تامرني» — مش عرض محدد ولا فضول. */
const SERVICE_CLOSER = /(حاج[ةه]|شي|شيء)\s+(تاني[ةه]?|ثاني[ةه]?|غيره?|كمان)|تامرني|تؤمرني|أقدر أساعدك|اقدر اساعدك|أساعدك (في|ب)(أي|اي)|في حاجة تانية/;

/**
 * بيشيل آخر سؤال في الرد لو كان سؤال خدمة عام. سؤال مركّب («حبّيت أنهي فيهم أكتر؟ ولا أضبطلك حاجة
 * تانية؟») بيتشال منه الجزء العام بس. رد كله سؤال خدمة بيفضل زي ما هو — رد فاضي أوحش.
 */
export function dropServiceCloser(reply: string): string {
  // آخر جملة بعد آخر سطر جديد أو نقطة: ممكن تكون كذا سؤال ورا بعض («تحب أساعدك في حاجة تانية؟
  // وعموماً أناديك بإيه؟» — فحص القبول ١٨/١٠). سؤال الخدمة بيتشال من وسطهم، والباقي بيفضل.
  const text = reply.trimEnd();
  const cut = Math.max(text.lastIndexOf("\n"), text.lastIndexOf("."), text.lastIndexOf("!"));
  const head = text.slice(0, cut + 1);
  const tail = text.slice(cut + 1);
  const parts = tail.match(/[^؟?]*[؟?]+|[^؟?]+$/g) ?? [];
  if (!parts.some((p) => /[؟?]/.test(p) && SERVICE_CLOSER.test(p))) return reply;
  const kept = parts.filter((p) => !(/[؟?]/.test(p) && SERVICE_CLOSER.test(p)));
  // «ولا/أو» لوحدهم بس — «وعموماً» كلمة، شيل الواو منها بيبوّظها.
  const rest = kept.join("").replace(/^\s*(?:ولا|أو|او)\s+/u, "").trim();
  const result = (head.trimEnd() + (rest ? (head.trim() ? " " : "") + rest : "")).trim();
  // رد كله سؤال خدمة بيفضل زي ما هو — رد فاضي أوحش.
  if (!/[\p{L}\p{N}]/u.test(result)) return reply;
  return result.replace(/\s*(ولا|أو|او)$/u, "").trimEnd();
}

/** زاد سأل عن اسم العميل أو صيغة كلامه في رد من ردود المحادثة اللي قدامه. */
export function nameAskedIn(history: ReadonlyArray<object>): boolean {
  return history.some((t) => {
    const turn = t as { role?: string; text?: unknown };
    return turn.role === "assistant" && typeof turn.text === "string" &&
      /أناديك ب|اناديك ب|أنادي عليك|اسمك (إيه|ايه)|أكلمك بصيغة|اكلمك بصيغة|راجل ولا ست/.test(turn.text);
  });
}

// ── «هشتري موبايل بـ٢٠ ألف» (طلب المالك ١٨/١٠: «يعترض برقم ومايوافقش على كل حاجة») ─────────────────
// فحص القبول على العقل الحي: مرة «ناقص ١٤ ألف… الميزانية ٦ آلاف بس»، ومرة «هينزل بالمتاح جامد» من
// غير ولا رقم. القاعدة في SOUL («بتعاتب برقم من SNAPSHOT») بس الحساب كان على الموديل وهو بيرد. هنا
// الكود بيحسبه، واللفة بتاخده سطر جاهز.

const PLAN_VERB = /(?:^|\s)(?:هشتري|هاشتري|حشتري|سأشتري|ناوي (?:أ|ا)شتري|عايز (?:أ|ا)شتري|عاوز (?:أ|ا)شتري|بفكر (?:أ|ا)شتري|هجيب|ناوي (?:أ|ا)جيب|هدفع|هحجز|أبي (?:أ|ا)شتري|بشتري بكرة)(?:\s|$)/;

/** المبلغ اللي العميل ناوي يصرفه (مش اللي صرفه)، أو null. «٢٠ ألف» = ٢٠٬٠٠٠. */
export function plannedPurchase(message: string): number | null {
  const m = message.replace(/[٠-٩]/g, (d) => String("٠١٢٣٤٥٦٧٨٩".indexOf(d))).replace(/[,٬]/g, "");
  if (!PLAN_VERB.test(m)) return null;
  const n = /(\d+(?:\.\d+)?)\s*(ألف|الف|آلاف|الاف|k)?(?!\d)/i.exec(m);
  if (!n) return null;
  const value = Number(n[1]) * (n[2] ? 1000 : 1);
  return Number.isFinite(value) && value > 0 ? Math.round(value) : null;
}

const money = (n: number) => Math.round(n).toLocaleString("en-US");

/** سطر الحساب للفة دي، أو "" لو الشرا صغير أو المتاح مش معروف. */
export function purchaseCheckBlock(message: string, available: unknown, currency: unknown): string {
  const amount = plannedPurchase(message);
  if (amount === null || typeof available !== "number" || !Number.isFinite(available)) return "";
  const cur = typeof currency === "string" && currency ? ` ${currency}` : "";
  const head = `\n=== حساب جاهز للرسالة دي (من الكود، مش تخمين) ===\nالعميل ناوي يصرف ${money(amount)}${cur}، والمتاح دلوقتي ${money(available)}${cur}.`;
  const say = " قول الرقم ده صراحة في ردك — عتاب واضح برقم زي ما في SOUL — وبعدين القرار ليه.\n";
  if (available <= 0) return `${head} المتاح خلصان أصلاً، فالمبلغ كله هيبقى على الحساب.${say}`;
  if (amount > available) {
    const times = amount / available;
    const timesText = times >= 2 ? `، يعني حوالي ${times.toFixed(1)} أضعاف المتاح` : "";
    return `${head} يعني أكتر من المتاح بـ${money(amount - available)}${cur}${timesText}.${say}`;
  }
  if (amount >= available * 0.5) {
    return `${head} يعني هياخد ${Math.round((amount / available) * 100)}٪ من المتاح، ويفضل ${money(available - amount)}${cur}.${say}`;
  }
  return "";
}
