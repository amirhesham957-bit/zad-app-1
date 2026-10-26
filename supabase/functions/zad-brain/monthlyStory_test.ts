// حكاية البيت الشهرية (ZAD_PLAN ٥.٢): القالب الاحتياطي بالأرقام بس، من غير أسامي تجار، والطول والمشاعر متسجلين.
import { assert, assertEquals } from "jsr:@std/assert@1";
import { BUSY_DAY_OPTIONAL_MOMENTS, momentFallback, momentLimits, MONTHLY_STORY_MOMENT } from "./voiceMoments.ts";
import { MOMENT_EMOTION_RANGE, MOMENT_EMOTIONS } from "../_shared/zadVoice.ts";

const facts = {
  month: "2026-10", currency: "EGP", spent: 4100, last_month_spent: 3500, change_pct: 17, txn_count: 23,
  top_categories: [{ name: "البقالة", amount: 1800 }, { name: "الرعاية الصحية", amount: 1500 }],
  weeks: { count: 4, highest: { from: "2026-10-06", spent: 2228 }, lowest: { from: "2026-10-13", spent: 746 } },
  learned: ["البقالة غالباً يوم الأربعاء: 8 مرة في 3 أسابيع مختلفة من آخر ٨، يعني 50٪ من مرات البقالة."],
};

Deno.test("monthly story fallback: the month's numbers, the comparison, the weeks, one learned line", () => {
  const m = momentFallback(MONTHLY_STORY_MOMENT, facts);
  assertEquals(m.title, "📖 حكاية البيت الشهر اللي فات");
  assertEquals(m.text.split("\n"), [
    "صرفت 4100 EGP الشهر اللي فات (اللي قبله 3500 EGP).",
    "أغلبها راح على البقالة: 1800 EGP.",
    "أغلى أسبوع 2228 EGP وأهداه 746 EGP.",
    "واتعلمت إن البقالة غالباً يوم الأربعاء: 8 مرة في 3 أسابيع مختلفة من آخر ٨، يعني 50٪ من مرات البقالة.",
    "الشهر الجاي: نبص على أكبر فئة سوا.",
  ]);
  assert(m.speech.includes("4100 EGP"));
});

Deno.test("monthly story fallback: a first month says no comparison and no week line it can't back", () => {
  const m = momentFallback(MONTHLY_STORY_MOMENT, { ...facts, last_month_spent: 0, weeks: { count: 1 }, learned: [] });
  assertEquals(m.text.split("\n")[0], "صرفت 4100 EGP الشهر اللي فات.");
  assert(!m.text.includes("أغلى أسبوع"));
  assert(!m.text.includes("اتعلمت"));
});

Deno.test("monthly story is registered: long like the weekly, warm voice, waits on a busy day", () => {
  assertEquals(momentLimits(MONTHLY_STORY_MOMENT), { text: 900, speech: 600 });
  assertEquals(MOMENT_EMOTIONS[MONTHLY_STORY_MOMENT], "warm");
  assert(MOMENT_EMOTION_RANGE[MONTHLY_STORY_MOMENT]?.includes("warm"));
  assert(BUSY_DAY_OPTIONAL_MOMENTS.has(MONTHLY_STORY_MOMENT));
});
