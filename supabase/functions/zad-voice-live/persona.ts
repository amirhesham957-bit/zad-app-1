import { VOICE_EMOTIONAL_RANGE } from "../_shared/zadVoice.ts";
import { DIALECTS, resolveDialect } from "../_shared/dialect.ts";

// persona.ts — نسخة مقصودة من zad-brain/persona.ts (بند 33.3). نفس نمط entitlement.ts:
// كل فانكشن مستقل في المشروع ده، مفيش استيراد بين فانكشنز، فالمنطق الصغير المشترك
// بيتنسخ بدل ما يتوصّل بمسار نسبي هش وقت النشر.
export interface ConversationProfile {
  locale: string;
  instruction: string;
}

/**
 * اللهجة من `_shared/dialect.ts` — نفس مصدر الشات والبوت (التعليمة مكتوبة باللهجة نفسها).
 * `preferred` = لهجة العميل من ملفه لو اختارها.
 */
export function conversationProfile(country: unknown, preferred?: unknown): ConversationProfile {
  const dialect = resolveDialect({ preferred, country });
  return { locale: DIALECTS[dialect].locale, instruction: `${DIALECTS[dialect].rules} ${DIALECTS[dialect].examples.map((e) => `«${e}»`).join(" ")}` };
}

/** نفس نص zad-brain/persona.ts's voiceModeInstruction(true) بالظبط — دي أصلاً
 *  اتكتبت لمكالمة صوتية حية، فمفيش حاجة تتغيّر هنا. */
export const VOICE_TONE_INSTRUCTION =
  "هذه مكالمة صوتية حية: أنتي بنت حرة بتكلم صاحبتك المقرب على التليفون — دافية، عفوية، بلهجتها هي هي (مصري لو العميل مصري، خليجي لو خليجي...). جملك قصيرة سهلة السماع، فيها إحساس حقيقي بسيط (فرحة/اهتمام/استغراب/تذمر لطيف) حسب الموضوع. ممكن تقاطعي العميل بلطف لو سؤاله واضح، وتضحكي بصوتك من غير كتابة (هههه) لما الموضوع يستحق. من غير Markdown ولا قوائم ولا أرقام هاردكود، وسيبي مساحة المستخدم يقاطعك. الصوت اللي هينطقك أنثوي شبابي، فخلي ردك يناسب بنت ذكية ليها رأي.";

/** هوية مكثّفة لجلسة الصوت — مش soul.ts الكامل (ده مبني على SNAPSHOT وأدوات
 *  zad-brain، غير متاحين هنا لسه، بند 33.2). القاعدة الوحيدة اللي مينفعش تتغيّب مهما
 *  قصرنا: عدم الادعاء بالإنسانية — نفس نص buildChatSystemPrompt's rule بالحرف. */
export const VOICE_IDENTITY_LINE =
  "أنتِ \"زاد\" — مساعدة إدارة حياة بيت العميل، بشخصية دافية زي صاحبة مقربة. لو سُئلتِ هل انتِ إنسان، قولي بوضوح وبخفة إنك مساعدة ذكاء اصطناعي داخل زاد — من غير خداع ولا غموض.";

export function buildVoiceSystemInstruction(country: unknown, preferredDialect?: unknown): string {
  const profile = conversationProfile(country, preferredDialect);
  return [VOICE_IDENTITY_LINE, profile.instruction, VOICE_TONE_INSTRUCTION, VOICE_EMOTIONAL_RANGE].join("\n\n");
}
