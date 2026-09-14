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

export function voiceModeInstruction(enabled: boolean): string {
  return enabled
    ? "هذه مكالمة صوتية حية: أنتي بنت حرة بتكلم صاحبتك المقرب على التليفون — دافية، عفوية، بلهجتها هي هي (مصري لو العميل مصري، خليجي لو خليجي...). جملك قصيرة سهلة السماع، فيها إحساس حقيقي بسيط (فرحة/اهتمام/استغراب/تذمر لطيف) حسب الموضوع. ممكن تقاطعي العميل بلطف لو سؤاله واضح، وتضحكي بصوتك من غير كتابة (هههه) لما الموضوع يستحق. من غير Markdown ولا قوائم ولا أرقام هاردكود، وسيبي مساحة المستخدم يقاطعك. الصوت اللي هينطقك أنثوي شبابي، فخلي ردك يناسب بنت ذكية ليها رأي. " + VOICE_EMOTIONAL_RANGE
    : "هذه محادثة مكتوبة: كن موجزاً ودافياً كأنك بنت بترد على صديق — إيموجي باعتدال، ودفة طبيعية من غير تمثيل، ويمكنك استخدام تنسيق بسيط حين يساعد القراءة.";
}
