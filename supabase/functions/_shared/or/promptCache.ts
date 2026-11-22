// م٤.٧: prompt caching للجزء الثابت. دوال صافية، من غير شبكة ولا داتابيز، ومش متوصلة.
// الأشكال مأخوذة من zad-brain/callModel.ts:
//  - anthropic: `system` بلوكات {type:"text",text,cache_control:{type:"ephemeral"}}، والـcache بيغطي كل اللي قبل العلامة (tools ثم system).
//  - openai_compatible (Groq/NVIDIA): prefix caching تلقائي، بس بيشترط إن البداية بايتات متطابقة. مفيش علامة.
//  - gemini: caching ضمني بنفس الشرط. `cachedContent` الصريح محتاج مكالمة منفصلة، ومؤجل.

export type PartKind = "rules" | "soul" | "tools" | "snapshot" | "time" | "user";
export interface SystemPart { kind: PartKind; text: string }

// ترتيب الثابت: القواعد ثم الروح ثم وصف الأدوات. الباقي متغيّر وبيفضل بترتيبه الأصلي.
const STABLE_RANK: Partial<Record<PartKind, number>> = { rules: 0, soul: 1, tools: 2 };

export function splitStablePrefix(
  systemParts: readonly SystemPart[],
): { stable: SystemPart[]; volatile: SystemPart[] } {
  const stable: { p: SystemPart; i: number }[] = [];
  const volatile: SystemPart[] = [];
  systemParts.forEach((p, i) => {
    if (STABLE_RANK[p.kind] !== undefined) stable.push({ p: { ...p }, i });
    else volatile.push({ ...p });
  });
  // ترتيب حتمي: بالرتبة ثم بالمكان الأصلي، فنفس المدخلات = نفس البايتات.
  stable.sort((a, b) => STABLE_RANK[a.p.kind]! - STABLE_RANK[b.p.kind]! || a.i - b.i);
  return { stable: stable.map((s) => s.p), volatile };
}

export type CacheProvider = "anthropic" | "gemini" | "openai_compatible";
export interface SystemBlock {
  type: "text";
  text: string;
  /** علامة إن البلوك ده من الجزء الثابت (آخر بلوك ثابت بياخد cache_control). */
  stable?: boolean;
  cache_control?: { type: "ephemeral" };
}
export interface CacheRequest {
  system: string | SystemBlock[];
  [k: string]: unknown;
}

const joinText = (blocks: SystemBlock[]) =>
  blocks.map((b) => b.text).join("\n\n");

/** بيرجّع طلب جديد. مابيعدّلش المدخل. مزوّد مجهول = نسخة مطابقة من المدخل. */
export function applyCacheHints<T extends CacheRequest>(
  provider: string,
  request: T,
): T {
  const copy = structuredClone(request);
  if (provider !== "anthropic" && provider !== "gemini" && provider !== "openai_compatible") {
    return copy;
  }
  if (typeof copy.system === "string") return copy; // مفيش تقسيم نعتمد عليه
  // الثابت الأول، المتغيّر بعده، بترتيب أصلي جوه كل مجموعة (حتمي).
  const stable = copy.system.filter((b) => b.stable);
  const volatile = copy.system.filter((b) => !b.stable);
  const strip = (b: SystemBlock): SystemBlock => {
    const { stable: _s, ...rest } = b;
    return rest;
  };
  if (provider === "anthropic") {
    const blocks = [...stable, ...volatile].map(strip);
    if (stable.length > 0) blocks[stable.length - 1].cache_control = { type: "ephemeral" };
    copy.system = blocks;
  } else {
    copy.system = joinText([...stable, ...volatile]);
  }
  return copy;
}

/** بيحوّل أجزاء السيستم لبلوكات جاهزة لـapplyCacheHints. */
export function toSystemBlocks(parts: readonly SystemPart[]): SystemBlock[] {
  const { stable, volatile } = splitStablePrefix(parts);
  return [
    ...stable.map((p): SystemBlock => ({ type: "text", text: p.text, stable: true })),
    ...volatile.map((p): SystemBlock => ({ type: "text", text: p.text })),
  ];
}

// ───────── قياس قبل/بعد ─────────
export interface UsagePayload {
  input_tokens?: number;
  cache_read_input_tokens?: number;
  cache_creation_input_tokens?: number;
  prompt_tokens?: number;
  prompt_tokens_details?: { cached_tokens?: number };
  promptTokenCount?: number;
  cachedContentTokenCount?: number;
}
export interface TimingRecord { latencyMs: number; usage?: UsagePayload }
export interface TimingSummary {
  n: number; meanMs: number; p50Ms: number; inputTokens: number; cachedTokens: number; hitRate: number;
}

const num = (v: unknown) => (typeof v === "number" && Number.isFinite(v) && v > 0 ? v : 0);

/** (إجمالي مدخلات، مقروء من الكاش). Anthropic بيحسب input_tokens من غير المقروء. */
export function readUsage(u: UsagePayload | undefined): { input: number; cached: number } {
  if (!u) return { input: 0, cached: 0 };
  if (u.cache_read_input_tokens !== undefined || u.input_tokens !== undefined) {
    const cached = num(u.cache_read_input_tokens);
    return { input: num(u.input_tokens) + cached + num(u.cache_creation_input_tokens), cached };
  }
  if (u.prompt_tokens !== undefined) {
    return { input: num(u.prompt_tokens), cached: num(u.prompt_tokens_details?.cached_tokens) };
  }
  return { input: num(u.promptTokenCount), cached: num(u.cachedContentTokenCount) };
}

export function summarizeTimings(records: readonly TimingRecord[]): TimingSummary {
  const lat = records.map((r) => num(r.latencyMs)).sort((a, b) => a - b);
  let input = 0, cached = 0;
  for (const r of records) {
    const u = readUsage(r.usage);
    input += u.input;
    cached += u.cached;
  }
  const n = records.length;
  return {
    n,
    meanMs: n ? lat.reduce((a, b) => a + b, 0) / n : 0,
    p50Ms: n ? lat[Math.floor((n - 1) / 2)] : 0,
    inputTokens: input,
    cachedTokens: cached,
    hitRate: input > 0 ? cached / input : 0,
  };
}

export function compareBeforeAfter(before: readonly TimingRecord[], after: readonly TimingRecord[]) {
  const b = summarizeTimings(before), a = summarizeTimings(after);
  return { before: b, after: a, meanDeltaMs: a.meanMs - b.meanMs, p50DeltaMs: a.p50Ms - b.p50Ms };
}
