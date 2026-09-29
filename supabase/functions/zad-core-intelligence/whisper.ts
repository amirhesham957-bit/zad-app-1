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

/**
 * جمل Whisper بيألفها لما الصوت فاضي أو صمت — متعلّمها من ترجمات يوتيوب في آخر الفيديو.
 * تجربة صاحب المشروع ٢٠٢٦-٠٩-٢٨: المساعد الصوتي «سمع» «اشتركوا في القناة» ٣ مرات ورا بعض
 * ورد عليها كأنها كلامه. بتتشال بس لما تكون هي كل التفريغ — جملة حقيقية فيها الكلمة دي عادي.
 */
const HALLUCINATIONS = [
  "اشتركوا في القناة",
  "اشترك في القناة",
  "لا تنسوا الاشتراك في القناة",
  "شكرا للمشاهدة",
  "شكرا على المشاهدة",
  "ترجمة نانسي قنقر",
  "نانسي قنقر",
  "موسيقى",
  "thanks for watching",
  "thank you for watching",
  "subscribe to the channel",
  "subtitles by the amara.org community",
];

function normalize(s: string): string {
  return s.toLowerCase()
    .replace(/[ً-ْـ]/g, "") // تشكيل وتطويل
    .replace(/[إأآ]/g, "ا").replace(/ى/g, "ي").replace(/ة/g, "ه")
    .replace(/[^\p{L}\p{N}\s.]/gu, " ")
    .replace(/\s+/g, " ")
    .trim()
    .replace(/[.\s]+$/, "");
}

const HALLUCINATION_SET = new Set(HALLUCINATIONS.map(normalize));

type WhisperSegment = { text?: string; no_speech_prob?: number; avg_logprob?: number };

/**
 * النص اللي اتقال فعلاً من رد Whisper (verbose_json)، أو null لو مفيش كلام.
 *
 * ١) أي segment Whisper نفسه شايفه صمت بيتشال — نفس قاعدته: no_speech_prob > 0.6 مع
 *    avg_logprob < -1 (الاتنين مع بعض، عشان كلام واطي بثقة كويسة مايتشالش).
 * ٢) لو اللي فاضل هو جملة من [HALLUCINATIONS] أو جملة الإرشاد نفسها (Whisper ساعات بيرجّع
 *    الـprompt لما مفيش صوت) ⇒ مفيش كلام.
 */
export function spokenText(data: unknown, prompt?: string): string | null {
  const d = (data ?? {}) as { text?: string; segments?: WhisperSegment[] };
  let text: string;
  if (Array.isArray(d.segments) && d.segments.length > 0) {
    text = d.segments
      .filter((s) => !((s.no_speech_prob ?? 0) > 0.6 && (s.avg_logprob ?? 0) < -1))
      .map((s) => s.text ?? "")
      .join(" ");
  } else {
    text = d.text ?? "";
  }
  text = text.replace(/\s+/g, " ").trim();
  if (!text) return null;
  const n = normalize(text);
  if (!n || HALLUCINATION_SET.has(n)) return null;
  if (prompt && n === normalize(prompt)) return null;
  return text;
}

/** إعدادات Whisper لبلد الحساب ([country] كود أو اسم عربي، أو null). */
export function whisperOptions(country: unknown): WhisperOptions {
  const code = countryCode(country);
  if (code === "TR") return { language: "tr" };
  if (code && DIALECT_HINT[code]) return { language: "ar", prompt: DIALECT_HINT[code] };
  return {};
}
