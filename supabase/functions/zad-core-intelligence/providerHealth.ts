// فحص مفاتيح المزوّدين (موقع، صور، موديلات، تليجرام) — أسماء وحالات HTTP بس، ولا حرف من أي
// مفتاح. بيتنادى من CI بعد كل نشر (مفتاح service role) عشان «المفتاح اتحط؟ وشغال؟» تبقى
// إجابة مقاسة مش تخمين. كل الشبكة بتتحقن عشان يتختبر من غير نداءات حقيقية.

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
  const geminiKeys = [1, 2, 3, 4, 5].map((i) => env(`ZAD_API_KEY_${i}`)).filter((k): k is string => !!k);
  if (geminiKeys.length === 0 && env("GEMINI_API_KEY")) geminiKeys.push(env("GEMINI_API_KEY")!);
  const groqKeys = [env("GROQ_API_KEY_1") ?? env("GROQ_API_KEY"), env("GROQ_API_KEY_2")].filter((k): k is string => !!k);

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
    ...groqKeys.map((k) => probe(fetchImpl, k, (key) => ({
      url: "https://api.groq.com/openai/v1/models",
      init: { headers: { Authorization: `Bearer ${key}` } },
    }))),
  ]);

  return {
    locationiq,
    pexels,
    telegram,
    elevenlabs,
    exchange_rate,
    usda,
    gemini_pool: rest.slice(0, geminiKeys.length),
    groq_pool: rest.slice(geminiKeys.length),
    community_chat_configured: !!env("TELEGRAM_COMMUNITY_CHAT_ID"),
    other_key_like_secret_names: interestingSecretNames(envNames).filter((n) => !["LOCATIONIQ_API_KEY", "PEXELS_API_KEY"].includes(n)),
  };
}
