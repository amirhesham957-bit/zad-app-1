// حراس الطقس (الموجة ٤، الشريحة ٢): أزمة الجو، تبديل هدوم الموسم مرة في الموسم، وسطر الجو في التحية.
import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { askedClothesKeys, clothingNudge, type DayWeather, weatherAlert, weatherSource } from "./weather.ts";
import { goodNightFacts, momentFallback, morningFacts } from "./voiceMoments.ts";

const day = (date: string, over: Partial<DayWeather> = {}): DayWeather =>
  ({ date, code: 1, label: "صافي", max: 30, min: 19, rain_mm: 0, wind_kmh: 10, ...over });
const W = (...days: DayWeather[]) => ({ place: "القاهرة", days });

Deno.test("alert: storms, heavy rain, heat, cold and wind — today first, then tomorrow", () => {
  assertEquals(weatherAlert(W(day("2026-10-11")), "2026-10-11"), null);
  const storm = weatherAlert(W(day("2026-10-11", { code: 95, rain_mm: 20 })), "2026-10-11")!;
  // العواصف قبل المطر لو الاتنين.
  assertEquals([storm.kind, storm.day], ["storm", "today"]);
  assertStringIncludes(storm.line, "النهارده فيه عواصف رعدية في القاهرة");
  assertEquals(weatherAlert(W(day("2026-10-11", { rain_mm: 10 })), "2026-10-11")?.kind, "heavy_rain");
  assertEquals(weatherAlert(W(day("2026-10-11", { rain_mm: 9.9 })), "2026-10-11"), null);
  assertEquals(weatherAlert(W(day("2026-10-11", { max: 40 })), "2026-10-11")?.kind, "heat");
  assertEquals(weatherAlert(W(day("2026-10-11", { min: 5 })), "2026-10-11")?.kind, "cold");
  assertEquals(weatherAlert(W(day("2026-10-11", { wind_kmh: 50 })), "2026-10-11")?.kind, "wind");
  const tomorrow = weatherAlert(W(day("2026-10-11"), day("2026-10-12", { max: 42 })), "2026-10-11")!;
  assertEquals([tomorrow.day, tomorrow.date], ["tomorrow", "2026-10-12"]);
  assertStringIncludes(tomorrow.line, "بكرة حر شديد في القاهرة (العظمى 42°)");
  // تصبح على خير: بكرة بس، حتى لو النهارده فيه حاجة.
  assertEquals(weatherAlert(W(day("2026-10-11", { code: 95 }), day("2026-10-12")), "2026-10-11", true), null);
  // التوقعات مش بتبدأ النهارده (كاش قديم) = مفيش.
  assertEquals(weatherAlert(W(day("2026-10-09", { code: 95 })), "2026-10-11"), null);
});

Deno.test("clothes: two cold nights or two hot days in the next three, keyed once per season", () => {
  const winter = clothingNudge(W(day("2026-11-20", { min: 14 }), day("2026-11-21", { min: 13 }), day("2026-11-22", { min: 17 })), "2026-11-20")!;
  assertEquals([winter.season, winter.key], ["winter", "clothes:winter:2026"]);
  assertStringIncludes(winter.line, "الصغرى 13°");
  // يناير لسه نفس شتا ٢٠٢٦.
  assertEquals(clothingNudge(W(day("2027-01-05", { min: 8 }), day("2027-01-06", { min: 9 })), "2027-01-05")?.key, "clothes:winter:2026");
  const summer = clothingNudge(W(day("2027-05-01", { max: 34 }), day("2027-05-02", { max: 36 })), "2027-05-01")!;
  assertEquals([summer.season, summer.key], ["summer", "clothes:summer:2027"]);
  assertStringIncludes(summer.line, "العظمى 36°");
  // ليلة باردة واحدة مش موسم.
  assertEquals(clothingNudge(W(day("2026-11-20", { min: 14 }), day("2026-11-21"), day("2026-11-22")), "2026-11-20"), null);
  assertEquals(clothingNudge(null, "2026-11-20"), null);
  assertEquals([...askedClothesKeys([{ facts: { weather_clothes: { key: "clothes:winter:2026" } } }, { facts: {} }])], ["clothes:winter:2026"]);
});

/** قاعدة مزيفة: كل جدول بيرجّع صفوفه لأي فلتر. */
function fakeSb(tables: Record<string, unknown[]>): SupabaseClient {
  const chain = (data: unknown): unknown =>
    new Proxy({}, {
      get(_t, prop) {
        if (prop === "then") return (res: (v: unknown) => unknown) => Promise.resolve({ data, error: null }).then(res);
        if (prop === "maybeSingle" || prop === "single") return () => chain(Array.isArray(data) ? data[0] ?? null : data);
        return () => chain(data);
      },
    });
  return { from: (t: string) => chain(tables[t] ?? []), rpc: () => chain([]) } as unknown as SupabaseClient;
}

const LOCAL = { date: "2026-11-20", time_zone: "Africa/Cairo", utc_offset: "+02:00" };
const forecast = (daily: Record<string, unknown[]>) => () =>
  Promise.resolve(new Response(JSON.stringify({ daily: { time: ["2026-11-20", "2026-11-21", "2026-11-22"], ...daily } })));
const STORMY_COLD = forecast({
  weather_code: [95, 3, 3], temperature_2m_max: [22, 21, 22], temperature_2m_min: [12, 11, 14],
  precipitation_sum: [25, 0, 0], wind_speed_10m_max: [30, 10, 10],
});
const USER = { id: "u", country: "EG", created_at: "2025-01-01T00:00:00Z" };

Deno.test("morning: the storm is said first, the clothes once a season, and the weather line", async () => {
  weatherSource.fetch = STORMY_COLD;
  const facts = await morningFacts(fakeSb({ zad_users: [USER] }), "u", LOCAL);
  assertEquals((facts.weather_alert as { kind: string }).kind, "storm");
  assertEquals((facts.weather_clothes as { key: string }).key, "clothes:winter:2026");
  assertEquals(facts.weather, { place: "القاهرة", today: { sky: "عواصف رعدية", max: 22, min: 12 } });
  const msg = momentFallback("morning_greeting", facts);
  assertStringIncludes(msg.title, "خلي بالك من الجو");
  assert(msg.text.indexOf("عواصف رعدية") < msg.text.indexOf("الليالي بدأت تبرد"));

  // اتقالت الموسم ده ⇒ مابتتقالش تاني.
  const again = await morningFacts(fakeSb({ zad_users: [USER], zad_voice_moments: [{ facts: { weather_clothes: { key: "clothes:winter:2026" } } }] }), "u", LOCAL);
  assertEquals(again.weather_clothes, undefined);
  assert(again.weather_alert);
});

Deno.test("morning: in a household circumstance only the safety alert stays; no source, no weather at all", async () => {
  weatherSource.fetch = STORMY_COLD;
  const quiet = await morningFacts(fakeSb({
    zad_users: [USER],
    // الظرف بيتقاس على الساعة الحقيقية (loadCircumstance) — شغال من امبارح لبعد ٥ أيام.
    zad_life_circumstances: [{
      id: "c", kind: "exceptional", source: "chat", ended_at: null,
      started_at: new Date(Date.now() - 86_400_000).toISOString(), ends_at: new Date(Date.now() + 5 * 86_400_000).toISOString(),
    }],
  }), "u", LOCAL);
  assertEquals(quiet.quiet, true);
  assert(quiet.weather_alert);
  assertEquals([quiet.weather_clothes, quiet.weather], [undefined, undefined]);
  weatherSource.fetch = () => Promise.reject(new Error("offline"));
  const none = await morningFacts(fakeSb({ zad_users: [USER] }), "u", LOCAL);
  assertEquals([none.weather, none.weather_alert, none.weather_clothes], [undefined, undefined, undefined]);
});

Deno.test("good night: tomorrow's storm is the one thing to remember", async () => {
  weatherSource.fetch = forecast({
    weather_code: [1, 95, 3], temperature_2m_max: [24, 22, 22], temperature_2m_min: [16, 15, 15],
    precipitation_sum: [0, 30, 0], wind_speed_10m_max: [10, 40, 10],
  });
  const facts = await goodNightFacts(fakeSb({ zad_users: [USER] }), "u", LOCAL);
  assertEquals((facts.weather_alert as { day: string }).day, "tomorrow");
  const msg = momentFallback("good_night", { ...facts, tomorrow_appointments: [{ title: "البنك" }] });
  assertStringIncludes(msg.text, "بكرة فيه عواصف رعدية");
  assert(!msg.text.includes("البنك"));
  weatherSource.fetch = () => Promise.reject(new Error("offline"));
});
