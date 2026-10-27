import { assert, assertEquals } from "jsr:@std/assert@1";
import { houseLearningPush } from "./houseLearningPush.ts";

Deno.test("house learning push (5.2): data-only fields name the learning, and its note is under the model's words", () => {
  const p = houseLearningPush({ id: "11111111-2222-3333-4444-555555555555", note: "البقالة بتتشرى يوم الأربع" }, "صرفت ١٢٠٠ الأسبوع ده. صح؟");
  assertEquals(p.data, { kind: "house_learning", learning_id: "11111111-2222-3333-4444-555555555555", route: "home" });
  assert(p.body.startsWith("صرفت ١٢٠٠ الأسبوع ده. صح؟"));
  assert(p.body.endsWith("🧠 البقالة بتتشرى يوم الأربع"));
  assertEquals(houseLearningPush({ id: "x", note: "n" }, "ا".repeat(500)).body.length, 180 + 2 + 4);
});
