// P3.4: تتبّع كل لفة موديل + قاطع دايرة المحركات في Postgres (ميجريشن 20261128200000).
// الحالة مشتركة بين كل نسخ الفانكشن. القاعدة الصلبة: أي فشل هنا (شبكة، RPC، مفيش env) = يتسجل في اللوج
// ويكمّل اللفة عادي. التتبع والقاطع عمرهم ما يوقّفوا ردّ على العميل.
import { createClient } from "jsr:@supabase/supabase-js@2";
import { currentTraceId } from "../_shared/trace.ts";
import { type Route, skipOpenRoutes, engineKey } from "../_shared/or/gatewayRouting.ts";

export const BREAKER_THRESHOLD = 3;
export const BREAKER_COOLDOWN_S = 300;
/** أقصى انتظار لسؤال القاطع قبل الفتح على مصراعيه. */
const GATE_TIMEOUT_MS = 800;

export interface RoundRecord {
  engine: string;
  traceId: string | null;
  startedAt: Date;
  durationMs: number;
  ok: boolean;
  error?: string;
}

export interface BreakerStore {
  /** حالات المحركات المفتوحة/نص مفتوحة: {engine: "open"|"half_open"}. الغايب = closed. */
  gate(engines: string[]): Promise<Record<string, string>>;
  record(r: RoundRecord): Promise<void>;
}

class RpcStore implements BreakerStore {
  // deno-lint-ignore no-explicit-any
  constructor(private sb: any) {}
  async gate(engines: string[]): Promise<Record<string, string>> {
    const { data, error } = await this.sb.rpc("zad_engine_is_open", {
      p_engines: engines, p_cooldown_s: BREAKER_COOLDOWN_S,
    });
    if (error) throw new Error(error.message);
    return data && typeof data === "object" ? data as Record<string, string> : {};
  }
  async record(r: RoundRecord): Promise<void> {
    const { error } = await this.sb.rpc("zad_engine_record_result", {
      p_engine: r.engine,
      p_trace_id: r.traceId,
      p_started_at: r.startedAt.toISOString(),
      p_duration_ms: Math.max(0, Math.round(r.durationMs)),
      p_ok: r.ok,
      p_error: r.error ?? null,
      p_threshold: BREAKER_THRESHOLD,
    });
    if (error) throw new Error(error.message);
  }
}

let override: BreakerStore | null | undefined;
let cached: BreakerStore | null | undefined;

/** للاختبارات: store بديل، أو null = مقفول خالص. undefined = رجوع للافتراضي. */
export function setBreakerStoreForTests(s: BreakerStore | null | undefined): void {
  override = s;
}

function store(): BreakerStore | null {
  if (override !== undefined) return override;
  if (cached !== undefined) return cached;
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  cached = url && key ? new RpcStore(createClient(url, key)) : null;
  return cached;
}

function afterResponse(work: Promise<unknown>): void {
  const runtime = (globalThis as { EdgeRuntime?: { waitUntil?: (p: Promise<unknown>) => void } }).EdgeRuntime;
  if (runtime?.waitUntil) runtime.waitUntil(work);
}

/** الـchain بعد تخطي المحركات المفتوحة. أي مشكلة في القاطع (بطء، خطأ) = الـchain زي ما هي. */
export async function routesAfterBreaker(chain: Route[]): Promise<{ routes: Route[]; skipped: string[] }> {
  const s = store();
  if (!s || chain.length < 2) return { routes: chain, skipped: [] };
  let timer: ReturnType<typeof setTimeout> | undefined;
  try {
    const states = await Promise.race([
      s.gate(chain.map(engineKey)),
      new Promise<never>((_, rej) => { timer = setTimeout(() => rej(new Error("breaker gate timeout")), GATE_TIMEOUT_MS); }),
    ]);
    const routes = skipOpenRoutes(chain, states);
    return { routes, skipped: chain.filter((r) => !routes.includes(r)).map(engineKey) };
  } catch (e) {
    console.warn("[zad-brain] engine breaker gate failed, failing open:", (e as Error)?.message ?? e);
    return { routes: chain, skipped: [] };
  } finally {
    if (timer !== undefined) clearTimeout(timer);
  }
}

/** بيسجّل لفة ويحرّك القاطع. مابيستناش ومابيرميش أبداً. */
export function recordRound(r: Omit<RoundRecord, "traceId" | "startedAt" | "durationMs"> & { startedAtMs: number }): void {
  const s = store();
  if (!s) return;
  const rec: RoundRecord = {
    engine: r.engine,
    traceId: currentTraceId(),
    startedAt: new Date(r.startedAtMs),
    durationMs: Date.now() - r.startedAtMs,
    ok: r.ok,
    error: r.error,
  };
  try {
    const work = s.record(rec).catch((e) => {
      console.warn("[zad-brain] round trace write failed:", (e as Error)?.message ?? e);
    });
    afterResponse(work);
  } catch (e) {
    console.warn("[zad-brain] round trace write failed:", (e as Error)?.message ?? e);
  }
}
