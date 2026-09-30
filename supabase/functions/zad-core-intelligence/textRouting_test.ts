import { assertEquals } from "jsr:@std/assert@1";
import { escalateOnBadJson, parseModelJson } from "./textRouting.ts";

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
