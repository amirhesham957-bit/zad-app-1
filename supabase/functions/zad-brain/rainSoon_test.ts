// «احتمال مطر في الساعات الجاية» (المالك ١٥/١١): التوقع بالساعة، القاعدة، واللحظة من أولها لآخرها.
import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { forecastUrl, hourPhrase, parseForecast, rainSoon, weatherSource } from "./weather.ts";
import { momentFallback, processVoiceMoments, RAIN_SOON_MOMENT, TEMPLATE_MOMENTS, TEXT_ONLY_MOMENTS } from "./voiceMoments.ts";

weatherSource.fetch = () => Promise.reject(new Error("no network in unit tests"));

const DAILY = {
  time: ["2026-11-15", "2026-11-16"], weather_code: [61, 3], temperature_2m_max: [24, 23], temperature_2m_min: [15, 14],
  precipitation_sum: [1.6, 0], wind_speed_10m_max: [20, 12],
};

Deno.test("rain: the hourly block keeps only the wet hours, on their own day", () => {
  const days = parseForecast({
    daily: DAILY,
    hourly: {
      time: ["2026-11-15T13:00", "2026-11-15T14:00", "2026-11-15T15:00", "2026-11-16T09:00", "garbage"],
      precipitation_probability: [10, 60, 70, 35, 99], precipitation: [0, 0.4, 1.2, 0, 5],
    },
  })!;
  assertEquals(days[0].rain_hours, [[14, 60, 0.4], [15, 70, 1.2]]);
  assertEquals(days[1].rain_hours, [[9, 35, 0]]);
  // من غير ساعات (أو بشكل غريب) اليوم لسه بيتقرا.
  assertEquals(parseForecast({ daily: DAILY })![0].rain_hours, undefined);
  assertEquals(parseForecast({ daily: DAILY, hourly: { time: "x" } })!.length, 2);
  assert(forecastUrl(30, 31, "Africa/Cairo").includes("hourly=precipitation_probability%2Cprecipitation"));
});

Deno.test("rain: only rain inside the next four hours counts, and the line says when", () => {
  const w = { place: "6 أكتوبر", days: [{ date: "2026-11-15", code: 61, label: "مطر", max: 24, min: 15, rain_mm: 1.6, wind_kmh: 20, rain_hours: [[14, 60, 0.4], [15, 70, 1.2], [20, 90, 3]] as Array<[number, number, number]> }] };
  const at12 = rainSoon(w, "2026-11-15", 12)!;
  assertEquals([at12.from_hour, at12.pct, at12.mm], [14, 70, 1.6]);
  assertStringIncludes(at12.line, "6 أكتوبر");
  assertStringIncludes(at12.line, "الساعة 2 الضهر");
  assertStringIncludes(at12.line, "70٪");
  // ٨ بالليل بعد شباك الـ٩ الصبح.
  assertEquals(rainSoon(w, "2026-11-15", 9), null);
  assertStringIncludes(rainSoon(w, "2026-11-15", 15)!.line, "دلوقتي");
  // ٤٠٪ وربع مم مش مطر يستاهل تنبيه.
  const drizzle = { ...w, days: [{ ...w.days[0], rain_hours: [[13, 40, 0.2]] as Array<[number, number, number]> }] };
  assertEquals(rainSoon(drizzle, "2026-11-15", 12), null);
  // كاش قديم من غير ساعات، أو يوم تاني، أو مفيش طقس.
  assertEquals(rainSoon({ ...w, days: [{ ...w.days[0], rain_hours: undefined }] }, "2026-11-15", 12), null);
  assertEquals(rainSoon(w, "2026-11-16", 12), null);
  assertEquals(rainSoon(null, "2026-11-15", 12), null);
  assertEquals([hourPhrase(9), hourPhrase(12), hourPhrase(16), hourPhrase(18), hourPhrase(21)],
    ["الساعة 9 الصبح", "الساعة 12 الضهر", "الساعة 4 العصر", "الساعة 6 المغرب", "الساعة 9 بالليل"]);
});

Deno.test("rain: the moment is a fixed text, never voiced and never a model call", () => {
  assert(TEXT_ONLY_MOMENTS.has(RAIN_SOON_MOMENT) && TEMPLATE_MOMENTS.has(RAIN_SOON_MOMENT));
  const m = momentFallback(RAIN_SOON_MOMENT, { rain: { line: "فيه احتمال مطر في القاهرة دلوقتي" } });
  assertEquals([m.title, m.text, m.speech], ["🌧️ احتمال مطر", "فيه احتمال مطر في القاهرة دلوقتي", ""]);
});

// ١٠:٢٠ UTC = ١٢:٢٠ القاهرة.
const NOW = Date.parse("2026-11-15T10:20:00Z");

function fakeDb(rows: Array<Record<string, unknown>>, rainHours: Array<[number, number, number]> | undefined) {
  const updates: Array<Record<string, unknown>> = [];
  const tables: Record<string, Array<Record<string, unknown>>> = {
    zad_voice_moments: rows,
    zad_users: [{ id: "u1", country: "EG", name: null }],
    zad_weather_cache: [{
      days: [{ date: "2026-11-15", code: 61, label: "مطر", max: 24, min: 15, rain_mm: 1.6, wind_kmh: 20, ...(rainHours ? { rain_hours: rainHours } : {}) }],
      fetched_at: new Date(NOW - 3600_000).toISOString(),
    }],
  };
  const from = (table: string) => {
    const filters: Array<(r: Record<string, unknown>) => boolean> = [];
    const hits = () => (tables[table] ?? []).filter((r) => filters.every((f) => f(r)));
    const q: Record<string, unknown> = {
      select: () => q, gte: () => q, or: () => q, order: () => q, in: () => q, is: () => q, not: () => q, lt: () => q,
      insert: () => Promise.resolve({ error: null }),
      eq: (k: string, v: unknown) => { filters.push((r) => !(k in r) || r[k] === v); return q; },
      like: (k: string, v: string) => { filters.push((r) => String(r[k] ?? "").startsWith(v.replace(/%$/, ""))); return q; },
      limit: () => Promise.resolve({ data: hits(), error: null }),
      maybeSingle: () => Promise.resolve({ data: hits()[0] ?? null, error: null }),
      then: (ok: (v: unknown) => unknown) => Promise.resolve({ data: hits(), error: null }).then(ok),
      update: (values: Record<string, unknown>) => ({
        eq: () => {
          updates.push(values);
          return Object.assign(Promise.resolve({ error: null }), { or: () => ({ select: () => Promise.resolve({ data: [{ id: "claimed" }], error: null }) }) });
        },
      }),
    };
    return q;
  };
  // deno-lint-ignore no-explicit-any
  return { sb: { from, rpc: () => Promise.resolve({ data: null, error: null }) } as any, updates };
}

const PENDING = {
  id: "r1", user_id: "u1", moment: RAIN_SOON_MOMENT, status: "pending", attempts: 0, created_at: new Date(NOW - 180_000).toISOString(),
  dedupe_key: "rain_soon:2026-11-15:12", facts: { local_date: "2026-11-15", local_hour: 12, time_zone: "Africa/Cairo" },
};

async function run(sb: unknown) {
  const pushed: string[] = [];
  let composed = 0;
  // deno-lint-ignore no-explicit-any
  const res = await processVoiceMoments(sb as any, {
    compose: () => { composed++; return Promise.reject(new Error("must not be called")); },
    pushDevice: (_u, title, body, data, dataOnly) => { pushed.push(`device:${data.moment}:${title}:${body}:${dataOnly}`); return Promise.resolve("sent"); },
    pushTelegram: (_u, _t, _b, _v, moment) => { pushed.push(`tg:${moment}`); return Promise.resolve("delivered"); },
    now: () => NOW,
    timeZoneOf: () => Promise.resolve("Africa/Cairo"),
  });
  return { res, pushed, composed };
}

Deno.test("rain: rain at 2 and the check at 12 — one written alert on the phone, no model, no Telegram", async () => {
  const { sb, updates } = fakeDb([{ ...PENDING }], [[14, 60, 0.4], [15, 70, 1.2]]);
  const { res, pushed, composed } = await run(sb);
  assertEquals(res.sent, 1);
  assertEquals(composed, 0);
  assertEquals(pushed.length, 1);
  assert(pushed[0].startsWith("device:rain_soon:🌧️ احتمال مطر:"), pushed[0]);
  assertStringIncludes(pushed[0], "الساعة 2 الضهر");
  assert(pushed[0].endsWith(":false"), "a text alert, not a data-only voice push");
  assert(updates.some((u) => u.status === "sent"));
});

Deno.test("rain: a dry afternoon, or an alert already sent today, says nothing", async () => {
  const dry = fakeDb([{ ...PENDING }], [[19, 80, 2]]);
  const a = await run(dry.sb);
  assertEquals([a.res.sent, a.res.skipped, a.pushed.length], [0, 1, 0]);
  assert(dry.updates.some((u) => u.status === "skipped" && u.error === "no rain ahead"));

  const warned = fakeDb([{ ...PENDING }, { ...PENDING, id: "r0", status: "sent", dedupe_key: "rain_soon:2026-11-15:9" }], [[14, 60, 0.4]]);
  const b = await run(warned.sb);
  assertEquals([b.res.sent, b.pushed.length], [0, 0]);
  assert(warned.updates.some((u) => u.status === "skipped" && u.error === "already warned today"));

  const yesterday = fakeDb([{ ...PENDING, facts: { ...PENDING.facts, local_date: "2026-11-14" } }], [[14, 60, 0.4]]);
  const c = await run(yesterday.sb);
  assertEquals(c.pushed.length, 0);
  assert(yesterday.updates.some((u) => u.error === "day changed"));
});
