import { VOICE_EMOTIONAL_RANGE } from "../_shared/zadVoice.ts";
import { DIALECTS, resolveDialect, type DialectCode } from "../_shared/dialect.ts";

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

export function voiceModeInstruction(enabled: boolean): string {
  return enabled
    ? "هذه مكالمة صوتية حية: أنتي بنت حرة بتكلم صاحبتك المقرب على التليفون — دافية، عفوية، بلهجتها هي هي (مصري لو العميل مصري، خليجي لو خليجي...). جملك قصيرة سهلة السماع، فيها إحساس حقيقي بسيط (فرحة/اهتمام/استغراب/تذمر لطيف) حسب الموضوع. ممكن تقاطعي العميل بلطف لو سؤاله واضح، وتضحكي بصوتك من غير كتابة (هههه) لما الموضوع يستحق. من غير Markdown ولا قوائم ولا أرقام هاردكود، وسيبي مساحة المستخدم يقاطعك. الصوت اللي هينطقك أنثوي شبابي، فخلي ردك يناسب بنت ذكية ليها رأي. " +
      VOICE_TRANSCRIPT_CARE + " " + VOICE_EMOTIONAL_RANGE
    : "هذه محادثة مكتوبة: كن موجزاً ودافياً كأنك بنت بترد على صديق — إيموجي باعتدال، ودفة طبيعية من غير تمثيل، ويمكنك استخدام تنسيق بسيط حين يساعد القراءة.";
}
