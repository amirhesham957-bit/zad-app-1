import { googleNearbyAny, googlePlacesKeys } from "./googlePlaces.ts";

// فحص مفاتيح المزوّدين (موقع، صور، موديلات، تليجرام) — أسماء وحالات HTTP بس، ولا حرف من أي
// مفتاح. بيتنادى من CI بعد كل نشر (مفتاح service role) عشان «المفتاح اتحط؟ وشغال؟» تبقى
// إجابة مقاسة مش تخمين. كل الشبكة بتتحقن عشان يتختبر من غير نداءات حقيقية.

import { geminiKeys as geminiKeyPool, groqKeys as groqKeyPool, MAX_KEYS } from "../_shared/keyPool.ts";

export interface ProbeResult {
  configured: boolean;
  status?: number;
  ok?: boolean;
  note?: string;
}

type Env = (name: string) => string | undefined;

/** توكن service role؟ مطابقة مباشرة للمفتاح، أو JWT دوره service_role (التوقيع اتحقق في البوابة). */
export function isServiceRoleToken(token: string | null | undefined, serviceKey: string | undefined): boolean {
  if (!token) return false;
  if (serviceKey && token === serviceKey) return true;
  return jwtClaims(token)?.role === "service_role";
}

/** `sub` من توكن اتحقق توقيعه في البوابة — عشان user_id اللي في الـbody يتصدّق بس لو هو صاحب التوكن. */
export function tokenSubject(token: string | null | undefined): string | null {
  const sub = token ? jwtClaims(token)?.sub : null;
  return typeof sub === "string" && sub ? sub : null;
}

function jwtClaims(token: string): Record<string, unknown> | null {
  const parts = token.split(".");
  if (parts.length !== 3) return null;
  try {
    return JSON.parse(atob(parts[1].replace(/-/g, "+").replace(/_/g, "/").padEnd(Math.ceil(parts[1].length / 4) * 4, "=")));
  } catch {
    return null;
  }
}

/** أسماء أسرار شكلها مفاتيح موقع/صور/أسعار — عشان لو اتحط مفتاح باسم غير اللي الكود بيقراه يبان. */
const INTERESTING_NAME = /LOCATION|MAPS|GEO|PLACES|PEXELS|UNSPLASH|PIXABAY|SERP|PRICE|RAPIDAPI|SPOON|EDAMAM|OPENFOOD|BARCODE|IMAGE|PHOTO/i;

export function interestingSecretNames(allNames: string[]): string[] {
  return allNames.filter((n) => INTERESTING_NAME.test(n)).sort();
}

/**
 * أسرار شكلها مفاتيح ذكاء اصطناعي ومفيش مسبح بيقراها (_shared/keyPool.ts) — مفتاح اتحط باسم
 * `GROK_API_KEY_1` أو `GROQ_KEY_3` أو رقم فوق [MAX_KEYS] بيتجاهل بصمت، والسعة اللي اتدفع
 * فيها مابتوصلش. الأسامي بس، ولا حرف من القيم.
 */
export function unreadAiKeyNames(allNames: string[]): string[] {
  const read = new Set(["ZAD_API_KEY", "GEMINI_API_KEY", "GROQ_API_KEY"]);
  for (let n = 1; n <= MAX_KEYS; n++) read.add(`ZAD_API_KEY_${n}`).add(`GROQ_API_KEY_${n}`);
  return allNames.filter((n) => /GROQ|GROK|XAI|GEMINI|ZAD_API/i.test(n) && /KEY/i.test(n) && !read.has(n)).sort();
}

/**
 * حدود مفتاح Groq من هيدرز الرد: limit-requests = طلبات في اليوم، limit-tokens = توكنز في
 * الدقيقة، ومعاهم الباقي. `undefined` لو الهيدرز مش موجودة (رد خطأ قبل الحد مثلاً).
 */
export function groqLimitsNote(h: Headers): string | undefined {
  const rpd = h.get("x-ratelimit-limit-requests");
  const tpm = h.get("x-ratelimit-limit-tokens");
  if (!rpd && !tpm) return undefined;
  return `rpd=${rpd ?? "?"} left=${h.get("x-ratelimit-remaining-requests") ?? "?"} ` +
    `tpm=${tpm ?? "?"} tpm_left=${h.get("x-ratelimit-remaining-tokens") ?? "?"}`;
}

async function probe(
  fetchImpl: typeof fetch,
  key: string | undefined,
  build: (key: string) => { url: string; init?: RequestInit },
  interpret?: (res: Response) => Promise<string | undefined>,
): Promise<ProbeResult> {
  if (!key) return { configured: false };
  try {
    const { url, init } = build(key);
    const res = await fetchImpl(url, { ...init, signal: AbortSignal.timeout(8000) });
    const note = interpret ? await interpret(res).catch(() => undefined) : undefined;
    return { configured: true, status: res.status, ok: res.ok, ...(note ? { note } : {}) };
  } catch (e) {
    return { configured: true, ok: false, note: `network: ${String((e as Error)?.message ?? e).slice(0, 80)}` };
  }
}

export async function providerHealth(env: Env, envNames: string[], fetchImpl: typeof fetch = fetch): Promise<Record<string, unknown>> {
  const geminiKeys = geminiKeyPool(env);
  const groqKeys = groqKeyPool(env);

  // Google Places: the same call nearby_pois makes, so "configured but the Places API is not
  // enabled on the key's project" shows here as ok:false instead of as an empty shop list.
  const googleKeys = googlePlacesKeys(env);
  const googlePlaces = (async (): Promise<ProbeResult> => {
    if (googleKeys.length === 0) return { configured: false };
    const found = await googleNearbyAny(fetchImpl, googleKeys, { lat: 30.0444, lon: 31.2357, tag: "supermarket", radius: 2000 });
    const tried = googleKeys.map((k) => k.name).join(",");
    return found === null
      ? { configured: true, ok: false, note: `refused by every key (${tried}) — Places API (New) enabled for them?` }
      : { configured: true, ok: true, note: `places=${found.places.length} via ${found.name}` };
  })();

  // Resend (zad-support's complaint email). A sending-only key answers /domains with 401
  // "restricted_api_key" — valid for what we use it for, so that reads as ok.
  const resend = (async (): Promise<ProbeResult> => {
    const r = await probe(fetchImpl, env("RESEND_API_KEY"), (k) => ({
      url: "https://api.resend.com/domains",
      init: { headers: { Authorization: `Bearer ${k}` } },
    }), async (res) => (res.ok ? undefined : (await res.text()).slice(0, 120)));
    if (r.status === 401 && /restricted/i.test(r.note ?? "")) {
      return { configured: true, status: 401, ok: true, note: "sending-only key" };
    }
    return r;
  })();

  const [locationiq, pexels, telegram, elevenlabs, exchange_rate, usda, ...rest] = await Promise.all([
    probe(fetchImpl, env("LOCATIONIQ_API_KEY"), (k) => ({
      url: `https://us1.locationiq.com/v1/nearby?key=${encodeURIComponent(k)}&lat=30.0444&lon=31.2357&tag=supermarket&radius=2000&format=json`,
    }), async (res) => {
      if (!res.ok) return (await res.text()).slice(0, 80);
      const body = await res.json();
      return `places=${Array.isArray(body) ? body.length : 0}`;
    }),
    probe(fetchImpl, env("PEXELS_API_KEY"), (k) => ({
      url: "https://api.pexels.com/v1/search?per_page=1&query=food",
      init: { headers: { Authorization: k } },
    })),
    probe(fetchImpl, env("TELEGRAM_BOT_TOKEN"), (k) => ({ url: `https://api.telegram.org/bot${k}/getMe` })),
    probe(fetchImpl, env("ELEVENLABS_API_KEY"), (k) => ({ url: "https://api.elevenlabs.io/v1/user", init: { headers: { "xi-api-key": k } } })),
    probe(fetchImpl, env("EXCHANGE_RATE_API_KEY"), (k) => ({ url: `https://v6.exchangerate-api.com/v6/${encodeURIComponent(k)}/latest/USD` })),
    probe(fetchImpl, env("USDA_API_KEY"), (k) => ({ url: `https://api.nal.usda.gov/fdc/v1/foods/search?pageSize=1&query=rice&api_key=${encodeURIComponent(k)}` })),
    ...geminiKeys.map((k) => probe(fetchImpl, k, (key) => ({
      url: "https://generativelanguage.googleapis.com/v1beta/models?pageSize=1",
      init: { headers: { "x-goog-api-key": key } },
    }))),
    // طلب chat بتوكن واحد على موديل العقل، مش /models: Groq بيرجّع حدود المفتاح في هيدرز الرد
    // (x-ratelimit-*) — «الحد في اليوم كام» بيتقرا من غير ما نوصله ونحرق كوتة اليوم.
    ...groqKeys.map((k) => probe(fetchImpl, k, (key) => ({
      url: "https://api.groq.com/openai/v1/chat/completions",
      init: {
        method: "POST",
        headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
        body: JSON.stringify({
          model: env("ZAD_GROQ_TEXT_MODEL") || "openai/gpt-oss-120b",
          messages: [{ role: "user", content: "ok" }],
          max_tokens: 1,
        }),
      },
    }), async (res) => groqLimitsNote(res.headers))),
  ]);

  return {
    locationiq,
    google_places: await googlePlaces,
    pexels,
    telegram,
    elevenlabs,
    exchange_rate,
    usda,
    resend: await resend,
    gemini_pool: rest.slice(0, geminiKeys.length),
    groq_pool: rest.slice(geminiKeys.length),
    community_chat_configured: !!env("TELEGRAM_COMMUNITY_CHAT_ID"),
    unread_ai_key_names: unreadAiKeyNames(envNames),
    other_key_like_secret_names: interestingSecretNames(envNames).filter((n) => !["LOCATIONIQ_API_KEY", "PEXELS_API_KEY"].includes(n)),
  };
}
