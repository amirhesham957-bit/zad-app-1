// المناسبات في العقل: الأداة، التوجيه، تحية الصبح (المناسبة وعرض الهدية)، والسؤال في السناب شوت.
import { assert, assertEquals } from "jsr:@std/assert@1";
import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { askedThisMorning } from "./curiosity.ts";
import { intentToolHints, scopeToolsForSpecialist } from "./specialists.ts";
import { freshContext, MUTATING_TOOLS, validateRememberOccasion, VALIDATORS } from "./validators.ts";
import { momentFallback, morningFacts, occasionLine } from "./voiceMoments.ts";

/** قاعدة مزيفة: كل جدول بيرجّع صفوفه لأي فلتر، والـrpc بيرجّع اللي اتحدد له. */
function fakeSb(tables: Record<string, unknown[]>, rpcs: Record<string, unknown>): SupabaseClient {
  const chain = (data: unknown): unknown =>
    new Proxy({}, {
      get(_t, prop) {
        if (prop === "then") {
          return (res: (v: unknown) => unknown, rej: (e: unknown) => unknown) =>
            Promise.resolve({ data, error: null }).then(res, rej);
        }
        if (prop === "maybeSingle" || prop === "single") {
          return () => chain(Array.isArray(data) ? data[0] ?? null : data);
        }
        return () => chain(data);
      },
    });
  return {
    from: (table: string) => chain(tables[table] ?? []),
    rpc: (fn: string) => chain(rpcs[fn] ?? null),
  } as unknown as SupabaseClient;
}

const LOCAL = { date: "2026-10-05", time_zone: "Africa/Cairo", utc_offset: "+03:00" };
const PROFILE = { preferred_name: "سارة", gender: null, household_role: null, pay_day: null, cares_for: null, occupation: null };
const BUDGET = { limit_confirmed: true, available: 6000, days_left: 20, currency: "EGP" };

Deno.test("the tool takes a real day and a known kind only", async () => {
  const ok = (input: Record<string, unknown>) => validateRememberOccasion(input, {}, freshContext("u"));
  assertEquals((await ok({ occasion: "birthday", person: "ماما", month: 3, day: 12 })).ok, true);
  assertEquals((await ok({ occasion: "anniversary", month: 2, day: 29 })).ok, true);
  assertEquals((await ok({ occasion: "birthday", month: 2, day: 30 })).ok, false);
  assertEquals((await ok({ occasion: "birthday", month: 3 })).ok, false);
  assertEquals((await ok({ occasion: "graduation", month: 3, day: 1 })).ok, false);
  assertEquals((await ok({ occasion: "birthday", person: "x".repeat(41), month: 3, day: 1 })).ok, false);
  assert(VALIDATORS.remember_occasion === validateRememberOccasion);
  assert(MUTATING_TOOLS.includes("remember_occasion"));
});

Deno.test("a date for someone routes to remember_occasion, in every specialist", () => {
  assert(intentToolHints("عيد ميلاد مراتي ١٢ مارس").includes("remember_occasion"));
  assert(intentToolHints("ذكرى جوازنا يوم ٥ يونيو").includes("remember_occasion"));
  assert(!intentToolHints("صرفت ٥٠ قهوة").includes("remember_occasion"));
  const tools = [{ name: "remember_occasion" }, { name: "add_inventory_item" }];
  assert(scopeToolsForSpecialist(tools, "pantry").some((t) => t.name === "remember_occasion"));
  assert(
    scopeToolsForSpecialist(tools, "general", null, intentToolHints("عيد ميلاد ماما امتى؟")).some((t) => t.name === "remember_occasion"),
  );
});

Deno.test("three days before someone's birthday: the occasion and a gift offer, as the day's one question", async () => {
  const sb = fakeSb(
    { zad_customer_profile: [PROFILE] },
    {
      zad_budget_state: BUDGET,
      zad_memory_occasions: [{ id: "n1", occasion: "birthday", occasion_for: "ماما", occasion_md: "10-08", note: "عيد ميلاد ماما: 8 أكتوبر" }],
    },
  );
  const facts = await morningFacts(sb, "u", LOCAL);
  assertEquals(facts.occasions, [{ occasion: "birthday", for: "ماما", md: "10-08", in_days: 3 }]);
  assertEquals(facts.gift_offer, { for: "ماما", amount: 300, currency: "EGP", deadline: "2026-10-08", on: "8 أكتوبر" });
  assertEquals(facts.daily_question_kind, "gift");
  assertEquals(facts.daily_question, "أحجزلك 300 EGP من المتاح لهدية ماما؟");
  assertEquals(facts.daily_question_field, undefined);
});

Deno.test("no confirmed budget: the reminder without money, and the profile question back", async () => {
  const sb = fakeSb(
    { zad_customer_profile: [PROFILE] },
    {
      zad_budget_state: { ...BUDGET, limit_confirmed: false },
      zad_memory_occasions: [{ id: "n1", occasion: "birthday", occasion_for: "ماما", occasion_md: "10-08", note: "x" }],
    },
  );
  const facts = await morningFacts(sb, "u", LOCAL);
  assertEquals((facts.occasions as unknown[]).length, 1);
  assertEquals(facts.gift_offer, undefined);
  assertEquals(facts.daily_question_kind, "profile");
});

Deno.test("the customer's own birthday today: congratulated, nothing to buy", async () => {
  const sb = fakeSb(
    { zad_customer_profile: [PROFILE] },
    {
      zad_budget_state: BUDGET,
      zad_memory_occasions: [
        { id: "n2", occasion: "birthday", occasion_for: null, occasion_md: "10-05", note: "عيد ميلاد العميل: 5 أكتوبر" },
        { id: "n3", occasion: "birthday", occasion_for: "يوسف", occasion_md: "12-01", note: "x" },
      ],
    },
  );
  const facts = await morningFacts(sb, "u", LOCAL);
  assertEquals(facts.occasions, [{ occasion: "birthday", for: null, md: "10-05", in_days: 0 }]);
  assertEquals(facts.gift_offer, undefined);
  const greeting = momentFallback("morning_greeting", facts);
  assertEquals(greeting.title, "🎂 كل سنة وإنت طيب");
  assert(greeting.text.startsWith("كل سنة وإنت طيب!"));
});

Deno.test("the fallback greeting names the person and the day", () => {
  assertEquals(occasionLine([{ occasion: "birthday", for: "ماما", in_days: 3, md: "10-08" }]).line, "فاضل ٣ أيام على عيد ميلاد ماما (8 أكتوبر).");
  assertEquals(occasionLine([{ occasion: "birthday", for: "ماما", in_days: 0, md: "10-05" }]).line, "النهارده عيد ميلاد ماما 🎂 — ماتنساش تتصل تهنّي.");
  assertEquals(occasionLine([{ occasion: "anniversary", for: null, in_days: 0 }]), { line: "كل سنة وإنتو طيبين! 💍 النهارده ذكرى جوازكم.", own: false });
  assertEquals(occasionLine(undefined), { line: "", own: false });
  const plain = momentFallback("morning_greeting", {});
  assertEquals(plain.title, "☀️ صباح الخير");
});

Deno.test("the gift question reaches the next chat turn with what was offered", () => {
  const sentAt = new Date().toISOString();
  const asked = askedThisMorning({
    sent_at: sentAt,
    facts: {
      daily_question: "أحجزلك 300 EGP من المتاح لهدية ماما؟",
      daily_question_kind: "gift",
      gift_offer: { for: "ماما", amount: 300, currency: "EGP", deadline: "2026-10-08", on: "8 أكتوبر" },
    },
  });
  assertEquals(asked, {
    question: "أحجزلك 300 EGP من المتاح لهدية ماما؟",
    kind: "gift",
    for: "ماما",
    amount: 300,
    currency: "EGP",
    deadline: "2026-10-08",
    sent_at: sentAt,
  });
});

Deno.test("the brain asks for a missing birthday itself: the customer's first, then people it knows", async () => {
  const { occasionQuestion } = await import("./occasions.ts");
  const mama = { occasion: "birthday", occasion_for: "ماما", occasion_md: "03-12" };
  const own = { occasion: "birthday", occasion_for: null, occasion_md: "07-04" };
  assertEquals(occasionQuestion([], [], "2026-10-04")?.for, null);
  assertEquals(occasionQuestion([own, mama], ["ماما", "يوسف"], "2026-10-04"), {
    for: "يوسف",
    question: "عيد ميلاد يوسف امتى؟ عشان أفكّرك قبلها",
  });
  assertEquals(occasionQuestion([own, mama], ["ماما"], "2026-10-04"), null);
  // one a day, rotating: tomorrow is someone else
  const today = occasionQuestion([own], ["يوسف", "مريم"], "2026-10-04")?.for;
  const tomorrow = occasionQuestion([own], ["يوسف", "مريم"], "2026-10-05")?.for;
  assert(today !== tomorrow);
});

Deno.test("profile done, no gift: the morning asks for a birthday, and the answer comes back as kind occasion", async () => {
  const fullProfile = { preferred_name: "سارة", gender: "female", household_role: "mother", pay_day: 25, cares_for: "children", occupation: "مهندسة" };
  // 2026-10-04 is an even day: occasions take it before curiosity.
  const sb = fakeSb(
    { zad_customer_profile: [fullProfile], zad_memory_entities: [{ name: "يوسف" }] },
    { zad_budget_state: BUDGET, zad_memory_occasions: [{ id: "n", occasion: "birthday", occasion_for: null, occasion_md: "07-04", note: "x" }] },
  );
  const facts = await morningFacts(sb, "u", { ...LOCAL, date: "2026-10-04" });
  assertEquals(facts.daily_question_kind, "occasion");
  assertEquals(facts.occasion_ask, { for: "يوسف" });
  const asked = askedThisMorning({ sent_at: new Date().toISOString(), facts });
  assertEquals(asked?.kind, "occasion");
  assertEquals(asked?.for, "يوسف");
});
