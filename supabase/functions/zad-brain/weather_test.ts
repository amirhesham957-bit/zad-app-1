// الطقس من Open-Meteo (weather.ts، الموجة ٤): المكان التقريبي، الكاش، والفشل.
import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { CAPITALS, forecastUrl, geocodeCity, loadWeather, parseForecast, placeKey, weatherForSnapshot, weatherRule, wmoLabel } from "./weather.ts";
import { intentToolHints } from "./specialists.ts";
import { CHAT_TOOLS } from "./index.ts";
import { freshContext, MUTATING_TOOLS, VALIDATORS } from "./validators.ts";

// رد حقيقي من /v1/forecast للقاهرة (اتجاب ٢٠٢٦-١٠-١١).
const CAIRO = {
  daily: {
    time: ["2026-10-11", "2026-10-12", "2026-10-13", "2026-10-14"],
    weather_code: [3, 1, 3, 95], temperature_2m_max: [29.7, 30.6, 31.4, 26], temperature_2m_min: [18.8, 18.7, 19.1, 17.2],
    precipitation_sum: [0, 0, 0, 12.34], wind_speed_10m_max: [12.4, 9.8, 10.5, 55.2],
  },
};

Deno.test("weather: Open-Meteo's daily block becomes days, and a strange answer becomes nothing", () => {
  const days = parseForecast(CAIRO)!;
  assertEquals(days.length, 4);
  assertEquals(days[0], { date: "2026-10-11", code: 3, label: "غيم", max: 30, min: 19, rain_mm: 0, wind_kmh: 12 });
  assertEquals([days[3].label, days[3].rain_mm, days[3].wind_kmh], ["عواصف رعدية", 12.3, 55]);
  assertEquals(parseForecast({}), null);
  assertEquals(parseForecast({ daily: { time: ["2026-10-11"], weather_code: ["x"] } }), null);
  assertEquals(parseForecast(null), null);
  assertEquals([wmoLabel(0), wmoLabel(45), wmoLabel(63), wmoLabel(65), wmoLabel(81)], ["صافي", "شبورة", "مطر", "مطر تقيل", "زخات مطر"]);
  assertEquals(placeKey(30.0626, 31.2497), "30.06,31.25");
  const url = forecastUrl(30.0626, 31.2497, "Africa/Cairo");
  assert(url.startsWith("https://api.open-meteo.com/v1/forecast?") && url.includes("forecast_days=4") && url.includes("timezone=Africa%2FCairo"));
});

const json = (body: unknown, ok = true) => Promise.resolve(new Response(JSON.stringify(body), { status: ok ? 200 : 500 }));

Deno.test("weather: a city is looked up inside the customer's own country, the biggest first", async () => {
  const asked: string[] = [];
  const fetcher = (url: string) => {
    asked.push(url);
    return json({ results: [
      // أكبر سكاناً بس في بلد تاني — مايتختارش.
      { name: "المنصورة", country_code: "YE", latitude: 12.8, longitude: 44.9, population: 9_000_000 },
      { name: "المنصورة", country_code: "EG", latitude: 31.04, longitude: 31.38, population: 439348 },
      { name: "منصورة", country_code: "EG", latitude: 30.1, longitude: 31.0, population: 100 },
    ] });
  };
  assertEquals(await geocodeCity("المنصورة", "EG", fetcher), { name: "المنصورة", lat: 31.04, lon: 31.38 });
  assert(asked[0].includes("countryCode=EG"));
  assertEquals(await geocodeCity("x", "EG", fetcher), null);
  assertEquals(await geocodeCity("المنصورة", "Egypt", fetcher), null);
});

/** قاعدة مزيفة لجدول الكاش: بتقرا بالمفتاح وبتسجّل الكتابة. */
function cacheSb(rows: Record<string, Record<string, unknown>>) {
  const writes: Array<Record<string, unknown>> = [];
  const sb = {
    from: () => {
      let key = "";
      const q = {
        select: () => q,
        eq: (_c: string, v: string) => { key = v; return q; },
        maybeSingle: () => Promise.resolve({ data: rows[key] ?? null, error: null }),
        upsert: (row: Record<string, unknown>) => { writes.push(row); rows[row.place_key as string] = row; return Promise.resolve({ error: null }); },
      };
      return q;
    },
  } as unknown as SupabaseClient;
  return { sb, writes };
}

const NOW = Date.parse("2026-10-11T09:00:00Z");
const CAIRO_KEY = placeKey(CAPITALS.EG.lat, CAPITALS.EG.lon);

Deno.test("weather: fresh cache answers without a call; stale cache refetches and is rewritten", async () => {
  const days = parseForecast(CAIRO)!;
  let calls = 0;
  const fetcher = () => { calls++; return json(CAIRO); };
  const fresh = cacheSb({ [CAIRO_KEY]: { days, fetched_at: new Date(NOW - 3_600_000).toISOString() } });
  const w = await loadWeather(fresh.sb, { country: "EG", timeZone: "Africa/Cairo", now: NOW, fetcher });
  assertEquals([w?.place, w?.from, calls, fresh.writes.length], ["القاهرة", "capital", 0, 0]);

  const stale = cacheSb({ [CAIRO_KEY]: { days, fetched_at: new Date(NOW - 4 * 3_600_000).toISOString() } });
  const again = await loadWeather(stale.sb, { country: "eg", timeZone: "Africa/Cairo", now: NOW, fetcher });
  assertEquals([calls, stale.writes.length, again?.fetched_at], [1, 1, new Date(NOW).toISOString()]);
  assertEquals(stale.writes[0].place_key, CAIRO_KEY);
});

Deno.test("weather: the source down — yesterday's cache under a day old, else nothing; no country, nothing", async () => {
  const days = parseForecast(CAIRO)!;
  const down = () => json({}, false);
  const recent = cacheSb({ [CAIRO_KEY]: { days, fetched_at: new Date(NOW - 10 * 3_600_000).toISOString() } });
  assertEquals((await loadWeather(recent.sb, { country: "EG", timeZone: "UTC", now: NOW, fetcher: down }))?.days.length, 4);
  const old = cacheSb({ [CAIRO_KEY]: { days, fetched_at: new Date(NOW - 30 * 3_600_000).toISOString() } });
  assertEquals(await loadWeather(old.sb, { country: "EG", timeZone: "UTC", now: NOW, fetcher: down }), null);
  const thrown = () => Promise.reject(new Error("offline"));
  assertEquals(await loadWeather(cacheSb({}).sb, { country: "EG", timeZone: "UTC", now: NOW, fetcher: thrown }), null);
  assertEquals(await loadWeather(cacheSb({}).sb, { country: null, timeZone: "UTC", now: NOW, fetcher: () => json(CAIRO) }), null);
});

Deno.test("weather: the profile's city, geocoded once; a city not found falls back to the capital", async () => {
  let geo = 0;
  const fetcher = (url: string) => {
    if (url.includes("geocoding")) {
      geo++;
      return json({ results: url.includes("%D8%A7%D9%84%D9%85%D9%86%D8%B5%D9%88%D8%B1%D8%A9")
        ? [{ name: "المنصورة", country_code: "EG", latitude: 31.04, longitude: 31.38, population: 1 }] : [] });
    }
    return json(CAIRO);
  };
  const c = cacheSb({});
  const w = await loadWeather(c.sb, { country: "EG", city: "المنصورة", timeZone: "Africa/Cairo", now: NOW, fetcher });
  assertEquals([w?.place, w?.from], ["المنصورة", "city"]);
  assert(c.writes.some((r) => r.place_key === "city:EG:المنصورة"));
  await loadWeather(c.sb, { country: "EG", city: "المنصورة", timeZone: "Africa/Cairo", now: NOW, fetcher });
  assertEquals(geo, 1);
  const misses = cacheSb({});
  const lost = await loadWeather(misses.sb, { country: "EG", city: "بلد مش موجودة", timeZone: "Africa/Cairo", now: NOW, fetcher });
  assertEquals([lost?.place, lost?.from], ["القاهرة", "capital"]);
  // «مالقيناهاش» بتتحفظ كمان: اللفة الجاية مابتدورش تاني.
  await loadWeather(misses.sb, { country: "EG", city: "بلد مش موجودة", timeZone: "Africa/Cairo", now: NOW, fetcher });
  assertEquals(geo, 2);
});

Deno.test("weather: snapshot shape, the prompt line, and the tool", () => {
  assertEquals(weatherForSnapshot(null), null);
  const snap = weatherForSnapshot({ place: "القاهرة", from: "capital", days: parseForecast(CAIRO)!, fetched_at: "x" })!;
  assertEquals((snap.days as unknown[]).length, 3);
  assertEquals(snap.source, "Open-Meteo");
  assertStringIncludes(weatherRule({ weather: { place: "القاهرة" } }), "من Open-Meteo لـالقاهرة");
  assertStringIncludes(weatherRule({}), "ماتخمّنش درجات حرارة");
  for (const ask of ["الجو عامل ايه بكرة؟", "هتمطر النهارده؟", "الطقس في إسكندرية"]) assert(intentToolHints(ask).includes("weather_forecast"), ask);
  assert(!intentToolHints("صرفت ٥٠ قهوة").includes("weather_forecast"));
  assert(CHAT_TOOLS.some((t) => t.name === "weather_forecast"));
  assert(!MUTATING_TOOLS.includes("weather_forecast"));
  const ctx = freshContext("u");
  ctx.counts.weather_forecast = 2;
  assertEquals((VALIDATORS.weather_forecast({}, {}, ctx) as { ok: boolean }).ok, false);
});
