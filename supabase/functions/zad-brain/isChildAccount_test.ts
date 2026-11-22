import { assertEquals } from "jsr:@std/assert@1";
import { isChildAccount } from "./voiceMoments.ts";

// deno-lint-ignore no-explicit-any
const sb = (res: any) => ({ from: () => ({ select: () => ({ eq: () => ({ maybeSingle: () => Promise.resolve(res) }) }) }) }) as any;

Deno.test("role=child ⇒ true", async () => assertEquals(await isChildAccount(sb({ data: { role: "child" }, error: null }), "u"), true));
Deno.test("role=admin ⇒ false", async () => assertEquals(await isChildAccount(sb({ data: { role: "admin" }, error: null }), "u"), false));
Deno.test("مفيش عيلة ⇒ false", async () => assertEquals(await isChildAccount(sb({ data: null, error: null }), "u"), false));
Deno.test("فشل القراءة ⇒ true (آمن)", async () => assertEquals(await isChildAccount(sb({ data: null, error: { message: "x" } }), "u"), true));
