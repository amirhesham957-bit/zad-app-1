// تحدي ٣٠ يوم توفير (20260914010000).
import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { challengeDayIndex, suggestChallengeCap } from "../_shared/savingsChallenge.ts";
import { emotionForMoment } from "../_shared/zadVoice.ts";
import { buildMomentPrompt, momentFallback } from "./voiceMoments.ts";
import { freshContext, validateStartSavingsChallenge } from "./validators.ts";

Deno.test("the suggested cap is 80% of the real daily average, else 90% of today's allowance, else nothing", () => {
  assertEquals(suggestChallengeCap({ avgDailySpend: 250, dailyAllowanceLeft: 400 }), 200);
  assertEquals(suggestChallengeCap({ avgDailySpend: null, dailyAllowanceLeft: 155 }), 139);
  assertEquals(suggestChallengeCap({ avgDailySpend: 0, dailyAllowanceLeft: -10 }), null);
});

Deno.test("day index counts the start day as day 1, by local date", () => {
  assertEquals(challengeDayIndex("2026-09-14", "2026-09-14"), 1);
  assertEquals(challengeDayIndex("2026-09-14", "2026-10-13"), 30);
});

Deno.test("milestones and completion are proud, a broken streak is sad", () => {
  assertEquals(emotionForMoment("challenge_milestone"), "proud");
  assertEquals(emotionForMoment("challenge_completed"), "proud");
  assertEquals(emotionForMoment("challenge_streak_broken"), "sad");
});

Deno.test("fallbacks carry the streak, the result and yesterday's spend vs the cap", () => {
  assertStringIncludes(momentFallback("challenge_milestone", { streak: 7, day: 9, length_days: 30 }).text, "7");
  assertStringIncludes(momentFallback("challenge_completed", { days_won: 26, length_days: 30, best_streak: 12 }).text, "26");
  const broken = momentFallback("challenge_streak_broken", { yesterday_spent: 180, daily_cap: 120, currency: "EGP", broken_streak: 5 });
  assertStringIncludes(broken.text, "180 EGP");
  assert(broken.speech.length > 0);
  assertStringIncludes(buildMomentPrompt({ moment: "challenge_streak_broken", facts: {} }, "EG", null).system, "مش لوم");
});

Deno.test("start_savings_challenge accepts a sane cap and length only", async () => {
  assert((await validateStartSavingsChallenge({}, {}, freshContext("u1"))).ok);
  assert((await validateStartSavingsChallenge({ daily_cap: 150, length_days: 21 }, {}, freshContext("u1"))).ok);
  assert(!(await validateStartSavingsChallenge({ daily_cap: 0 }, {}, freshContext("u1"))).ok);
  assert(!(await validateStartSavingsChallenge({ length_days: 3 }, {}, freshContext("u1"))).ok);
});
