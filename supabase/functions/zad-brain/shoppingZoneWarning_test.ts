// «افتكر إننا متفقين نوفّر» عند دخول منطقة تسوق (store_arrival → shopping_zone_warning).
import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { savingsAgreementFrom } from "../_shared/savingsAgreement.ts";
import { emotionForMoment } from "../_shared/zadVoice.ts";
import { buildMomentPrompt, momentFallback } from "./voiceMoments.ts";

const base = { brokeActive: false, brokeDailyCap: null, challenge: null, threat: "SAFE", dailyAllowanceLeft: 300, currency: "EGP" };

Deno.test("no savings agreement, no warning — Zad doesn't nag on every store visit", () => {
  assertEquals(savingsAgreementFrom(base), null);
  assertEquals(savingsAgreementFrom({ ...base, threat: "WATCH" }), null);
});

Deno.test("broke mode beats a challenge, which beats a budget in danger", () => {
  assertEquals(savingsAgreementFrom({ ...base, brokeActive: true, brokeDailyCap: 20, challenge: { daily_cap: 150, streak: 4 }, threat: "OVER" })?.reason, "broke");
  const ch = savingsAgreementFrom({ ...base, challenge: { daily_cap: 150, streak: 4 }, threat: "DANGER" });
  assertEquals(ch?.reason, "challenge");
  assertEquals(ch?.streak, 4);
  const budget = savingsAgreementFrom({ ...base, threat: "DANGER", dailyAllowanceLeft: 87.6 });
  assertEquals(budget?.reason, "budget");
  assertEquals(budget?.daily_cap, 88);
});

Deno.test("the warning is teasing, short, and knows the deal and the list", () => {
  assertEquals(emotionForMoment("shopping_zone_warning"), "playful");
  const m = momentFallback("shopping_zone_warning", { store_name: "كارفور", reason: "challenge", daily_cap: 150, currency: "EGP", list_count: 3 });
  assertStringIncludes(m.text, "كارفور");
  assertStringIncludes(m.text, "150 EGP");
  assertStringIncludes(m.text, "3");
  assertStringIncludes(m.speech, "القايمة");
  assert(m.speech.length < 160);
  assertStringIncludes(buildMomentPrompt({ moment: "shopping_zone_warning", facts: {} }, "EG", null).system, "مش لوم");
});

Deno.test("a place reminder that carries the savings deal asks the model to mention it", () => {
  assertStringIncludes(buildMomentPrompt({ moment: "place_reminder", facts: { savings: { reason: "broke" } } }, "EG", null).system, "savings");
});
