import { assert, assertStringIncludes } from "jsr:@std/assert@1";
import { INITIATIVE_RULE } from "./persona.ts";

Deno.test("the initiative rule is in the chat prompt, and bounded", async () => {
  const source = await Deno.readTextFile(new URL("./index.ts", import.meta.url));
  assert(source.includes("${INITIATIVE_RULE}"));
  assertStringIncludes(INITIATIVE_RULE, "مرة في المحادثة بالكتير");
  assertStringIncludes(INITIATIVE_RULE, "متألفش");
  assertStringIncludes(INITIATIVE_RULE, "متسألش عن حاجة عارفها");
  assert(INITIATIVE_RULE.length < 800, "paid for on every turn");
});
