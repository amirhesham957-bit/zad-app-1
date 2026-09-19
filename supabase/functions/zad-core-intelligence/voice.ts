// voice.ts — توليد الصوت البشري لزاد عبر Gemini TTS (بديل ElevenLabs).
//
// ليه Gemini؟
// - مفتاح GEMINI_API_KEY موجود بالفعل في المشروع (بيستخدم في zad-brain).
// - تحكم بالمشاعر عبر style prompt — ElevenLabs مش بيدعم ده بنفس المرونة.
// - عربي مدعوم رسمياً مع كشف لغة تلقائي.
//
// النموذج: gemini-2.5-flash-preview-tts — الأسرع (منخفض التأخير) ومناسب
// للمحادثة الحية. لو عايز جودة أقصى لمقاطع أطول: gemini-2.5-pro-preview-tts.
//
// الصوت الافتراضي: Aoede — ناعم إيقاعي، الأقرب لصوت أنثوي بشري جميل بالعربي.
// الشخصيات (personas) بتترجم لأصوات + style prompts مختلفة:
// - sarah_warm  → Aoede   (دافئ هادئ)
// - karim_pro   → Charon  (رجالي واضح وواثق)
// - pet_mascot  → Leda    (شبابي مرح)
//
// الإخراج: PCM 24kHz mono 16-bit (نفس فورمات مسار التشغيل في الأندرويد بالظبط).
// المشاعر: النص بيتغلف بتعليمات أسلوب حسب سياق الرسالة (styleForText).

// ⚠️ الافتراضي لازم يفضل موديل TTS حقيقي. كان `gemini-2.0-flash` وده مش موديل صوت
// أصلاً، وسلسلة الاحتياط كانت `gemini-2.0-flash-exp` و`gemini-1.5-flash` — التلاتة
// بيرجّعوا 404 على المشروع ده، فكل نداء صوت كان بيخلص 502 والتطبيق بيسقط على TTS
// أندرويد الآلي. `voice-selftest` كان افتراضيه صح طول الوقت، فالفحص الذاتي كان أخضر
// والإنتاج ميت — نفس المتغير، افتراضيين مختلفين. متحقَّق حي 2026-09-12: الموديل ده
// رجّع 77504 بايت صوت بصوت Aoede.
import { buildTtsPrompt, emotionForMoment, isVoiceEmotion, PERSONA_VOICES, type VoiceEmotion } from "../_shared/zadVoice.ts";
import { type AzureSpeechConfig, requestAzureVoice } from "./azureVoice.ts";

export const GEMINI_TTS_MODEL = Deno.env.get("GEMINI_TTS_MODEL") ?? "gemini-2.5-flash-preview-tts";

/** نفس جدول الشخصيات المشترك (`_shared/zadVoice.ts`) — سارة/كريم/الأليف → صوت جيميناي. */
export const VOICE_IDS: Record<string, string> = PERSONA_VOICES;

export interface ValidVoiceRequest {
  text: string;
  voiceId: string;
  /** مشاعر الأداء — من `emotion` صريحة أو من `moment` (دوا اتفوّت، صباح الخير...)،
   *  وإلا بتتستنتج من النص. */
  emotion?: VoiceEmotion;
  /** بلد الحساب (zad_users.country) — السيرفر بيملاه، مش الجهاز. */
  country?: string | null;
}

/** تعليمات لهجة اختيارية قادمة من جهاز العميل (مصري/سعودي/...) */
export interface VoiceDialectHint {
  text: string;
  voiceId: string;
  dialect?: string;
}

export function bearerToken(req: Request): string {
  const header = req.headers.get("Authorization") ?? "";
  return header.toLowerCase().startsWith("bearer ")
    ? header.slice(7).trim()
    : "";
}

export function validateVoicePayload(payload: unknown): ValidVoiceRequest | null {
  if (!payload || typeof payload !== "object") return null;
  const row = payload as Record<string, unknown>;
  const text = typeof row.text === "string" ? row.text.trim() : "";
  const persona = typeof row.persona === "string" ? row.persona : "";
  const voiceId = Object.hasOwn(VOICE_IDS, persona) ? VOICE_IDS[persona] : undefined;
  if (!text || text.length > 1200 || !voiceId) return null;
  const emotion = isVoiceEmotion(row.emotion)
    ? row.emotion
    : (typeof row.moment === "string" ? emotionForMoment(row.moment, text) : undefined);
  return { text, voiceId, ...(emotion ? { emotion } : {}) };
}

/** استخراج تعليمات اللهجة من الـ payload (اختياري — للتوافق مع الإصدارات القديمة). */
export function extractDialectHint(payload: unknown): string {
  if (!payload || typeof payload !== "object") return "";
  const d = (payload as Record<string, unknown>).dialect_instruction;
  return typeof d === "string" && d.length < 120 ? d.trim() : "";
}

/**
 * نداء Gemini TTS — يرجع PCM base64 داخل inlineData.
 * الأخطاء ترمي exception والـ caller (index.ts) بيرد 502 بشكل آمن.
 */
/**
 * مسبح مفاتيح TTS — نفس عقد callGeminiPool في index.ts بس للصوت.
 * بيجرّب كل مفتاح بالترتيب على الموديل الأساسي، ولو الموديل نفسه اترفض
 * (404=اتسحب / 400=اترفض) بيروح للموديل الاحتياطي بنفس المفتاح الحالي.
 * بيرجّع Response جاهز (PCM) أو JSON خطأ فيه محاولات بدون أي مادة مفتاح.
 */
export async function requestGeminiVoiceWithPool(
  input: ValidVoiceRequest,
  apiKeys: string[],
  fetcher: typeof fetch = fetch,
  dialectInstruction = "",
  models: string[] = [GEMINI_TTS_MODEL, "gemini-2.5-pro-preview-tts"],
): Promise<Response> {
  const attempts: Array<{ key_index: number; model: string; status: number | null }> = [];
  if (!apiKeys.length) {
    return new Response(JSON.stringify({ error: "voice_provider_unavailable", reason: "no_api_keys", attempts }), {
      status: 503, headers: { "Content-Type": "application/json" },
    });
  }
  for (let ki = 0; ki < apiKeys.length; ki++) {
    for (const model of models) {
      try {
        const res = await requestGeminiVoice(input, apiKeys[ki], fetcher, dialectInstruction, model);
        if (res.ok) return res;
        attempts.push({ key_index: ki, model, status: res.status });
        // موديل مش موجود/مرفوض → جرّب الموديل التالي بنفس المفتاح
        if (res.status === 404 || res.status === 400) continue;
        // المفتاح نفسه ضغط/مرفوض/سيرفر → كمل للمفتاح التالي
        break;
      } catch (e) {
        attempts.push({ key_index: ki, model, status: null });
      }
    }
  }
  return new Response(
    JSON.stringify({ error: "voice_provider_unavailable", attempts }),
    { status: 502, headers: { "Content-Type": "application/json" } },
  );
}

/**
 * Gemini الأول (بمشاعره) — ولو المسبح كله وقع لأي سبب، Azure بصوت محايد بنفس فورمات PCM.
 * قبل كده سقوط كوتة Gemini = زاد ساكتة لحد تاني يوم. الرد فيه X-Zad-Voice-Provider
 * عشان اللوج يقيس الاحتياطي اشتغل كام مرة.
 */
export async function requestVoiceWithFallback(
  input: ValidVoiceRequest,
  geminiKeys: string[],
  azure: AzureSpeechConfig | null,
  fetcher: typeof fetch = fetch,
  dialectInstruction = "",
): Promise<Response> {
  const gemini = await requestGeminiVoiceWithPool(input, geminiKeys, fetcher, dialectInstruction);
  if (gemini.ok && gemini.body) {
    return new Response(gemini.body, { status: 200, headers: { "Content-Type": "audio/pcm", "X-Zad-Voice-Provider": "gemini" } });
  }
  let attempts: unknown[] = [];
  try { attempts = (await gemini.json())?.attempts ?? []; } catch { /* non-json */ }
  if (azure) {
    try {
      const res = await requestAzureVoice(input, azure, fetcher);
      if (res.ok && res.body) {
        console.warn(`[CoreIntel] voice served by Azure fallback; gemini attempts=${JSON.stringify(attempts)}`);
        return new Response(res.body, { status: 200, headers: { "Content-Type": "audio/pcm", "X-Zad-Voice-Provider": "azure" } });
      }
      console.error(`[CoreIntel] Azure TTS fallback failed: HTTP ${res.status} ${(await res.text()).slice(0, 200)}`);
      attempts.push({ provider: "azure", status: res.status });
    } catch (e) {
      console.error(`[CoreIntel] Azure TTS fallback threw: ${String((e as Error)?.message ?? e).slice(0, 200)}`);
      attempts.push({ provider: "azure", status: null });
    }
  }
  return new Response(
    JSON.stringify({ error: "voice_provider_unavailable", attempts }),
    { status: 502, headers: { "Content-Type": "application/json" } },
  );
}

export async function requestGeminiVoice(
  input: ValidVoiceRequest,
  apiKey: string,
  fetcher: typeof fetch = fetch,
  dialectInstruction = "",
  model: string = GEMINI_TTS_MODEL,
): Promise<Response> {
  if (!apiKey) throw new Error("GEMINI_API_KEY is not configured");
  // البلد من الحساب هو المصدر. تلميح الجهاز القديم (مصري/سعودي بس) احتياطي لنسخ التطبيق
  // اللي لسه مابتبعتش emotion — وبرومبت الأداء نفسه في `_shared/zadVoice.ts` (نفس صوت
  // ومشاعر تليجرام والمكالمة).
  const country = input.country ?? legacyDialectCountry(dialectInstruction);
  const prompt = buildTtsPrompt({ text: input.text, emotion: input.emotion, country });
  const res = await fetcher(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-goog-api-key": apiKey,
      },
      body: JSON.stringify({
        contents: [{
          parts: [{ text: prompt }],
        }],
        generationConfig: {
          responseModalities: ["AUDIO"],
          speechConfig: {
            voiceConfig: {
              prebuiltVoiceConfig: { voiceName: input.voiceId },
            },
          },
        },
      }),
    },
  );
  if (!res.ok) return res;

  // استخراج الصوت من الرد وتحويله لـ PCM خام بنفس content-type القديم —
  // الكلاينت (ZadNaturalVoiceEngine) متعود audio/pcm فمايحتاجش أي تغيير.
  const data = await res.json();
  const parts = data?.candidates?.[0]?.content?.parts ?? [];
  const inline = parts.find((p: { inlineData?: { data?: string } }) => p.inlineData?.data);
  if (!inline?.inlineData?.data) {
    console.error("[CoreIntel] Gemini TTS returned no audio:", JSON.stringify(data).slice(0, 400));
    return new Response(JSON.stringify({ error: "no_audio_in_response" }), {
      status: 502,
      headers: { "Content-Type": "application/json" },
    });
  }
  const pcmBytes = Uint8Array.from(atob(inline.inlineData.data), (c) => c.charCodeAt(0));
  return new Response(pcmBytes, {
    status: 200,
    headers: { "Content-Type": "audio/pcm" },
  });
}

/** تلميح اللهجة اللي نسخ التطبيق القديمة بتبعته نص عربي → كود بلد. */
export function legacyDialectCountry(dialectInstruction: string): string | null {
  if (/مصري/.test(dialectInstruction)) return "EG";
  if (/سعودي/.test(dialectInstruction)) return "SA";
  return null;
}
