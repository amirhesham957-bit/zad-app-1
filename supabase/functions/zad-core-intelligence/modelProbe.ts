// فحص الكوتة الحقيقية لكل موديل على كل مفتاح (ZAD_DREAM_PLAN.md — قرار المالك ٢٠٢٦-١٠-١٧:
// «أداة فحص تحدد الحدود الحقيقية بدل أرقام المدونات»).
//
// ليه مش كفاية provider_health: ده بيسأل «المفتاح شغال؟» على موديل واحد. السؤال هنا «كل موديل
// بيرد على كل مفتاح؟ وحده كام؟». المصادر العامة مختلفة على حدود جوجل المجانية، والحد على المشروع
// (ai.google.dev/gemini-api/docs/rate-limits)، وعلى Groq على الـorganization — يعني عشر مفاتيح في
// حساب واحد = حصة واحدة. الإجابة لازم تتقاس على مفاتيحنا إحنا.
//
// اللي بيتقاس:
//   Gemini — نداء generateContent صغير جداً لكل (مفتاح، موديل). 200 = الموديل متاح للمشروع ده.
//            429 بيرجّع QuotaFailure فيها اسم الحد وقيمته (مثلاً GenerateRequestsPerDay…=20) —
//            ده الرقم الرسمي للمشروع ده بالظبط. Gemini مابيرجّعش الحد في الرد الناجح.
//   Groq   — نداء chat بتوكن واحد؛ الهيدرز بترجع حد الطلبات في اليوم وحد التوكنز في الدقيقة والباقي.
//            لو مفتاحين ورا بعض الباقي بتاعهم نقص بواحد بالظبط ⇒ غالباً نفس الـorganization.
//
// التكلفة: طلب واحد لكل (مفتاح، موديل) من كوتة اليوم. بيتنادى بإيد (service role)، مش من كرون.

export const GEMINI_PROBE_MODELS: readonly string[] = [
  "gemini-3.1-flash-lite",
  "gemini-3.5-flash-lite",
  "gemini-3.5-flash",
  "gemini-3.6-flash",
  "gemini-3.8-flash",
];

export const GROQ_PROBE_MODELS: readonly string[] = [
  "openai/gpt-oss-20b",
  "openai/gpt-oss-120b",
  "qwen/qwen3.8-27b",
];

export interface ProbeRow {
  provider: "gemini" | "groq";
  key_slot: number;
  model: string;
  status: number | null;
  ok: boolean;
  limit_requests: number | null;
  remaining_requests: number | null;
  limit_tokens: number | null;
  remaining_tokens: number | null;
  quota_note: string | null;
}

const TIMEOUT_MS = 12000;

function intOrNull(v: string | null | undefined): number | null {
  if (v == null || v === "") return null;
  const n = Number.parseInt(v, 10);
  return Number.isFinite(n) ? n : null;
}

/**
 * حد جوجل من جسم الـ429: كل violation فيها quotaId وquotaValue. بيرجّع «quotaId=value» مفصولين
 * بـ«; »، أو أول ١٦٠ حرف من الرسالة لو مافيش تفاصيل.
 */
export function geminiQuotaNote(body: unknown): string | null {
  const err = (body as { error?: { message?: unknown; details?: unknown } } | null)?.error;
  if (!err) return null;
  const notes: string[] = [];
  for (const d of Array.isArray(err.details) ? err.details : []) {
    for (const v of Array.isArray((d as { violations?: unknown })?.violations) ? (d as { violations: unknown[] }).violations : []) {
      const id = (v as { quotaId?: unknown }).quotaId;
      const value = (v as { quotaValue?: unknown }).quotaValue;
      if (typeof id === "string") notes.push(value != null ? `${id}=${value}` : id);
    }
  }
  if (notes.length > 0) return notes.join("; ");
  return typeof err.message === "string" ? err.message.slice(0, 160) : null;
}

/** موديلات Gemma 4 اللي الـListModels بيقول إنها بتعمل generateContent — عشان تتفحص من غير تخمين اسمها. */
export function gemmaModelsFrom(listBody: unknown): string[] {
  const models = (listBody as { models?: unknown })?.models;
  if (!Array.isArray(models)) return [];
  const out: string[] = [];
  for (const m of models) {
    const name = String((m as { name?: unknown }).name ?? "").replace(/^models\//, "");
    const methods = (m as { supportedGenerationMethods?: unknown }).supportedGenerationMethods;
    if (/^gemma-4/.test(name) && Array.isArray(methods) && methods.includes("generateContent")) out.push(name);
  }
  return out.sort();
}

async function probeGemini(fetchImpl: typeof fetch, key: string, slot: number, model: string): Promise<ProbeRow> {
  const row: ProbeRow = {
    provider: "gemini", key_slot: slot, model, status: null, ok: false,
    limit_requests: null, remaining_requests: null, limit_tokens: null, remaining_tokens: null, quota_note: null,
  };
  try {
    const res = await fetchImpl(
      `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json", "x-goog-api-key": key },
        body: JSON.stringify({
          contents: [{ role: "user", parts: [{ text: "رد بكلمة واحدة: تمام" }] }],
          generationConfig: { maxOutputTokens: 16, temperature: 0 },
        }),
        signal: AbortSignal.timeout(TIMEOUT_MS),
      },
    );
    row.status = res.status;
    row.ok = res.ok;
    if (!res.ok) row.quota_note = geminiQuotaNote(await res.json().catch(() => null));
  } catch (e) {
    row.quota_note = `network: ${String((e as Error)?.message ?? e).slice(0, 120)}`;
  }
  return row;
}

async function probeGroq(fetchImpl: typeof fetch, key: string, slot: number, model: string): Promise<ProbeRow> {
  const row: ProbeRow = {
    provider: "groq", key_slot: slot, model, status: null, ok: false,
    limit_requests: null, remaining_requests: null, limit_tokens: null, remaining_tokens: null, quota_note: null,
  };
  try {
    const res = await fetchImpl("https://api.groq.com/openai/v1/chat/completions", {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${key}` },
      body: JSON.stringify({ model, messages: [{ role: "user", content: "ok" }], max_tokens: 1 }),
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
    row.status = res.status;
    row.ok = res.ok;
    row.limit_requests = intOrNull(res.headers.get("x-ratelimit-limit-requests"));
    row.remaining_requests = intOrNull(res.headers.get("x-ratelimit-remaining-requests"));
    row.limit_tokens = intOrNull(res.headers.get("x-ratelimit-limit-tokens"));
    row.remaining_tokens = intOrNull(res.headers.get("x-ratelimit-remaining-tokens"));
    if (!res.ok) row.quota_note = (await res.text().catch(() => "")).replace(/[^\x20-\x7E]/g, "").slice(0, 160) || null;
  } catch (e) {
    row.quota_note = `network: ${String((e as Error)?.message ?? e).slice(0, 120)}`;
  }
  return row;
}

/**
 * مفاتيح Groq اللي شكلها في نفس الـorganization: اتفحصت ورا بعض على نفس الموديل، وباقي التاني
 * أقل من الأول بواحد بالظبط. مؤشر مش إثبات — مفتاحين في حسابين مختلفين مالهمش علاقة بالعداد.
 */
export function sharedGroqSlots(rows: ProbeRow[]): Array<[number, number]> {
  const pairs: Array<[number, number]> = [];
  const byModel = new Map<string, ProbeRow[]>();
  for (const r of rows) {
    if (r.provider !== "groq" || r.remaining_requests == null) continue;
    byModel.set(r.model, [...(byModel.get(r.model) ?? []), r]);
  }
  for (const list of byModel.values()) {
    for (let i = 1; i < list.length; i++) {
      const a = list.at(i - 1)!, b = list.at(i)!;
      if (b.remaining_requests === (a.remaining_requests as number) - 1) pairs.push([a.key_slot, b.key_slot]);
    }
  }
  const seen = new Set<string>();
  return pairs.filter(([a, b]) => {
    const k = `${a}-${b}`;
    if (seen.has(k)) return false;
    seen.add(k);
    return true;
  });
}

export interface ProbeReport {
  rows: ProbeRow[];
  gemma_models: string[];
  groq_shared_slots: Array<[number, number]>;
  summary: Record<string, { keys_ok: number; keys_total: number; notes: string[] }>;
}

export async function modelQuotaProbe(
  geminiKeys: string[],
  groqKeys: string[],
  fetchImpl: typeof fetch = fetch,
  opts: { geminiModels?: readonly string[]; groqModels?: readonly string[] } = {},
): Promise<ProbeReport> {
  let gemma: string[] = [];
  if (geminiKeys.length > 0) {
    try {
      const res = await fetchImpl("https://generativelanguage.googleapis.com/v1beta/models?pageSize=200", {
        headers: { "x-goog-api-key": geminiKeys[0] },
        signal: AbortSignal.timeout(TIMEOUT_MS),
      });
      if (res.ok) gemma = gemmaModelsFrom(await res.json());
    } catch { /* الفحص يكمل من غير Gemma */ }
  }
  const geminiModels = [...new Set([...(opts.geminiModels ?? GEMINI_PROBE_MODELS), ...gemma])];
  const groqModels = opts.groqModels ?? GROQ_PROBE_MODELS;

  // جوجل: كل حد لمشروعه، فالتوازي مايبوّظش القياس.
  const geminiRows = await Promise.all(
    geminiKeys.flatMap((k, i) => geminiModels.map((m) => probeGemini(fetchImpl, k, i + 1, m))),
  );
  // Groq: ورا بعض لكل موديل عشان مؤشر «نفس الـorganization» يبقى له معنى.
  const groqRows: ProbeRow[] = [];
  for (const m of groqModels) {
    for (let i = 0; i < groqKeys.length; i++) groqRows.push(await probeGroq(fetchImpl, groqKeys[i], i + 1, m));
  }

  const rows = [...geminiRows, ...groqRows];
  const summary: ProbeReport["summary"] = {};
  for (const r of rows) {
    const s = summary[`${r.provider}:${r.model}`] ??= { keys_ok: 0, keys_total: 0, notes: [] };
    s.keys_total++;
    if (r.ok) s.keys_ok++;
    const note = r.ok
      ? (r.limit_requests != null ? `rpd=${r.limit_requests} tpm=${r.limit_tokens ?? "?"}` : null)
      : `${r.status ?? "err"} ${r.quota_note ?? ""}`.trim();
    if (note && !s.notes.includes(note) && s.notes.length < 4) s.notes.push(note);
  }
  return { rows, gemma_models: gemma, groq_shared_slots: sharedGroqSlots(groqRows), summary };
}
