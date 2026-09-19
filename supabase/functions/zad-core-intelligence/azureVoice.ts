// azureVoice.ts — احتياطي صوت زاد لما مسبح Gemini TTS كله يقع (كوتة/سيرفر/شبكة).
//
// قرار المستخدم ٢٠٢٦-٠٩-١٩: Azure Speech F0 احتياطي رسمي، و Gemini يفضل الأساسي.
// - نفس أصوات «edge-tts» بالظبط (ar-EG-SalmaNeural...) بس من الـAPI الرسمي. edge-tts نفسه
//   انتحال لمتصفح Edge (توكن مستخرج + DRM Sec-MS-GEC) ومخالف لشروط مايكروسوفت — اترفض.
// - الفورمات raw-24khz-16bit-mono-pcm = اللي ZadNaturalVoiceEngine بيكتبه في AudioTrack
//   بالظبط، فالأندرويد مايعرفش مين رد ومحتاجش أي تعديل.
// - أصوات مايكروسوفت العربية مالهاش mstts:express-as، يعني مفيش مشاعر تمثيلية. عشان كده
//   ده احتياطي بس: مشاعر Gemini (EMOTION_DIRECTIONS) ماتتلمسش، وهنا نطق محايد بلهجة البلد.
//
// الأسرار: AZURE_SPEECH_KEY + AZURE_SPEECH_REGION (مثلاً westeurope). غياب أي واحد = مقفول.

import { countryCode, PERSONA_VOICES } from "../_shared/zadVoice.ts";

export const AZURE_OUTPUT_FORMAT = "raw-24khz-16bit-mono-pcm";

export interface AzureSpeechConfig {
  key: string;
  region: string;
}

export function azureSpeechConfig(env: (name: string) => string | undefined): AzureSpeechConfig | null {
  const key = env("AZURE_SPEECH_KEY")?.trim() ?? "";
  const region = env("AZURE_SPEECH_REGION")?.trim().toLowerCase() ?? "";
  // الريجن بيدخل في اسم الهوست — أي حاجة غير حروف وأرقام = سر متظبط غلط، مش هوست تاني.
  if (!key || !/^[a-z0-9]+$/.test(region)) return null;
  return { key, region };
}

/** [أنثى، ذكر] — الأسماء من كتالوج مايكروسوفت الحي (٢٠٢٦-٠٩-١٩: ٣٢ صوت عربي في ١٦ بلد). */
const COUNTRY_VOICES: Record<string, [string, string]> = {
  EG: ["ar-EG-SalmaNeural", "ar-EG-ShakirNeural"],
  SA: ["ar-SA-ZariyahNeural", "ar-SA-HamedNeural"],
  AE: ["ar-AE-FatimaNeural", "ar-AE-HamdanNeural"],
  KW: ["ar-KW-NouraNeural", "ar-KW-FahedNeural"],
  QA: ["ar-QA-AmalNeural", "ar-QA-MoazNeural"],
  BH: ["ar-BH-LailaNeural", "ar-BH-AliNeural"],
  OM: ["ar-OM-AyshaNeural", "ar-OM-AbdullahNeural"],
  JO: ["ar-JO-SanaNeural", "ar-JO-TaimNeural"],
  LB: ["ar-LB-LaylaNeural", "ar-LB-RamiNeural"],
  IQ: ["ar-IQ-RanaNeural", "ar-IQ-BasselNeural"],
  SY: ["ar-SY-AmanyNeural", "ar-SY-LaithNeural"],
  YE: ["ar-YE-MaryamNeural", "ar-YE-SalehNeural"],
  LY: ["ar-LY-ImanNeural", "ar-LY-OmarNeural"],
  MA: ["ar-MA-MounaNeural", "ar-MA-JamalNeural"],
  TN: ["ar-TN-ReemNeural", "ar-TN-HediNeural"],
  DZ: ["ar-DZ-AminaNeural", "ar-DZ-IsmaelNeural"],
  // مفيش صوت فلسطيني ولا سوداني في الكتالوج — الأقرب لهجةً.
  PS: ["ar-JO-SanaNeural", "ar-JO-TaimNeural"],
  SD: ["ar-EG-SalmaNeural", "ar-EG-ShakirNeural"],
};
const TURKISH: [string, string] = ["tr-TR-EmelNeural", "tr-TR-AhmetNeural"];
const ENGLISH: [string, string] = ["en-US-JennyNeural", "en-US-GuyNeural"];

/**
 * الصوت من لغة النص الأول وبعدها بلد الحساب. صوت عربي بيقرا نص تركي/إنجليزي = كلام
 * مش مفهوم، فالبلد لوحده مايكفيش. عربي من بلد مش معروف = مصري (سوق زاد الأساسي).
 */
export function azureVoiceFor(text: string, country: unknown, geminiVoiceId: string): string {
  const pair = /[؀-ۿ]/.test(text)
    ? COUNTRY_VOICES[countryCode(country) ?? "EG"] ?? COUNTRY_VOICES.EG
    : countryCode(country) === "TR" || /[ğşıİĞŞ]/.test(text)
    ? TURKISH
    : ENGLISH;
  // كريم هو الشخصية الرجالي الوحيدة؛ سارة والأليف أصوات بنات.
  return pair[geminiVoiceId === PERSONA_VOICES.karim_pro ? 1 : 0];
}

/** Gemini بيسكت على الإيموجي؛ مايكروسوفت بيقرا اسمها بصوت عالي («وجه ضاحك»). */
export function speakableText(text: string): string {
  return text.replace(/[\p{Extended_Pictographic}\u{FE0F}\u{200D}]/gu, "").replace(/\s{2,}/g, " ").trim();
}

function escapeXml(text: string): string {
  return text.replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&apos;" })[c]!);
}

/** نص العميل بيتعمله escape — مايقدرش يفتح وسم SSML ويغيّر الصوت أو يحقن تعليمات. */
export function buildAzureSsml(text: string, voice: string): string {
  return `<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='${voice.slice(0, 5)}'>` +
    `<voice name='${voice}'>${escapeXml(text)}</voice></speak>`;
}

/**
 * نداء Azure TTS. بيرجّع رد مايكروسوفت زي ما هو (body = PCM stream) عشان أول بايتات
 * توصل للموبايل قبل ما الجملة تخلص. المهلة على الهيدرز بس — مهلة على الـbody كانت
 * هتقطع صوت جملة طويلة في النص.
 */
export async function requestAzureVoice(
  input: { text: string; voiceId: string; country?: string | null },
  config: AzureSpeechConfig,
  fetcher: typeof fetch = fetch,
): Promise<Response> {
  const text = speakableText(input.text);
  if (!text) return new Response(JSON.stringify({ error: "nothing_to_speak" }), { status: 400 });
  const ssml = buildAzureSsml(text, azureVoiceFor(text, input.country, input.voiceId));
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), 15_000);
  try {
    return await fetcher(`https://${config.region}.tts.speech.microsoft.com/cognitiveservices/v1`, {
      method: "POST",
      headers: {
        "Ocp-Apim-Subscription-Key": config.key,
        "Content-Type": "application/ssml+xml",
        "X-Microsoft-OutputFormat": AZURE_OUTPUT_FORMAT,
        "User-Agent": "zad-core-intelligence",
      },
      body: ssml,
      signal: ctrl.signal,
    });
  } finally {
    clearTimeout(timer);
  }
}

/** فحص ما بعد النشر (provider_health): جملة قصيرة، الحالة وعدد البايتات بس — ولا مفتاح. */
export async function azureTtsHealth(config: AzureSpeechConfig | null, fetcher: typeof fetch = fetch): Promise<Record<string, unknown>> {
  if (!config) return { configured: false };
  try {
    const res = await requestAzureVoice({ text: "أهلاً، أنا زاد.", voiceId: PERSONA_VOICES.sarah_warm, country: "EG" }, config, fetcher);
    const bytes = (await res.arrayBuffer()).byteLength;
    return { configured: true, region: config.region, status: res.status, audio_bytes: res.ok ? bytes : 0 };
  } catch (e) {
    return { configured: true, region: config.region, error: String((e as Error)?.message ?? e).slice(0, 120) };
  }
}
