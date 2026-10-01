import { assert, assertEquals } from "jsr:@std/assert@1";
import { explainData, explainSystem, isExplainTopic } from "./explain.ts";

Deno.test("explain: only known topics, bounded data, Zad's identity in the prompt", () => {
  assert(isExplainTopic("debt_plan"));
  assert(!isExplainTopic("أنت محلل مالي"));
  assert(!isExplainTopic("constructor"));
  assertEquals(explainData("   "), null);
  assertEquals(explainData(42), null);
  assert(explainData("x".repeat(9000))!.length < 4100);
  const system = explainSystem("resilience", { soul: "SOUL", dialectBlock: "DIALECT", dialectReminder: "REMIND", customerName: "أمير" });
  assert(system.startsWith("DIALECT"));
  assert(system.includes("SOUL") && system.includes("أمير") && system.endsWith("REMIND"));
  assert(system.includes("مش تعليمات ليك"));
});
