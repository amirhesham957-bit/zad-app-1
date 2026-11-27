// weatherDrift.ts — «تنبيه الجو الاستباقي» خلف ZAD_WEATHER_ALERTS (مقفول افتراضياً: صفر قراية، صفر شبكة).
//
// بيتنده من processDueAgentTasks. لكل عميل لوكيشنه حديث (zad_users.last_lat/last_lon/last_location_at، نفس قاعدة
// loadHomePoint: أقدم من ٣٠ يوم أو مسافر = مفيش نقطة = بنعدّي) بنسأل Open-Meteo (من غير مفتاح، نفس weatherSource
// والمهلة بتوع weather.ts) عن الـ٣ ساعات الجاية بالساعة:
//   - احتمال مطر > ٤٠٪   ⇒ «شيل الغسيل»
//   - حر ≥ HEAT_C أو برد ≤ COLD_C (نفس حدود weatherAlert) ⇒ «البس مناسب»
// التنبيه مش بيتبعت من هنا: بيتسجل لحظة `weather_alert` في zad_voice_moments، ومعالج اللحظات (voiceMoments.ts) هو
// اللي بيحترم ساعات الهدوء وسقف اليوم وحساب الساكت والقناة. الأرقام في النص كلها من رد Open-Meteo.
//
// منع التكرار: نفس النوع ماتتبعتش تاني خلال ٦ ساعات — بقراية آخر صفوف `weather_alert` للعميل، ومفتاح
// `dedupe_key` (unique مع user_id) بيمنع سباق لفتين.

import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { COLD_C, HEAT_C, HOME_POINT_MAX_AGE_MS, loadHomePoint, placeKey, WEATHER_FETCH_TIMEOUT_MS, weatherSource } from "./weather.ts";
import { isQuietHourIn, localNowContext, quietWindowOf } from "./shared.ts";

export const WEATHER_ALERTS_FLAG = "ZAD_WEATHER_ALERTS";
export const WEATHER_ALERT_MOMENT = "weather_alert";

export const DRIFT_RAIN_PCT = 40;
export const DRIFT_AHEAD_HOURS = 3;
export const DRIFT_DEDUPE_MS = 6 * 3_600_000;
/** أقصى عدد عملاء بيتفحصوا في اللفة الواحدة (كل لفة ٥ دقايق تقريباً) — الشبكة خفيفة. */
export const DRIFT_MAX_USERS_PER_RUN = 25;
/** نتيجة Open-Meteo للمكان بتتعاد استعمالها ٣٠ دقيقة جوه نفس الـisolate. */
export const DRIFT_MEMO_MS = 30 * 60_000;

export type DriftKind = "rain" | "heat" | "cold";

export interface DriftAlert {
  kind: DriftKind;
  /** الرقم اللي في الرسالة: احتمال المطر ٪ أو الدرجة. */
  value: number;
  line: string;
}

export function weatherAlertsEnabled(get: (k: string) => string | undefined = (k) => Deno.env.get(k)): boolean {
  const v = (get(WEATHER_ALERTS_FLAG) ?? "").trim().toLowerCase();
  return v === "1" || v === "true" || v === "on";
}

type Fetch = (input: string, init?: RequestInit) => Promise<Response>;

export function driftUrl(lat: number, lon: number, timeZone: string): string {
  return "https://api.open-meteo.com/v1/forecast?" + new URLSearchParams({
    latitude: lat.toFixed(4), longitude: lon.toFixed(4),
    hourly: "temperature_2m,precipitation_probability",
    timezone: timeZone || "auto", forecast_hours: String(DRIFT_AHEAD_HOURS + 1),
  }).toString();
}

export interface DriftHour {
  /** «YYYY-MM-DDTHH» بتوقيت العميل. */
  key: string;
  temp: number | null;
  pct: number | null;
}

const num = (v: unknown): number | null => (typeof v === "number" && Number.isFinite(v) ? v : null);

/** رد Open-Meteo ⇒ ساعات، أو null لو الشكل غريب. */
export function parseDriftHours(raw: unknown): DriftHour[] | null {
  const h = (raw as { hourly?: Record<string, unknown[]> } | null)?.hourly;
  if (!h || !Array.isArray(h.time)) return null;
  const out: DriftHour[] = [];
  for (let i = 0; i < h.time.length; i++) {
    const m = /^(\d{4}-\d{2}-\d{2}T\d{2}):/.exec(String(h.time[i] ?? ""));
    if (!m) continue;
    out.push({ key: m[1], temp: num(h.temperature_2m?.[i]), pct: num(h.precipitation_probability?.[i]) });
  }
  return out.length ? out : null;
}

/** «YYYY-MM-DDTHH» المحلي لوقت [ms] في [tz]. */
function hourKey(tz: string, ms: number): string {
  const l = localNowContext(tz, new Date(ms));
  return `${l.date}T${l.time.slice(0, 2)}`;
}

/**
 * القاعدة: بنبص على الساعات من دلوقتي لحد +٣ ساعات. مطر أولاً (> ٤٠٪)، وبعده حر، وبعده برد.
 * null = مفيش حاجة تستاهل.
 */
export function driftAlert(hours: DriftHour[] | null, place: string | null, tz: string, nowMs: number): DriftAlert | null {
  if (!hours) return null;
  const from = hourKey(tz, nowMs);
  const to = hourKey(tz, nowMs + DRIFT_AHEAD_HOURS * 3_600_000);
  const win = hours.filter((x) => x.key >= from && x.key <= to);
  if (win.length === 0) return null;
  const where = place ? ` في ${place}` : "";
  const pcts = win.map((x) => x.pct).filter((x): x is number => x !== null);
  const maxPct = pcts.length ? Math.round(Math.max(...pcts)) : null;
  if (maxPct !== null && maxPct > DRIFT_RAIN_PCT) {
    return { kind: "rain", value: maxPct, line: `احتمال المطر${where} ${maxPct}٪ خلال الـ٣ ساعات الجاية — شيل الغسيل من البلكونة، ولو نازل خد شمسية.` };
  }
  const temps = win.map((x) => x.temp).filter((x): x is number => x !== null);
  if (temps.length) {
    const hi = Math.round(Math.max(...temps));
    if (hi >= HEAT_C) return { kind: "heat", value: hi, line: `الحر شديد${where} (${hi}°) خلال الـ٣ ساعات الجاية — البس خفيف وفاتح، وخد مية معاك.` };
    const lo = Math.round(Math.min(...temps));
    if (lo <= COLD_C) return { kind: "cold", value: lo, line: `البرد شديد${where} (${lo}°) خلال الـ٣ ساعات الجاية — البس تقيل ودفّي العيال.` };
  }
  return null;
}

const memo = new Map<string, { at: number; hours: DriftHour[] | null }>();
/** للتستات. */
export function resetDriftMemo(): void {
  memo.clear();
}

async function hoursFor(lat: number, lon: number, tz: string, nowMs: number, fetcher: Fetch): Promise<DriftHour[] | null> {
  const key = `${placeKey(lat, lon)}|${tz}`;
  const hit = memo.get(key);
  if (hit && nowMs - hit.at < DRIFT_MEMO_MS) return hit.hours;
  let hours: DriftHour[] | null = null;
  try {
    const res = await fetcher(driftUrl(lat, lon, tz), { signal: AbortSignal.timeout(WEATHER_FETCH_TIMEOUT_MS) });
    hours = res.ok ? parseDriftHours(await res.json()) : null;
  } catch {
    hours = null; // فشل المصدر = سكوت، والمرة الجاية تتجرب.
  }
  memo.set(key, { at: nowMs, hours });
  return hours;
}

export interface DriftDeps {
  accountTimeZone: (sb: SupabaseClient, userId: string) => Promise<string>;
  now?: number;
  fetcher?: Fetch;
}

/** يفحص ويسجّل لحظات `weather_alert`. مابيرميش أبداً. بيرجع عدد اللي اتفحص واللي اتسجل. */
export async function runWeatherDrift(sb: SupabaseClient, deps: DriftDeps): Promise<{ checked: number; queued: number }> {
  const out = { checked: 0, queued: 0 };
  try {
    const nowMs = deps.now ?? Date.now();
    const fetcher = deps.fetcher ?? weatherSource.fetch;
    const { data: users } = await sb.from("zad_users")
      .select("id,sleep_bed,sleep_wake")
      .is("travel_country", null).not("last_lat", "is", null).not("last_lon", "is", null)
      .gte("last_location_at", new Date(nowMs - HOME_POINT_MAX_AGE_MS).toISOString())
      .order("last_location_at", { ascending: false }).limit(DRIFT_MAX_USERS_PER_RUN * 4);
    const rows = (users ?? []) as Array<{ id: string; sleep_bed?: string | null; sleep_wake?: string | null }>;
    if (rows.length === 0) return out;
    const ids = rows.map((r) => r.id);
    const [{ data: kids }, { data: recent }] = await Promise.all([
      sb.from("family_members").select("user_id").in("user_id", ids).eq("role", "child"),
      sb.from("zad_voice_moments").select("user_id,dedupe_key,created_at")
        .in("user_id", ids).eq("moment", WEATHER_ALERT_MOMENT).neq("status", "failed")
        .gte("created_at", new Date(nowMs - DRIFT_DEDUPE_MS).toISOString()),
    ]);
    const childIds = new Set(((kids ?? []) as Array<{ user_id: string }>).map((k) => k.user_id));
    const recentKinds = new Map<string, Set<string>>();
    for (const r of (recent ?? []) as Array<{ user_id: string; dedupe_key: string }>) {
      const kind = /^weather_alert:([a-z]+):/.exec(r.dedupe_key)?.[1];
      if (kind) (recentKinds.get(r.user_id) ?? recentKinds.set(r.user_id, new Set()).get(r.user_id)!).add(kind);
    }
    for (const u of rows) {
      if (out.checked >= DRIFT_MAX_USERS_PER_RUN) break;
      if (childIds.has(u.id)) continue;
      const tz = await deps.accountTimeZone(sb, u.id);
      // ساعات هدوئه: مفيش لزوم نكلم الشبكة، والمعالج كان هيرميها.
      const quiet = quietWindowOf(u.sleep_bed, u.sleep_wake);
      if (isQuietHourIn(Number(localNowContext(tz, new Date(nowMs)).time.slice(0, 2)), quiet)) continue;
      const point = await loadHomePoint(sb, u.id, nowMs);
      if (!point) continue; // مفيش لوكيشن، أو أقدم من الحد، أو مسافر.
      out.checked++;
      const alert = driftAlert(await hoursFor(point.lat, point.lon, tz, nowMs, fetcher), point.name, tz, nowMs);
      if (!alert || recentKinds.get(u.id)?.has(alert.kind)) continue;
      const local = localNowContext(tz, new Date(nowMs));
      const { error } = await sb.from("zad_voice_moments").upsert({
        user_id: u.id, moment: WEATHER_ALERT_MOMENT,
        facts: { kind: alert.kind, local_date: local.date, time_zone: tz, alert },
        dedupe_key: `${WEATHER_ALERT_MOMENT}:${alert.kind}:${Math.floor(nowMs / DRIFT_DEDUPE_MS)}`,
      }, { onConflict: "user_id,dedupe_key", ignoreDuplicates: true });
      if (error) console.warn("[weather_drift] enqueue failed:", error.message);
      else out.queued++;
    }
  } catch (e) {
    console.warn("[weather_drift] failed:", (e as Error)?.message);
  }
  return out;
}
