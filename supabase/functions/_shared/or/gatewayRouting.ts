// م٤.٨: توجيه استدعاءات الـLLM عبر Cloudflare AI Gateway (أو مباشر) + سلسلة الاحتياط. نقي: مفيش شبكة ولا Deno.env ولا zad-brain.
// القاعدة الصلبة: الصور (vision) مابتروحش Groq أبداً.
// nextRoute: 429 و5xx والشبكة (status 0) = ينتقل للي بعده. 401/403 = يتخطى باقي مزوّد ده وينتقل لمزوّد تاني.
// أي 4xx تاني (زي 400) = يوقف ويرجّع null. الـ2xx/3xx مش فشل، فبيرجّع null كمان.

export type Provider = "gemini" | "groq";
export type Route = { provider: Provider; model: string; viaGateway: boolean };
export type Failure = { status: number };
export type Sample = { viaGateway: boolean; ms: number; cacheHit?: boolean };
export type PlanInput = { hasVision: boolean; gatewayEnabled: boolean; geminiModels: string[]; groqModel: string };
export type Stats = { n: number; p50: number | null; p95: number | null };

const ID_RE = /^[A-Za-z0-9_-]+$/;
const PROVIDER_SLUG: Record<Provider, string> = { gemini: "google-ai-studio", groq: "groq" };

/** رابط الـAI Gateway للمزوّد. بيرمي خطأ لو الـid فيه حاجة غير [A-Za-z0-9_-]. */
export function buildGatewayUrl(opts: { accountId: string; gatewayId: string; provider: Provider }): string {
  if (!ID_RE.test(opts.accountId)) throw new Error("invalid accountId");
  if (!ID_RE.test(opts.gatewayId)) throw new Error("invalid gatewayId");
  if (!(opts.provider in PROVIDER_SLUG)) throw new Error("invalid provider");
  return `https://gateway.ai.cloudflare.com/v1/${opts.accountId}/${opts.gatewayId}/${PROVIDER_SLUG[opts.provider]}`;
}

/** سلسلة الاحتياط: موديلات Gemini بالترتيب، وبعدهم Groq (إلا لو فيه صورة). الموديلات الفاضية بتتشال. */
export function planRoutes(input: PlanInput): Route[] {
  const viaGateway = input.gatewayEnabled;
  const chain: Route[] = input.geminiModels
    .map((m) => m.trim())
    .filter((m) => m !== "")
    .map((model): Route => ({ provider: "gemini", model, viaGateway }));
  const groq = input.groqModel.trim();
  if (!input.hasVision && groq !== "") chain.push({ provider: "groq", model: groq, viaGateway });
  return chain;
}

/** فشل يستاهل الانتقال للي بعده: الشبكة (0) و429 و5xx. */
export function isRetryable(status: number): boolean {
  return status === 0 || status === 429 || (status >= 500 && status < 600);
}

/** 401/403 = المفتاح أو الصلاحية، فباقي مزوّد ده مفيهوش فايدة. */
function isProviderSkip(status: number): boolean {
  return status === 401 || status === 403;
}

/** الـindex اللي بعد الفشل عند idx. */
function advance(chain: Route[], idx: number, status: number): number {
  if (idx >= chain.length) return chain.length;
  if (isRetryable(status)) return idx + 1;
  if (isProviderSkip(status)) {
    const provider = chain[idx].provider;
    let j = idx + 1;
    while (j < chain.length && chain[j].provider === provider) j++;
    return j;
  }
  return chain.length;
}

/**
 * الـRoute اللي بعد آخر فشل. failures = نتايج المحاولات بالترتيب (مش بالضرورة طول الـchain، لأن التخطي بيسقط routes).
 * بدون فشل بيرجّع أول route. لو آخر فشل مش retryable ومش 401/403 بيرجّع null. لو السلسلة خلصت بيرجّع null.
 */
export function nextRoute(chain: Route[], failures: Failure[]): Route | null {
  if (failures.length === 0) return chain[0] ?? null;
  let idx = 0;
  let last = 0;
  for (const f of failures) {
    last = f.status;
    idx = advance(chain, idx, f.status);
  }
  if (!isRetryable(last) && !isProviderSkip(last)) return null;
  return chain[idx] ?? null;
}

/** nearest-rank على مصفوفة مرتبة تصاعدياً. فاضية = null. */
export function percentile(sorted: number[], p: number): number | null {
  const n = sorted.length;
  if (n === 0) return null;
  const rank = Math.ceil((p / 100) * n);
  return sorted[Math.min(n, Math.max(1, rank)) - 1];
}

function statsOf(ms: number[]): Stats {
  const sorted = [...ms].sort((a, b) => a - b);
  return { n: sorted.length, p50: percentile(sorted, 50), p95: percentile(sorted, 95) };
}

/** ملخص تجربة م٤.٨: المباشر مقابل الـGateway. السامبلات اللي ms بتاعها مش رقم محدود بتتجاهل. */
export function summarizeTrial(samples: Sample[]): {
  direct: Stats;
  gateway: Stats & { cacheHitRate: number | null };
  deltaP50Ms: number | null;
} {
  const ok = samples.filter((s) => Number.isFinite(s.ms));
  const direct = statsOf(ok.filter((s) => !s.viaGateway).map((s) => s.ms));
  const gwSamples = ok.filter((s) => s.viaGateway);
  const gw = statsOf(gwSamples.map((s) => s.ms));
  const hits = gwSamples.filter((s) => s.cacheHit === true).length;
  const deltaP50Ms = direct.p50 !== null && gw.p50 !== null ? gw.p50 - direct.p50 : null;
  return {
    direct,
    gateway: { ...gw, cacheHitRate: gwSamples.length > 0 ? hits / gwSamples.length : null },
    deltaP50Ms,
  };
}
