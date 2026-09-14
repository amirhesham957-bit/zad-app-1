// «فين راحت فلوسي؟» — تقرير الجمعة الصوتي (20260914008000).
import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { buildMomentPrompt, momentFallback, momentLimits, parseComposedMoment, processVoiceMoments, summarizeWeek, weeklyMomentFor } from "./voiceMoments.ts";
import { emotionForMoment } from "../_shared/zadVoice.ts";
import { speechLimitForMoment } from "../zad-telegram-bot/voiceAlert.ts";

const tx = (amount: number, category: string, title = category) => ({ amount, category, title, currency: "EGP" });

Deno.test("spending 20% less than last week with little waste is a proud week", () => {
  const w = summarizeWeek({
    thisWeek: [tx(400, "سوبرماركت"), tx(400, "مواصلات")],
    lastWeek: [tx(1000, "سوبرماركت")],
    wasted: [],
    monthlyLimit: null,
    currency: "EGP",
  })!;
  assertEquals(w.tone, "proud");
  assertEquals(w.spent, 800);
  assertEquals(w.saved_vs_last_week, 200);
  assertEquals(w.change_pct, -20);
  assertEquals(weeklyMomentFor(w.tone), "weekly_money_proud");
  assertEquals(emotionForMoment("weekly_money_proud"), "proud");
});

Deno.test("spending jumped or food went to waste — gentle reproach, with the biggest spend named", () => {
  const jump = summarizeWeek({
    thisWeek: [tx(300, "مطاعم", "طلبات"), tx(900, "مطاعم", "كنتاكي")],
    lastWeek: [tx(800, "سوبرماركت")],
    wasted: [],
    monthlyLimit: null,
    currency: "EGP",
  })!;
  assertEquals(jump.tone, "reproach");
  assertEquals(jump.top_categories[0], { name: "مطاعم", amount: 1200 });
  assertEquals(jump.biggest?.title, "كنتاكي");

  const waste = summarizeWeek({ thisWeek: [tx(500, "سوبرماركت")], lastWeek: [tx(520, "سوبرماركت")], wasted: ["لبن", "خبز", "طماطم"], monthlyLimit: null, currency: "EGP" })!;
  assertEquals(waste.tone, "reproach");
  assertEquals(emotionForMoment(weeklyMomentFor(waste.tone)), "reproachful");
});

Deno.test("over the weekly slice of the monthly limit is reproach even without last week", () => {
  const w = summarizeWeek({ thisWeek: [tx(3000, "تسوق")], lastWeek: [], wasted: [], monthlyLimit: 9000, currency: "EGP" })!;
  assertEquals(w.weekly_budget, 2100);
  assertEquals(w.tone, "reproach");
});

Deno.test("a week with no spending and no waste has nothing to tell", () => {
  assertEquals(summarizeWeek({ thisWeek: [], lastWeek: [tx(100, "x")], wasted: [], monthlyLimit: null, currency: null }), null);
});

Deno.test("the weekly story may be longer than an alert, on the phone and on Telegram", () => {
  assertEquals(momentLimits("weekly_money_proud").speech, 600);
  assertEquals(momentLimits("dose_missed").speech, 400);
  assertEquals(speechLimitForMoment("weekly_money_reproach"), 600);
  assertEquals(speechLimitForMoment("dose_missed"), 320);
  const long = "ك".repeat(550);
  const parsed = parseComposedMoment(`{"title":"t","text":"x","speech":"${long}"}`, true, momentLimits("weekly_money_story"));
  assertEquals(parsed?.speech.length, 550);
});

Deno.test("the prompt tells the model it is the weekly story and to use only the given numbers", () => {
  const p = buildMomentPrompt({ moment: "weekly_money_reproach", facts: { spent: 1200 } }, "EG", null);
  assertStringIncludes(p.system, "فين راحت فلوسي");
  assertStringIncludes(p.system, "عتاب لطيف");
  assertStringIncludes(p.user, "=== بيانات");
});

Deno.test("model down: the fallback still tells the week with real numbers and the wasted items", () => {
  const m = momentFallback("weekly_money_reproach", {
    spent: 1200, last_week_spent: 800, currency: "EGP", saved_vs_last_week: 0,
    top_categories: [{ name: "مطاعم", amount: 900 }], wasted_items: ["لبن"],
  });
  assertStringIncludes(m.text, "1200 EGP");
  assertStringIncludes(m.text, "مطاعم");
  assertStringIncludes(m.text, "لبن");
  assert(m.speech.length > 0);
});

Deno.test("a queued weekly story with its numbers already computed goes out under the tone's moment", async () => {
  const updates: unknown[] = [];
  const tables: Record<string, Array<Record<string, unknown>>> = {
    zad_voice_moments: [{
      id: "w1", user_id: "u1", moment: "weekly_money_story", status: "pending", attempts: 0, created_at: new Date().toISOString(),
      facts: { tone: "proud", spent: 800, last_week_spent: 1000, saved_vs_last_week: 200, currency: "EGP", top_categories: [] },
    }],
    zad_users: [{ id: "u1", country: "EG", name: null }],
  };
  const from = (table: string) => {
    const q: Record<string, unknown> = {
      select: () => q, eq: () => q, gte: () => q, order: () => q,
      limit: () => Promise.resolve({ data: tables[table] ?? [], error: null }),
      maybeSingle: () => Promise.resolve({ data: (tables[table] ?? [])[0] ?? null, error: null }),
      update: (values: unknown) => ({ eq: () => { updates.push(values); return Promise.resolve({ error: null }); } }),
    };
    return q;
  };
  const moments: string[] = [];
  // deno-lint-ignore no-explicit-any
  const res = await processVoiceMoments({ from } as any, {
    compose: () => Promise.reject(new Error("quota")),
    pushDevice: (_u, _t, _b, data) => { moments.push(`device:${data.moment}`); return Promise.resolve("sent"); },
    pushTelegram: (_u, _t, _b, _v, moment) => { moments.push(`tg:${moment}`); return Promise.resolve("delivered"); },
  });
  assertEquals(res.sent, 1);
  assertEquals(moments, ["device:weekly_money_proud", "tg:weekly_money_proud"]);
});
