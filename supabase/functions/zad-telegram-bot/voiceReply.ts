// voiceReply.ts — رد الشات بصوت زاد على تليجرام (ZAD_LIVING_BRAIN.md الشريحة ١٣).
//
// المالك (٢٠٢٦-١٠-٠٣): الجداول والفواتير والقوايم نص (كفاءة وكوتة)؛ الاطمئنان والدعم والتشجيع
// والعتاب الخفيف فويس — «إحساس بالمبادرة والوعي». القرار هنا بالكود من الرد نفسه، مش من الموديل:
// إيصال تنفيذ أو قايمة أو أرقام كتير ⇒ نص؛ العميل بعت فويس ⇒ رد بفويس (نفس القناة)؛ غير كده فويس
// بس لو الرد فيه إحساس واضح. والنص بيتبعت الأول دايماً — الفويس زيادة، مش بديل.

import { ALERT_SPEECH_MAX_CHARS } from "./voiceAlert.ts";
import { inferEmotion, type VoiceEmotion } from "../_shared/zadVoice.ts";

/** إحساس يستاهل صوت لوحده (من غير ما العميل يبعت فويس). */
const EMOTIONAL: ReadonlySet<VoiceEmotion> = new Set<VoiceEmotion>([
  "proud", "caring", "sad", "worried", "reproachful", "sulky", "tender", "cheerful",
]);

/**
 * الإحساس اللي الرد يتقال بيه، أو null = يفضل نص. [transactional] = الرد مستني زرار تأكيد أو
 * إعلان — ده تنفيذ، مش كلام.
 */
export function voiceReplyEmotion(input: { text: string; inboundVoice: boolean; transactional: boolean }): VoiceEmotion | null {
  if (input.transactional) return null;
  const text = input.text.trim();
  if (!text || text.length > ALERT_SPEECH_MAX_CHARS) return null;
  const lines = text.split("\n").map((l) => l.trim()).filter(Boolean);
  // إيصالات التنفيذ («✅ تم…»)، والتحذيرات، والقوايم والجداول.
  if (lines.some((l) => /^(?:[-•*▪]|\d+[.)]|✅|⚠️|🔒|📌|❌|\|)/u.test(l))) return null;
  if ((text.match(/\d[\d,.٫]*/g) ?? []).length > 3) return null;
  const emotion = inferEmotion(text);
  if (input.inboundVoice) return emotion;
  return EMOTIONAL.has(emotion) ? emotion : null;
}
