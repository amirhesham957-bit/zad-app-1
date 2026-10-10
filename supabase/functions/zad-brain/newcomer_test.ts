// أول ٧٢ ساعة (newcomer.ts): سؤالين في اليوم من النواقص اللي بتشغّل حارس، بقواعد مش بموديل.
import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { askedThisMorning } from "./curiosity.ts";
import { askedNewcomerKeys, isNewcomer, NEWCOMER_HOURS, newcomerFacts, newcomerQuestion } from "./newcomer.ts";
import { BUSY_DAY_OPTIONAL_MOMENTS, morningFacts, NEWCOMER_MOMENT, processVoiceMoments, TEMPLATE_MOMENTS } from "./voiceMoments.ts";
import { buildChatSystemPrompt } from "./index.ts";

const HOUR = 3_600_000;
// ٣ العصر بتوقيت القاهرة: برّه الهدوء.
const NOW = Date.parse("2026-10-10T12:00:00Z");
const NONE = new Set<string>();
const SELF_BIRTHDAY = { for: null, question: "عيد ميلادك امتى؟ عشان أفتكره وأفرح معاك يومها 🎂" };

Deno.test("newcomer: only the first 72 hours count", () => {
  assertEquals(NEWCOMER_HOURS, 72);
  assert(isNewcomer(new Date(NOW - 71 * HOUR).toISOString(), NOW));
  assert(!isNewcomer(new Date(NOW - 73 * HOUR).toISOString(), NOW));
  assert(!isNewcomer(new Date(NOW + HOUR).toISOString(), NOW));
  assert(!isNewcomer(null, NOW));
  assert(!isNewcomer("not a date", NOW));
});

Deno.test("newcomer: the gaps that run a guard, health first, then the month, the country, a birthday", () => {
  const base = {
    profile: { pay_day: null },
    country: null,
    medsWithoutTimes: [{ name: "Allzyme", for_person: "ماما" }],
    birthday: SELF_BIRTHDAY,
  };
  const order: string[] = [];
  const asked = new Set<string>();
  for (let i = 0; i < 5; i++) {
    const q = newcomerQuestion({ ...base, askedKeys: asked });
    if (!q) break;
    order.push(q.gap);
    asked.add(q.key);
  }
  assertEquals(order, ["dose_times", "pay_day", "country", "birthday"]);
  // كل حاجة اتسألت ⇒ مفيش سؤال، مش لف من الأول.
  assertEquals(newcomerQuestion({ ...base, askedKeys: asked }), null);
});

Deno.test("newcomer: a filled gap is never asked", () => {
  assertEquals(newcomerQuestion({ profile: { pay_day: 25 }, country: "EG", medsWithoutTimes: [], birthday: null, askedKeys: NONE }), null);
  // خانة فاضية بمسافات = ناقصة.
  assertEquals(newcomerQuestion({ profile: { pay_day: " " }, country: "EG", medsWithoutTimes: [], birthday: null, askedKeys: NONE })?.gap, "pay_day");
  // مفيش صف ملف خالص = يوم القبض ناقص.
  assertEquals(newcomerQuestion({ profile: null, country: "EG", medsWithoutTimes: [], birthday: null, askedKeys: NONE })?.gap, "pay_day");
});

Deno.test("newcomer: each question records the answer through a path the chat already knows", () => {
  const ask = (over: Partial<Parameters<typeof newcomerQuestion>[0]>) =>
    newcomerQuestion({ profile: { pay_day: 1 }, country: "EG", medsWithoutTimes: [], birthday: null, askedKeys: NONE, ...over })!;
  const med = newcomerFacts(ask({ medsWithoutTimes: [{ name: "Allzyme", for_person: "ماما" }] }));
  assertStringIncludes(String(med.daily_question), "«Allzyme» بتاع ماما بيتاخد الساعة كام؟");
  assertEquals(med.daily_question_kind, "curiosity");
  const curiosity = med.curiosity as Record<string, string>;
  assertEquals(curiosity.tool, "update_pharmacy_item");
  assertStringIncludes(curiosity.record, "times_explicit = true");
  assertStringIncludes(curiosity.record, "ماتخمّنش ساعات");
  assertEquals(med.newcomer, { key: "newcomer:dose_times:allzyme", gap: "dose_times" });

  const pay = newcomerFacts(ask({ profile: {} }));
  assertEquals([pay.daily_question_kind, pay.daily_question_field], ["profile", "pay_day"]);

  const country = newcomerFacts(ask({ country: "" }));
  // «أنا في مصر» لوحدها مافيهاش نية تجيب set_market — الأداة بتتعرض مع السؤال.
  assertEquals((country.curiosity as Record<string, string>).tool, "set_market");

  const birthday = newcomerFacts(ask({ birthday: { for: "ماما", question: "عيد ميلاد ماما امتى؟ عشان أفكّرك قبلها" } }));
  assertEquals([birthday.daily_question_kind, birthday.occasion_ask], ["occasion", { for: "ماما" }]);
});

Deno.test("newcomer: what was asked is read back from the moment rows", () => {
  const keys = askedNewcomerKeys([{ facts: { newcomer: { key: "newcomer:pay_day" } } }, { facts: { curiosity: { key: "quiet:x" } } }, { facts: null }]);
  assertEquals([...keys], ["newcomer:pay_day"]);
  // السؤال اللي اتبعت بيوصل للشات ومعاه الأداة اللي تسجّل جوابه.
  const asked = askedThisMorning({ sent_at: new Date().toISOString(), facts: newcomerFacts(newcomerQuestion({
    profile: { pay_day: 1 }, country: "EG", medsWithoutTimes: [{ name: "Allzyme", for_person: null }], birthday: null, askedKeys: NONE,
  })!) });
  assertEquals(asked?.kind, "curiosity");
  assertEquals(asked?.tool, "update_pharmacy_item");
});

Deno.test("chat: the answer is recorded and Zad says what it will do with it", () => {
  const prompt = buildChatSystemPrompt({ asked_this_morning: { question: "x", kind: "profile", field: "pay_day", sent_at: "2026-10-10T08:00:00Z" } });
  assertStringIncludes(prompt, "أو بعد الضهر في أول أيامه");
  assertStringIncludes(prompt, "إيه اللي اتسجل وهيتعمل بيه إيه");
});

/** قاعدة مزيفة: كل جدول بيرجّع صفوفه لأي فلتر، والتحديثات بتتسجل. */
function fakeSb(tables: Record<string, unknown[]>, updates: Array<Record<string, unknown>> = []): SupabaseClient {
  const chain = (data: unknown): unknown =>
    new Proxy({}, {
      get(_t, prop) {
        if (prop === "then") {
          return (res: (v: unknown) => unknown, rej: (e: unknown) => unknown) => Promise.resolve({ data, error: null }).then(res, rej);
        }
        if (prop === "maybeSingle" || prop === "single") return () => chain(Array.isArray(data) ? data[0] ?? null : data);
        if (prop === "update") {
          return (payload: Record<string, unknown>) => {
            updates.push(payload);
            return chain([{ id: "claimed" }]);
          };
        }
        return () => chain(data);
      },
    });
  return { from: (table: string) => chain(tables[table] ?? []), rpc: () => chain([]) } as unknown as SupabaseClient;
}

const LOCAL = { date: "2026-10-10", time_zone: "Africa/Cairo", utc_offset: "+03:00" };
const PROFILE = { preferred_name: "سارة", gender: null, household_role: null, pay_day: null, cares_for: null, occupation: null };
const MED = { name: "Allzyme", for_person: null, dose_times: null, remaining_quantity: 20 };

Deno.test("morning: a new account's one question is the guard gap, not the profile rotation", async () => {
  const fresh = new Date(Date.now() - 20 * HOUR).toISOString();
  const facts = await morningFacts(fakeSb({
    zad_users: [{ id: "u", created_at: fresh, country: "EG" }], zad_customer_profile: [PROFILE], zad_pharmacy_items: [MED],
  }), "u", LOCAL);
  assertEquals(facts.daily_question_kind, "curiosity");
  assertStringIncludes(String(facts.daily_question), "Allzyme");
  assertEquals((facts.newcomer as { gap: string }).gap, "dose_times");
  assertEquals(facts.daily_question_field, undefined);

  // حساب عمره ١٠ أيام: نفس دوران خانات الملف زي ما كان.
  const old = await morningFacts(fakeSb({
    zad_users: [{ id: "u", created_at: new Date(Date.now() - 240 * HOUR).toISOString(), country: "EG" }],
    zad_customer_profile: [PROFILE], zad_pharmacy_items: [MED],
  }), "u", LOCAL);
  assertEquals(old.daily_question_kind, "profile");
  assertEquals(old.newcomer, undefined);
});

function momentRow(facts: Record<string, unknown> = { time_zone: "Africa/Cairo", local_date: "2026-10-10" }) {
  return { id: "m1", user_id: "u", moment: NEWCOMER_MOMENT, status: "pending", attempts: 0, created_at: new Date().toISOString(), facts };
}

Deno.test("afternoon: the second question goes out as written — no model call", async () => {
  assert(TEMPLATE_MOMENTS.has(NEWCOMER_MOMENT));
  assert(BUSY_DAY_OPTIONAL_MOMENTS.has(NEWCOMER_MOMENT));
  const updates: Array<Record<string, unknown>> = [];
  const sb = fakeSb({
    zad_voice_moments: [momentRow()],
    zad_users: [{ id: "u", created_at: new Date(NOW - 30 * HOUR).toISOString(), country: "EG", name: "سارة" }],
    zad_customer_profile: [{ ...PROFILE, pay_day: null }],
  }, updates);
  let composeCalls = 0;
  const said: string[] = [];
  const res = await processVoiceMoments(sb, {
    compose: () => { composeCalls++; return Promise.resolve("{}"); },
    pushDevice: (_u, _t, body) => { said.push(body); return Promise.resolve("sent"); },
    pushTelegram: () => Promise.resolve("delivered"),
    timeZoneOf: () => Promise.resolve("Africa/Cairo"),
    now: () => NOW,
  });
  assertEquals(res.sent, 1);
  assertEquals(composeCalls, 0);
  assertEquals(said, ["بتقبض يوم كام في الشهر؟ عشان أحسب شهرك صح"]);
  // السؤال اتحفظ في الصف (الشات بيقراه) قبل ما يتبعت.
  assert(updates.some((u) => (u.facts as { newcomer?: { key?: string } } | undefined)?.newcomer?.key === "newcomer:pay_day"));
  assert(updates.some((u) => (u.delivery as { composed_by?: string } | undefined)?.composed_by === "template"));
});

Deno.test("afternoon: past 72 hours, or every gap already asked, the moment is dropped unsent", async () => {
  // يوم القبض والبلد معروفين، ومفيش دوا؛ الباقي عيد ميلاده — واتسأل الصبح.
  const askedBirthday = { time_zone: "Africa/Cairo", newcomer: { key: "newcomer:birthday:" } };
  for (const [user, facts] of [
    [{ id: "u", created_at: new Date(NOW - 80 * HOUR).toISOString(), country: "EG" }, undefined],
    [{ id: "u", created_at: new Date(NOW - 5 * HOUR).toISOString(), country: "EG" }, askedBirthday],
  ] as const) {
    const updates: Array<Record<string, unknown>> = [];
    let pushed = 0;
    const res = await processVoiceMoments(fakeSb({
      zad_voice_moments: [momentRow(facts)], zad_users: [user], zad_customer_profile: [{ pay_day: 25 }],
    }, updates), {
      compose: () => Promise.reject(new Error("never")),
      pushDevice: () => { pushed++; return Promise.resolve("sent"); },
      pushTelegram: () => { pushed++; return Promise.resolve("delivered"); },
      timeZoneOf: () => Promise.resolve("Africa/Cairo"),
      now: () => NOW,
    });
    assertEquals([res.sent, res.skipped, pushed], [0, 1, 0]);
    assert(updates.some((u) => u.error === "nothing to ask"));
  }
});
