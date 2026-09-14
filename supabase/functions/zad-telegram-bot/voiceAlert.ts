// voiceAlert.ts — فويس نوت بصوت زاد (سارة = Aoede) مع التنبيهات المالية الحرجة على تليجرام.
//
// ليه: التنبيه الحرج (الميزانية خلصت، إشعارات البنك وقفت، الصرف أسرع من السقف) كان نص
// بيتقري زي أي رسالة معاملة عادية ويتنسي في نفس الشات. فويس بنفس الصوت اللي بيقرا
// الإشعارات جوه التطبيق وبيرد في المكالمة بيلفت الانتباه — صوت واحد في التلات قنوات.
//
// التصميم:
// - مين يقرر إن التنبيه حرج؟ اللي بيبعته (تريجر الداتابيز / zad-brain) عن طريق `voice: true`
//   في طلب realtime_push. البوت مابيخمّنش من النص.
// - النص بيتبعت الأول وعلى طول؛ الفويس بعده في الخلفية. فشل الصوت مابيأخّرش ولا بيلغي
//   التنبيه نفسه.
// - Gemini TTS بيرجّع PCM خام 24kHz، وتليجرام sendVoice بيقبل OGG/Opus أو MP3 أو M4A —
//   فبنحوّل لـMP3 بـlamejs (JS خالص، مفيش ffmpeg على الـedge). اتقاس 2026-09-14: ١٥ ثانية
//   كلام = ~0.4 ثانية CPU، والنص مقصوص عشان يفضل تحت ده بكتير.

import { Mp3Encoder } from "npm:@breezystack/lamejs@1.2.7";

export const ALERT_TTS_MODELS = ["gemini-2.5-flash-preview-tts", "gemini-2.5-pro-preview-tts"];
/** نفس صوت سارة في `zad-core-intelligence/voice.ts` (VOICE_IDS.sarah_warm) والمكالمة الحية. */
export const ALERT_VOICE_NAME = "Aoede";
export const ALERT_SPEECH_MAX_CHARS = 320;
const PCM_SAMPLE_RATE = 24_000;

/** طلب realtime_push عايز فويس؟ `true` صريحة بس — أي قيمة تانية = نص بس زي الأول. */
export function wantsVoice(payload: unknown): boolean {
  return !!payload && typeof payload === "object" && (payload as { voice?: unknown }).voice === true;
}

/**
 * نص الكلام من عنوان التنبيه ونصه: من غير إيموجي (المحرك بينطق أسماءها أو بيتلخبط)،
 * ومن غير رموز Markdown، ومقصوص على آخر جملة كاملة قبل الحد.
 */
export function alertSpeechText(title: string, body: string, maxChars = ALERT_SPEECH_MAX_CHARS): string {
  const clean = (s: string) =>
    s
      .replace(/[\p{Extended_Pictographic}\u{FE0F}\u{200D}]/gu, "")
      .replace(/[*_`#>|~]/g, "")
      .replace(/\s+/g, " ")
      .trim();
  const t = clean(title);
  const b = clean(body);
  const joined = t && b ? `${t}. ${b}` : (t || b);
  if (joined.length <= maxChars) return joined;
  const cut = joined.slice(0, maxChars);
  const lastStop = Math.max(cut.lastIndexOf("."), cut.lastIndexOf("،"), cut.lastIndexOf("؟"), cut.lastIndexOf("!"));
  return (lastStop > maxChars * 0.5 ? cut.slice(0, lastStop + 1) : cut).trim();
}

/** PCM 16-bit little-endian mono → MP3. */
export function pcmToMp3(pcm: Uint8Array, sampleRate = PCM_SAMPLE_RATE, kbps = 48): Uint8Array<ArrayBuffer> {
  const samples = new Int16Array(pcm.buffer, pcm.byteOffset, Math.floor(pcm.byteLength / 2));
  const encoder = new Mp3Encoder(1, sampleRate, kbps);
  const chunks: Uint8Array[] = [];
  for (let i = 0; i < samples.length; i += 1152) {
    const out = encoder.encodeBuffer(samples.subarray(i, i + 1152));
    if (out.length) chunks.push(new Uint8Array(out));
  }
  const tail = encoder.flush();
  if (tail.length) chunks.push(new Uint8Array(tail));
  const result = new Uint8Array(chunks.reduce((n, c) => n + c.length, 0));
  let offset = 0;
  for (const c of chunks) {
    result.set(c, offset);
    offset += c.length;
  }
  return result;
}

/**
 * يولّد PCM بصوت زاد لنص التنبيه. نفس عقد مسبح zad-core-intelligence: كل مفتاح بالترتيب،
 * موديل مرفوض (404/400) → الموديل اللي بعده بنفس المفتاح، ضغط/خطأ سيرفر → المفتاح اللي
 * بعده. null لو كله فشل — والسبب بيتسجّل من غير أي مادة مفتاح.
 */
export async function synthesizeAlertPcm(
  text: string,
  apiKeys: string[],
  fetcher: typeof fetch = fetch,
): Promise<Uint8Array | null> {
  if (!text || apiKeys.length === 0) return null;
  const attempts: string[] = [];
  const prompt =
    "اقرأ النص التالي بصوت واضح وطبيعي — ولّد الصوت فقط من دون أي نص مكتوب.\n\n" +
    "اقرأ بنبرة هادئة لكن جادة، بإيقاع أبطأ شوية، كأخت بتنبّه أخوها لحاجة مهمة تخص فلوسه — من غير تهويل.\n\n" +
    `${text}\n\nالآن ولّد الصوت لهذا النص.`;
  for (let ki = 0; ki < apiKeys.length; ki++) {
    for (const model of ALERT_TTS_MODELS) {
      try {
        const res = await fetcher(
          `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
          {
            method: "POST",
            headers: { "Content-Type": "application/json", "x-goog-api-key": apiKeys[ki] },
            body: JSON.stringify({
              contents: [{ parts: [{ text: prompt }] }],
              generationConfig: {
                responseModalities: ["AUDIO"],
                speechConfig: { voiceConfig: { prebuiltVoiceConfig: { voiceName: ALERT_VOICE_NAME } } },
              },
            }),
          },
        );
        if (!res.ok) {
          attempts.push(`k${ki}/${model}:${res.status}`);
          await res.body?.cancel();
          if (res.status === 404 || res.status === 400) continue;
          break;
        }
        const data = await res.json();
        const parts = data?.candidates?.[0]?.content?.parts ?? [];
        const inline = parts.find((p: { inlineData?: { data?: string } }) => p?.inlineData?.data);
        if (!inline) {
          attempts.push(`k${ki}/${model}:no_audio`);
          continue;
        }
        return Uint8Array.from(atob(inline.inlineData.data), (c) => c.charCodeAt(0));
      } catch (_e) {
        attempts.push(`k${ki}/${model}:threw`);
      }
    }
  }
  console.error(`[voiceAlert] TTS failed on every key/model: ${attempts.join(", ")}`);
  return null;
}

/** نفس مسبح مفاتيح جيميناي في باقي الفانكشنز (ZAD_API_KEY_1..5، وبعدها المفرد القديم). */
export function geminiKeysFromEnv(get: (name: string) => string | undefined = (n) => Deno.env.get(n)): string[] {
  const keys = [1, 2, 3, 4, 5].map((n) => get(`ZAD_API_KEY_${n}`)).filter((k): k is string => !!k);
  if (keys.length === 0) {
    const legacy = get("ZAD_API_KEY") || get("GEMINI_API_KEY");
    if (legacy) keys.push(legacy);
  }
  return keys;
}
