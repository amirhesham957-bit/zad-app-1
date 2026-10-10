// وقت العيلة قبل الويك إند (familyTime.ts، الموجة ٤): مرة في الأسبوع، للبيت اللي فيه أكتر من فرد، بالجو والتوفير.
import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { familyTime, isFamilyHome, isWeekendEve, outdoorDay } from "./familyTime.ts";
import type { DayWeather } from "./weather.ts";
import { weatherSource } from "./weather.ts";
import { dealSource } from "./tasteDeals.ts";
import { momentFallback, morningFacts } from "./voiceMoments.ts";

weatherSource.fetch = () => Promise.reject(new Error("no network in unit tests"));
dealSource.search = () => Promise.resolve(null);

const THU = "2026-10-15";
const FRI = "2026-10-16";
const day = (date: string, over: Partial<DayWeather> = {}): DayWeather =>
  ({ date, code: 1, label: "صافي مع شوية سحاب", max: 27, min: 18, rain_mm: 0, wind_kmh: 12, ...over });
const FAMILY = { familyMembers: 3 };
// الدورة ماشية أبطأ من السقف: اتوفّر ٢٥٠ ⇒ ٣٠٪ = ٧٥ ⇒ ٧٠.
const SAVING = { threat: "SAFE", velocity: 0.8, spent: 1000, available: 4000, currency: "EGP" };

Deno.test("family time: the eve of the weekend in their country", () => {
  assert(isWeekendEve(THU, "EG"));
  assert(isWeekendEve(THU, "SA"));
  assert(!isWeekendEve(FRI, "EG"));
  // المغرب وتونس وتركيا ولبنان: الويك إند بيبدأ السبت.
  assert(isWeekendEve(FRI, "MA"));
  assert(!isWeekendEve(THU, "TR"));
  assert(isWeekendEve(THU, null));
});

Deno.test("family time: a home of more than one, and a day fit for going out", () => {
  assert(isFamilyHome({ familyMembers: 2 }));
  assert(isFamilyHome({ familyMembers: 1, kidsCount: 1 }));
  assert(isFamilyHome({ familyMembers: 1, householdSize: 4 }));
  assert(!isFamilyHome({ familyMembers: 1, householdSize: 1 }));
  assert(outdoorDay(day(FRI)));
  for (const bad of [{ code: 61 }, { rain_mm: 2 }, { max: 36 }, { max: 15 }, { wind_kmh: 45 }]) assert(!outdoorDay(day(FRI, bad)), JSON.stringify(bad));
  assert(!outdoorDay(null));
});

Deno.test("family time: out or in by tomorrow's weather, a ceiling from savings, else free", () => {
  const out = familyTime({ date: THU, country: "EG", family: FAMILY, days: [day(THU), day(FRI)], budget: SAVING, tight: false })!;
  assertEquals([out.outdoor, out.budget], [true, 70]);
  assertStringIncludes(out.line, "بكرة الجو حلو (صافي مع شوية سحاب، العظمى 27°) — خروجة عيلة؟");
  assertStringIncludes(out.line, "في حدود 70 EGP من اللي اتوفّر");
  const rainy = familyTime({ date: THU, country: "EG", family: FAMILY, days: [day(THU), day(FRI, { code: 63, label: "مطر", rain_mm: 6 })], budget: SAVING, tight: false })!;
  assertEquals(rainy.outdoor, false);
  assertStringIncludes(rainy.line, "قعدة عيلة في البيت");
  // ضيق (خطر أو «مفلس»): أفكار ببلاش، من غير مبلغ.
  const tight = familyTime({ date: THU, country: "EG", family: FAMILY, days: [day(FRI)], budget: SAVING, tight: true })!;
  assertEquals(tight.budget, null);
  assertStringIncludes(tight.line, "ببلاش");
  // مفيش جو: جملة عامة من غير أرقام جو.
  assertStringIncludes(familyTime({ date: THU, country: "EG", family: FAMILY, days: null, budget: null, tight: false })!.line, "آخر الأسبوع جه");
  // مش اليوم، أو فرد لوحده ⇒ مفيش.
  assertEquals(familyTime({ date: FRI, country: "EG", family: FAMILY, days: null, budget: null, tight: false }), null);
  assertEquals(familyTime({ date: THU, country: "EG", family: { familyMembers: 1 }, days: null, budget: null, tight: false }), null);
});

function fakeSb(tables: Record<string, unknown[]>, rpcs: Record<string, unknown> = {}): SupabaseClient {
  const chain = (data: unknown): unknown =>
    new Proxy({}, {
      get(_t, prop) {
        if (prop === "then") return (res: (v: unknown) => unknown) => Promise.resolve({ data, error: null }).then(res);
        if (prop === "maybeSingle" || prop === "single") return () => chain(Array.isArray(data) ? data[0] ?? null : data);
        return () => chain(data);
      },
    });
  return { from: (t: string) => chain(tables[t] ?? []), rpc: (fn: string) => chain(rpcs[fn] ?? null) } as unknown as SupabaseClient;
}

const LOCAL = { date: THU, time_zone: "Africa/Cairo", utc_offset: "+03:00" };
const TABLES = {
  zad_users: [{ id: "u", country: "EG", created_at: "2025-01-01T00:00:00Z" }],
  family_members: [{ family_id: "f", user_id: "u" }, { family_id: "f", user_id: "v" }],
};
const forecast = () => Promise.resolve(new Response(JSON.stringify({ daily: {
  time: [THU, FRI, "2026-10-17"], weather_code: [1, 1, 1], temperature_2m_max: [27, 26, 26],
  temperature_2m_min: [18, 18, 18], precipitation_sum: [0, 0, 0], wind_speed_10m_max: [10, 10, 10],
} })));

Deno.test("morning: Thursday's greeting carries the family's weekend, and the template says it", async () => {
  weatherSource.fetch = forecast;
  const facts = await morningFacts(fakeSb(TABLES, { zad_budget_state: { ...SAVING, limit_confirmed: true } }), "u", LOCAL);
  const ft = facts.family_time as { outdoor: boolean; budget: number | null; line: string };
  assertEquals([ft.outdoor, ft.budget], [true, 70]);
  assertStringIncludes(momentFallback("morning_greeting", facts).text, "خروجة عيلة؟");
  // «أنا مفلس» شغال ⇒ ببلاش.
  const broke = await morningFacts(fakeSb({ ...TABLES, zad_broke_mode: [{ ends_at: new Date(Date.now() + 86_400_000).toISOString(), ended_at: null }] },
    { zad_budget_state: SAVING }), "u", LOCAL);
  assertEquals((broke.family_time as { budget: number | null }).budget, null);
  // البيت في ظرف (شغال على الساعة الحقيقية) ⇒ مفيش اقتراح.
  const inCircumstance = await morningFacts(fakeSb({ ...TABLES, zad_life_circumstances: [{
    id: "c", kind: "exceptional", source: "chat", ended_at: null,
    started_at: new Date(Date.now() - 86_400_000).toISOString(), ends_at: new Date(Date.now() + 5 * 86_400_000).toISOString(),
  }] }, { zad_budget_state: SAVING }), "u", LOCAL);
  assertEquals([inCircumstance.quiet, inCircumstance.family_time], [true, undefined]);
  // يوم تاني، أو حد لوحده ⇒ مفيش.
  assertEquals((await morningFacts(fakeSb(TABLES), "u", { ...LOCAL, date: FRI })).family_time, undefined);
  assertEquals((await morningFacts(fakeSb({ zad_users: TABLES.zad_users }), "u", LOCAL)).family_time, undefined);
  weatherSource.fetch = () => Promise.reject(new Error("no network in unit tests"));
});
