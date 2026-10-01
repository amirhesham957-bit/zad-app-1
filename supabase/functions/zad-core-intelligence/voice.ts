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
// صوت واحد اسمه زاد (قرار المالك ٢٠٢٦-٠٩-٢٧): أي persona بيوصل — sarah_warm/karim_pro/
// pet_mascot من نسخ قديمة، أو مفيش — بيطلع Aoede بلهجة بلد الحساب.
//
// الإخراج: PCM 24kHz mono 16-bit (نفس فورمات مسار التشغيل في الأندرويد بالظبط).
// المشاعر: النص بيتغلف بتعليمات أسلوب حسب سياق الرسالة (styleForText).

// ⚠️ الافتراضي لازم يفضل موديل TTS حقيقي. كان `gemini-2.0-flash` وده مش موديل صوت
// أصلاً، وسلسلة الاحتياط كانت `gemini-2.0-flash-exp` و`gemini-1.5-flash` — التلاتة
// بيرجّعوا 404 على المشروع ده، فكل نداء صوت كان بيخلص 502 والتطبيق بيسقط على TTS
// أندرويد الآلي. `voice-selftest` كان افتراضيه صح طول الوقت، فالفحص الذاتي كان أخضر
// والإنتاج ميت — نفس المتغير، افتراضيين مختلفين. متحقَّق حي 2026-09-12: الموديل ده
// رجّع 77504 بايت صوت بصوت Aoede.
import { buildTtsPrompt, emotionForMoment, GEMINI_TTS_CHAIN, inferEmotion, isVoiceEmotion, PERSONA_VOICES, voiceForPersona, type VoiceEmotion } from "../_shared/zadVoice.ts";
import { type AzureSpeechConfig, requestAzureVoice } from "./azureVoice.ts";

/**
 * إحساس رد الشات كله: من أول جملة فيه (`feeling_from` من التطبيق)، ونفس الإحساس لكل
 * حتة في الرد. كان كل جملة بتاخد إحساس من كلامها («صوتين»)، وبعدها كله بقى «warm» ثابت
 * (#51) فالرد طلع من غير مشاعر. أول جملة واحدة لكل الحتت = مشاعر وصوت واحد (٢٠٢٦-١٠-٠٢).
 * نسخة تطبيق قديمة مابتبعتهاش ⇒ «warm» زي #51.
 */
export function chatReplyEmotion(feelingFrom: unknown): VoiceEmotion {
  return typeof feelingFrom === "string" && feelingFrom.trim()
    ? inferEmotion(feelingFrom.slice(0, 400))
    : "warm";
}

export const GEMINI_TTS_MODEL = Deno.env.get("GEMINI_TTS_MODEL") ?? "gemini-2.5-flash-preview-tts";
/** جملة قصيرة بتتقرا في ثواني؛ أكتر من كده يبقى معلّق، والأحسن ننقل للموديل/المفتاح اللي بعده. */
const TTS_TIMEOUT_MS = 10_000;

/**
 * حالة المسبح بين الطلبات (جوه نفس الـinstance).
 *
 * كل طلب صوت كان بيبدأ من المفتاح الأول: مفتاح خلصت كوتته في الدقيقة (TTS المجاني ضيق
 * جداً — نداء واحد ورا التاني رجّع 429، ٢٠٢٦-٠٩-٢٩) كان بيتجرب الأول في كل جملة. ومع حد
 * ٢٠ ثانية لكل محاولة، ٥ مفاتيح × موديلين كانوا ممكن ياخدوا دقايق قبل Azure — «المساعد
 * الصوتي بيأخر في الرد آوي». دلوقتي: البداية بتلف، والمفتاح اللي رجّع 429 بيرتاح دقيقة،
 * وكل محاولات Gemini ليها سقف وقت واحد.
 */
export interface TtsPoolState {
  cursor: number;
  coolingUntil: Map<number, number>;
  /**
   * `مفتاح|موديل` اللي رجّع 429 — الكوتة لكل موديل على كل مفتاح. الزوج اللي خلص بيتساب
   * لحد ما يرتاح، بدل ما كل جملة تجربه تاني وتستنى رفضه (٢٠٢٦-٠٩-٣٠: «المساعد الصوتي
   * بياخد ٤٠ ثانية»). ولو كل الأزواج مرتاحة، Gemini بيتساب فوراً لـAzure.
   */
  pairCoolingUntil: Map<string, number>;
}

export function freshTtsPool(): TtsPoolState {
  return { cursor: 0, coolingUntil: new Map(), pairCoolingUntil: new Map() };
}

const sharedTtsPool = freshTtsPool();
const TTS_COOLDOWN_MS = 60_000;
/** كوتة اليوم خلصت على الزوج ده (`...PerDay...` في رد 429): مفيش فايدة نجربه تاني قريب. */
const TTS_DAY_COOLDOWN_MS = 30 * 60_000;
/**
 * بعده Gemini بيتساب ويتجرب Azure — العميل مستني صوت جملة، مش دقايق. كان ١٥ ثانية، والجملة
 * الأولى كانت بتستنى ده كله قبل ما تتقال لما الكوتة تخلص.
 */
const TTS_POOL_BUDGET_MS = 8_000;

/** ترتيب المفاتيح لطلب واحد: من المؤشر ولفّ، والمرتاحين في الآخر (مش مستبعدين). */
export function ttsKeyOrder(count: number, pool: TtsPoolState, now: number): number[] {
  const start = count > 0 ? pool.cursor % count : 0;
  pool.cursor = count > 0 ? (start + 1) % count : 0;
  const order = Array.from({ length: count }, (_, i) => (start + i) % count);
  const ready = order.filter((k) => (pool.coolingUntil.get(k) ?? 0) <= now);
  const cooling = order.filter((k) => (pool.coolingUntil.get(k) ?? 0) > now);
  return [...ready, ...cooling];
}

/** جدول الأسامي المشترك (`_shared/zadVoice.ts`) — كلها صوت زاد. */
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
  // صوت واحد (زاد): الـpersona اختياري، وأي قيمة — حتى من نسخة قديمة — بتطلع نفس الصوت.
  const voiceId = voiceForPersona(row.persona);
  if (!text || text.length > 1200) return null;
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
/**
 * آخر موديل صوت نطق بنجاح. جمل الرد الواحد بتتولد كل جملة في طلب لوحدها، والسلسلة كانت بتبدأ من
 * أول موديل في كل جملة — فجملة تطلع من موديل وجملة من موديل تاني بصوت مختلف («صوتين في نفس الرد»،
 * المالك ٢٠٢٦-١٠-٠١). الموديل اللي نجح بيتجرب الأول في الجملة اللي بعدها.
 */
let lastGoodTtsModel: string | null = null;

/** ترتيب الموديلات للطلب ده: آخر واحد نجح الأول، والباقي بترتيبه. */
export function stickyModelOrder(models: string[], lastGood: string | null): string[] {
  return lastGood && models.includes(lastGood) ? [lastGood, ...models.filter((m) => m !== lastGood)] : models;
}

export async function requestGeminiVoiceWithPool(
  input: ValidVoiceRequest,
  apiKeys: string[],
  fetcher: typeof fetch = fetch,
  dialectInstruction = "",
  models: string[] = stickyModelOrder([...new Set([GEMINI_TTS_MODEL, ...GEMINI_TTS_CHAIN])], lastGoodTtsModel),
  pool: TtsPoolState = sharedTtsPool,
  now: () => number = Date.now,
): Promise<Response> {
  const attempts: Array<{ key_index: number; model: string; status: number | null }> = [];
  if (!apiKeys.length) {
    return new Response(JSON.stringify({ error: "voice_provider_unavailable", reason: "no_api_keys", attempts }), {
      status: 503, headers: { "Content-Type": "application/json" },
    });
  }
  // موديل رجّع 503 (زحمة على الموديل كله، مش المفتاح) مابيتجربش تاني بمفتاح تاني في نفس الطلب —
  // قبل كده كان بيلف بيه على كل المفاتيح، وده جزء من الـ٣٠-٦٠ ثانية اللي العميل بيستناها.
  const downModels = new Set<string>();
  const startedAt = now();
  const pairCooling = (ki: number, model: string) => (pool.pairCoolingUntil.get(`${ki}|${model}`) ?? 0) > startedAt;
  // كل مفتاح × كل موديل خلص كوتته قريب: ولا نداء — Azure على طول، في ملّي ثانية مش ١٥ ثانية.
  if (apiKeys.every((_, ki) => models.every((m) => pairCooling(ki, m)))) {
    return new Response(JSON.stringify({ error: "voice_provider_unavailable", reason: "pool_cooling", attempts }), {
      status: 503, headers: { "Content-Type": "application/json" },
    });
  }
  keys: for (const ki of ttsKeyOrder(apiKeys.length, pool, startedAt)) {
    for (const model of models) {
      if (downModels.has(model)) continue;
      if (pairCooling(ki, model)) continue;
      if (now() - startedAt > TTS_POOL_BUDGET_MS) {
        console.warn(`[CoreIntel] TTS pool over ${TTS_POOL_BUDGET_MS}ms, giving up on Gemini`);
        break keys;
      }
      try {
        const res = await requestGeminiVoice(input, apiKeys[ki], fetcher, dialectInstruction, model);
        if (res.ok) {
          lastGoodTtsModel = model;
          return res;
        }
        attempts.push({ key_index: ki, model, status: res.status });
        // الكوتة لكل موديل: 429 على موديل = عداده خلص على المفتاح ده، والموديل اللي بعده ليه
        // عداد لوحده بنفس المفتاح. المفتاح بيرتاح في ترتيب الطلبات الجاية بس.
        if (res.status === 429) {
          pool.coolingUntil.set(ki, now() + TTS_COOLDOWN_MS);
          const body = await res.text().catch(() => "");
          const perDay = /per\s*day|perday/i.test(body);
          pool.pairCoolingUntil.set(`${ki}|${model}`, now() + (perDay ? TTS_DAY_COOLDOWN_MS : TTS_COOLDOWN_MS));
          continue;
        }
        if (res.status === 503) {
          downModels.add(model);
          continue;
        }
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
  preferAzure = false,
): Promise<Response> {
  // ردود الشات: سلمى (Azure) الأول لما تكون مضبوطة — نفس الصوت في كل جملة ومن غير كوتة ١٠ نداءات
  // في اليوم (قرار المالك ٢٠٢٦-١٠-٠١). لحظات اليوم بمشاعرها بتفضل على Gemini.
  if (preferAzure && azure) {
    try {
      const res = await requestAzureVoice(input, azure, fetcher);
      if (res.ok && res.body) {
        return new Response(res.body, { status: 200, headers: { "Content-Type": "audio/pcm", "X-Zad-Voice-Provider": "azure" } });
      }
      console.error(`[CoreIntel] Azure TTS (primary) failed: HTTP ${res.status}; trying Gemini`);
      await res.body?.cancel();
    } catch (e) {
      console.error(`[CoreIntel] Azure TTS (primary) threw: ${String((e as Error)?.message ?? e).slice(0, 200)}`);
    }
  }
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
      // مكانش فيه حد أصلاً: نداء معلّق كان بيسكّت زاد لحد ما المنصة نفسها تقطع.
      signal: AbortSignal.timeout(TTS_TIMEOUT_MS),
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
