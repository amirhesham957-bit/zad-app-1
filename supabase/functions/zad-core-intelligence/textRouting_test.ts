import { assertEquals } from "jsr:@std/assert@1";
import { escalateOnBadJson, escalationModel, parseModelJson, repairModelJson } from "./textRouting.ts";

Deno.test("model JSON: fences stripped, broken text is null", () => {
  assertEquals(parseModelJson('```json\n{"a":1}\n```'), { a: 1 });
  assertEquals(parseModelJson('{"a":1}'), { a: 1 });
  assertEquals(parseModelJson("{a:1"), null);
  assertEquals(parseModelJson(null), null);
});

Deno.test("broken JSON from the light model is asked once of the heavy one — never returned broken", async () => {
  let heavyCalls = 0;
  const heavy = () => { heavyCalls++; return Promise.resolve('{"ok":true}'); };
  assertEquals(await escalateOnBadJson('{"ok": tru', heavy), { value: { ok: true }, escalated: true });
  assertEquals(heavyCalls, 1);
  assertEquals(await escalateOnBadJson('{"ok":1}', heavy), { value: { ok: 1 }, escalated: false });
  assertEquals(heavyCalls, 1, "good JSON never costs a heavy call");
  assertEquals(await escalateOnBadJson(null, heavy), { value: null, escalated: false });
  assertEquals(heavyCalls, 1, "a provider failure is the chain's job, not an escalation");
});

Deno.test("the chef's real slip (2026-11-15): a missing comma between two keys is repaired", () => {
  const raw = '{"text":"يا ميرو، جمعت لك أفكار" "recipes":[{"recipe_name":"باذنجان متبل","prep_time_minutes":20 "cost_estimate":0}]}';
  assertEquals(parseModelJson(raw), {
    text: "يا ميرو، جمعت لك أفكار",
    recipes: [{ recipe_name: "باذنجان متبل", prep_time_minutes: 20, cost_estimate: 0 }],
  });
});

Deno.test("repair: missing commas between array items and after literals, trailing commas dropped", () => {
  assertEquals(parseModelJson('{"a":[1 2 3],"b":true "c":null "d":{"x":1} "e":[{"y":2} {"z":3}],}'), {
    a: [1, 2, 3], b: true, c: null, d: { x: 1 }, e: [{ y: 2 }, { z: 3 }],
  });
  assertEquals(parseModelJson('[-1.5e3 "x",]'), [-1500, "x"]);
});

Deno.test("repair never touches the inside of a string", () => {
  const s = '{"q":"قال \\"أهلاً\\" \\"تاني\\" ,} ]"}';
  assertEquals(repairModelJson(s), s);
  assertEquals(parseModelJson(s), { q: 'قال "أهلاً" "تاني" ,} ]' });
});

Deno.test("repair does not invent an answer: cut-off or unquoted JSON stays unreadable", () => {
  assertEquals(parseModelJson('{"recipes":[{"recipe_name":"باذنجان'), null);
  assertEquals(parseModelJson("{a:1}"), null);
  assertEquals(parseModelJson("ده مش JSON"), null);
});

Deno.test("escalation always asks another model, never the one that just failed", () => {
  assertEquals(escalationModel("lite", "flash", "lite"), "flash", "light failed ⇒ heavy");
  assertEquals(escalationModel("flash", "flash", "lite"), "lite", "heavy failed ⇒ light (was: nobody)");
  assertEquals(escalationModel("same", "same", "same"), null, "one model configured ⇒ no retry");
});
