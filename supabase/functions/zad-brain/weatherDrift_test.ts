// تنبيه الجو الاستباقي (ZAD_WEATHER_ALERTS): فلاج مقفول = صفر شبكة، العتبات، منع التكرار ٦ ساعات، لوكيشن قديم/ناقص، وفشل المصدر.
import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { driftAlert, DRIFT_DEDUPE_MS, resetDriftMemo, runWeatherDrift, weatherAlertsEnabled } from "./weatherDrift.ts";
import { momentFallback, TEMPLATE_MOMENTS, TEXT_ONLY_MOMENTS } from "./voiceMoments.ts";
import { processDueAgentTasks } from "./agentTasksRunner.ts";
import { weatherSource } from "./weather.ts";

// ١١:٠٠ القاهرة.
const NOW = Date.parse("2026-11-27T09:00:00Z");
const TZ = "Africa/Cairo";
const FRESH = new Date(NOW - 3_600_000).toISOString();

type Row = Record<string, unknown>;
function fakeDb(tables: Record<string, Row[]>) {
  const from = (table: string) => {
    const rows = (tables[table] ??= []);
    const fs: Array<(r: Row) => boolean> = [];
    const hits = () => rows.filter((r) => fs.every((f) => f(r)));
    const q: Record<string, unknown> = {
      select: () => q, order: () => q,
      is: (k: string, v: unknown) => { fs.push((r) => (r[k] ?? null) === v); return q; },
      not: (k: string, _op: string, v: unknown) => { fs.push((r) => (r[k] ?? null) !== v); return q; },
      eq: (k: string, v: unknown) => { fs.push((r) => r[k] === v); return q; },
      neq: (k: string, v: unknown) => { fs.push((r) => r[k] !== v); return q; },
      lte: (k: string, v: string) => { fs.push((r) => String(r[k] ?? "") <= v); return q; },
      gte: (k: string, v: string) => { fs.push((r) => String(r[k] ?? "") >= v); return q; },
      in: (k: string, v: unknown[]) => { fs.push((r) => v.includes(r[k])); return q; },
      limit: () => Promise.resolve({ data: hits(), error: null }),
      maybeSingle: () => Promise.resolve({ data: hits()[0] ?? null, error: null }),
      then: (ok: (v: unknown) => unknown) => Promise.resolve({ data: hits(), error: null }).then(ok),
      upsert: (row: Row) => {
        if (!rows.some((r) => r.user_id === row.user_id && r.dedupe_key === row.dedupe_key)) {
          rows.push({ status: "pending", created_at: new Date(clock.now).toISOString(), ...row });
        }
        return Promise.resolve({ error: null });
      },
    };
    return q;
  };
  // deno-lint-ignore no-explicit-any
  return { from, rpc: () => Promise.resolve({ data: null, error: null }), tables } as any;
}
const clock = { now: NOW };

const user = (over: Row = {}): Row => ({ id: "u1", last_lat: 30.0, last_lon: 31.2, last_location_at: FRESH, travel_country: null, sleep_bed: null, sleep_wake: null, ...over });
const baseTables = (u: Row = user()): Record<string, Row[]> =>
  ({ zad_users: [u], zad_user_city: [{ user_id: "u1", city: "القاهرة" }], family_members: [], zad_voice_moments: [] });

function openMeteo(temps: number[], pcts: number[], calls: string[] = [], hours = ["T11", "T12", "T13", "T14"]) {
  const time = hours.map((h) => `2026-11-27${h}:00`);
  return (url: string) => {
    calls.push(url);
    return Promise.resolve(new Response(JSON.stringify({ hourly: { time, temperature_2m: temps, precipitation_probability: pcts } }), { status: 200 }));
  };
}
const deps = (fetcher: (u: string) => Promise<Response>, now = NOW) => {
  clock.now = now;
  return { accountTimeZone: () => Promise.resolve(TZ), now, fetcher };
};
// deno-lint-ignore no-explicit-any
const queued = (sb: any): Row[] => sb.tables.zad_voice_moments;

Deno.test("drift: flag is closed unless explicitly on", () => {
  assertEquals(weatherAlertsEnabled(() => undefined), false);
  assertEquals(weatherAlertsEnabled(() => "0"), false);
  assertEquals(weatherAlertsEnabled(() => "1"), true);
});

Deno.test("drift: rain above 40% in the next three hours queues one alert with the fetched number", async () => {
  resetDriftMemo();
  const sb = fakeDb(baseTables());
  const calls: string[] = [];
  const r = await runWeatherDrift(sb, deps(openMeteo([20, 20, 20, 20], [10, 55, 30, 0], calls)));
  assertEquals([r.checked, r.queued, calls.length], [1, 1, 1]);
  assertStringIncludes(calls[0], "api.open-meteo.com");
  const [row] = queued(sb);
  assertEquals(row.moment, "weather_alert");
  const m = momentFallback("weather_alert", row.facts as Row);
  assertStringIncludes(m.text, "55٪");
  assertStringIncludes(m.text, "القاهرة");
  assertStringIncludes(m.text, "الغسيل");
  assert(TEXT_ONLY_MOMENTS.has("weather_alert") && TEMPLATE_MOMENTS.has("weather_alert"));
});

Deno.test("drift: exactly 40% is not enough; extreme heat and cold are", async () => {
  resetDriftMemo();
  let sb = fakeDb(baseTables());
  assertEquals((await runWeatherDrift(sb, deps(openMeteo([20, 20, 20, 20], [40, 40, 10, 0])))).queued, 0);
  resetDriftMemo();
  sb = fakeDb(baseTables());
  assertEquals((await runWeatherDrift(sb, deps(openMeteo([30, 41, 38, 30], [0, 0, 0, 0])))).queued, 1);
  const heat = momentFallback("weather_alert", queued(sb)[0].facts as Row);
  assertStringIncludes(heat.text, "41°");
  assertEquals(heat.title, "🌡️ حر شديد");
  resetDriftMemo();
  sb = fakeDb(baseTables());
  assertEquals((await runWeatherDrift(sb, deps(openMeteo([9, 4, 8, 9], [0, 0, 0, 0])))).queued, 1);
  const cold = momentFallback("weather_alert", queued(sb)[0].facts as Row);
  assertStringIncludes(cold.text, "4°");
  assertEquals(cold.title, "🥶 برد شديد");
});

Deno.test("drift: ordinary weather, or an extreme hour beyond three hours, says nothing", async () => {
  resetDriftMemo();
  const sb = fakeDb(baseTables());
  assertEquals((await runWeatherDrift(sb, deps(openMeteo([25, 26, 27, 28], [5, 10, 20, 30])))).queued, 0);
  // الفحص ١٠:٠٠ القاهرة: شباك ١٠–١٣، فساعة ١٤ برا.
  resetDriftMemo();
  const early = openMeteo([25, 26, 27, 45], [5, 10, 20, 30], [], ["T10", "T11", "T12", "T14"]);
  assertEquals((await runWeatherDrift(sb, deps(early, NOW - 3_600_000))).queued, 0);
});

Deno.test("drift: the same alert is not repeated within 6 hours, but comes back after", async () => {
  resetDriftMemo();
  const sb = fakeDb(baseTables());
  const wet = openMeteo([20, 20, 20, 20], [80, 80, 80, 80]);
  assertEquals((await runWeatherDrift(sb, deps(wet))).queued, 1);
  resetDriftMemo();
  assertEquals((await runWeatherDrift(sb, deps(wet, NOW + 3_600_000))).queued, 0);
  assertEquals(queued(sb).length, 1);
  // بعد ٦ ساعات ونص (٤:٣٠ العصر القاهرة).
  resetDriftMemo();
  const later = NOW + DRIFT_DEDUPE_MS + 1_800_000;
  sb.tables.zad_users[0].last_location_at = new Date(later - 3_600_000).toISOString();
  const wetLater = openMeteo([20, 20, 20, 20], [80, 80, 80, 80], [], ["T17", "T18", "T19", "T20"]);
  assertEquals((await runWeatherDrift(sb, deps(wetLater, later))).queued, 1);
  assertEquals(queued(sb).length, 2);
});

Deno.test("drift: a different alert kind is not blocked by a recent one of another kind", async () => {
  resetDriftMemo();
  const sb = fakeDb(baseTables());
  assertEquals((await runWeatherDrift(sb, deps(openMeteo([20, 20, 20, 20], [80, 80, 80, 80])))).queued, 1);
  resetDriftMemo();
  assertEquals((await runWeatherDrift(sb, deps(openMeteo([44, 44, 44, 44], [0, 0, 0, 0]), NOW + 600_000))).queued, 1);
});

Deno.test("drift: missing, stale, travelling, child and quiet-hours users never reach the network", async () => {
  const calls: string[] = [];
  const wet = openMeteo([20, 20, 20, 20], [90, 90, 90, 90], calls);
  const midnight = Date.parse("2026-11-27T22:00:00Z"); // ٠٠:٠٠ القاهرة
  const cases: Array<[string, Record<string, Row[]>, number]> = [
    ["no fix", baseTables(user({ last_lat: null, last_lon: null })), NOW],
    ["stale fix", baseTables(user({ last_location_at: new Date(NOW - 31 * 86_400_000).toISOString() })), NOW],
    ["travelling", baseTables(user({ travel_country: "SA" })), NOW],
    ["child", { ...baseTables(), family_members: [{ user_id: "u1", role: "child" }] }, NOW],
    ["quiet hours", baseTables(user({ last_location_at: new Date(midnight - 3_600_000).toISOString() })), midnight],
  ];
  for (const [name, tables, now] of cases) {
    resetDriftMemo();
    const r = await runWeatherDrift(fakeDb(tables), deps(wet, now));
    assertEquals([name, r.queued, calls.length], [name, 0, 0]);
  }
});

Deno.test("drift: Open-Meteo failing or answering garbage is a silent skip", async () => {
  for (const f of [
    () => Promise.reject(new Error("down")),
    () => Promise.resolve(new Response("nope", { status: 500 })),
    () => Promise.resolve(new Response(JSON.stringify({ hourly: { time: "x" } }), { status: 200 })),
  ]) {
    resetDriftMemo();
    const sb = fakeDb(baseTables());
    const r = await runWeatherDrift(sb, deps(f));
    assertEquals([r.checked, r.queued, queued(sb).length], [1, 0, 0]);
  }
  assertEquals(driftAlert(null, null, TZ, NOW), null);
});

const runnerDeps = {
  modelRoutine: "m", maxAgentTurns: 1, buildSnapshot: () => Promise.resolve({}), buildChatSystemPrompt: () => "", groqSystemFor: () => "",
  runTool: () => Promise.resolve(""), proactiveTitleFor: () => Promise.resolve(""), accountTimeZone: () => Promise.resolve(TZ),
};

Deno.test("drift: processDueAgentTasks makes zero network calls with the flag closed, and checks with it open", async () => {
  const original = weatherSource.fetch;
  let hits = 0;
  weatherSource.fetch = () => { hits++; return Promise.reject(new Error("offline")); };
  const prev = Deno.env.get("ZAD_WEATHER_ALERTS");
  const db = () => fakeDb({ agent_tasks: [], zad_users: [user({ last_location_at: new Date().toISOString() })], zad_user_city: [], family_members: [], zad_voice_moments: [] });
  try {
    resetDriftMemo();
    Deno.env.delete("ZAD_WEATHER_ALERTS");
    const closed = await processDueAgentTasks(db(), runnerDeps);
    assertEquals([closed, hits], [{ processed: 0, failed: 0, postponed: 0 }, 0]);
    Deno.env.set("ZAD_WEATHER_ALERTS", "1");
    const hour = Number(new Intl.DateTimeFormat("en-GB", { timeZone: TZ, hour: "2-digit", hour12: false }).format(new Date()));
    const open = await processDueAgentTasks(db(), runnerDeps);
    assertEquals(open, { processed: 0, failed: 0, postponed: 0 });
    // خارج ساعات الهدوء الشبكة بتتنده مرة؛ جوّاها مابتتندهش (الاتنين صح).
    assertEquals(hits, hour >= 7 && hour < 23 ? 1 : 0);
  } finally {
    weatherSource.fetch = original;
    if (prev === undefined) Deno.env.delete("ZAD_WEATHER_ALERTS"); else Deno.env.set("ZAD_WEATHER_ALERTS", prev);
    resetDriftMemo();
  }
});
