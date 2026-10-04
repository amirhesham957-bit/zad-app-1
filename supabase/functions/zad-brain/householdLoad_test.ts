// «ضغط البيت» من أرقام البيت والساعة — مش حالة العميل النفسية.
import { assert, assertEquals } from "jsr:@std/assert@1";
import { householdLoad, householdLoadRule } from "./householdLoad.ts";
import { buildChatSystemPrompt, buildSystemPrompt } from "./index.ts";

const calm = { threat: "SAFE", available: 4000, budget: 10000, brokeMode: false, localHour: 14 };

Deno.test("household load: money running out, broke mode or the small hours are high", () => {
  assertEquals(householdLoad({ ...calm, threat: "OVER" }).level, "high");
  assertEquals(householdLoad({ ...calm, threat: "DANGER" }).level, "high");
  assertEquals(householdLoad({ ...calm, available: -50 }).level, "high");
  assertEquals(householdLoad({ ...calm, brokeMode: true }).level, "high");
  assertEquals(householdLoad({ ...calm, localHour: 2 }).level, "high");
  assertEquals(householdLoad({ ...calm, brokeMode: true, threat: "OVER" }).reasons.length, 2);
});

Deno.test("household load: a safe budget with room left is easy; anything unclear is normal", () => {
  assertEquals(householdLoad(calm).level, "easy");
  assertEquals(householdLoad({ ...calm, available: 1000 }).level, "normal", "under 30% of the budget");
  assertEquals(householdLoad({ ...calm, threat: "WATCH" }).level, "normal");
  assertEquals(householdLoad({ ...calm, threat: "UNKNOWN" }).level, "normal");
  assertEquals(householdLoad({ ...calm, budget: null }).level, "normal", "no ceiling, no surplus to speak of");
  assertEquals(householdLoad({ ...calm, available: null }).level, "normal");
  assertEquals(householdLoad({ ...calm, localHour: 5 }).level, "easy", "5 AM is morning");
});

Deno.test("household load: the rule speaks of the house, never of the customer's mind", () => {
  const rule = householdLoadRule({ household_load: householdLoad(calm) });
  assert(rule.includes("مش حالة العميل النفسية"));
  assert(rule.includes("عمرك ما تقوله «إنت متوتر»"));
  assertEquals(householdLoadRule({}), "");
  assertEquals(householdLoadRule(null), "");
});

Deno.test("household load: both the chat and the daily analysis carry the rule", () => {
  const snap = { household_load: householdLoad({ ...calm, threat: "OVER" }) };
  assert(buildChatSystemPrompt(snap).includes("**household_load**"));
  assert(buildSystemPrompt(snap).includes("high ⇒ رؤية واحدة بالكتير"));
});
