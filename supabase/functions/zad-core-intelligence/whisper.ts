// لغة Whisper ولهجته من بلد الحساب.
//
// transcribeAudio كان بيبعت language=ar ثابت لكل الناس (٢٠٢٦-٠٩-٢٧): عميل تركي أو بيتكلم
// إنجليزي كان كلامه بيتفرّغ عربي غلط، وعميل مصري ماكانش Whisper بيعرف إنه بيسمع عامية
// مصرية. دلوقتي: بلد عربي = ar + جملة إرشاد بمفردات لهجته (Whisper بيستخدم الـprompt كسياق
// سابق، فبيقرّب التفريغ من كتابة اللهجة: «عايز» مش «أريد»، «دلوقتي» مش «الآن»)؛ تركيا = tr؛
// بلد مش معروف = من غير language خالص، Whisper يكتشف اللغة لوحده.
import { countryCode } from "../_shared/zadVoice.ts";

export interface WhisperOptions {
  language?: string;
  prompt?: string;
}

// ⚠️ بيانات لهجات للموديل، مش نصوص واجهة — ماتترجمهاش.
const EGYPT = "عايز، دلوقتي، ازاي، فين، كام، جنيه، اشتريت، دفعت، صرفت.";
const GULF = "أبي، أبغى، وش، كم، الحين، زين، ريال، دفعت، شريت.";
const LEVANT = "بدي، هلق، شو، قديش، منيح، ليرة، دينار، دفعت، اشتريت.";
const IRAQ = "أريد، هسه، شكد، شنو، زين، دينار، دفعت، اشتريت.";
const MAGHREB = "بغيت، دابا، شحال، واش، درهم، دينار، خلصت، شريت.";

const DIALECT_HINT: Record<string, string> = {
  EG: EGYPT, SD: EGYPT,
  SA: GULF, AE: GULF, KW: GULF, QA: GULF, BH: GULF, OM: GULF, YE: GULF,
  JO: LEVANT, LB: LEVANT, SY: LEVANT, PS: LEVANT,
  IQ: IRAQ,
  MA: MAGHREB, TN: MAGHREB, DZ: MAGHREB, LY: MAGHREB,
};

/** إعدادات Whisper لبلد الحساب ([country] كود أو اسم عربي، أو null). */
export function whisperOptions(country: unknown): WhisperOptions {
  const code = countryCode(country);
  if (code === "TR") return { language: "tr" };
  if (code && DIALECT_HINT[code]) return { language: "ar", prompt: DIALECT_HINT[code] };
  return {};
}
