import { assertEquals } from "jsr:@std/assert@1";
import { countBy, sanitizeError } from "./pipelineHealth.ts";

Deno.test("sanitizeError strips customer text, ids and long numbers", () => {
  const out = sanitizeError("rejected: فكرني الساعة ٥ user 3f2a9c1e-1111-2222-3333-444455556666 amount 1234567");
  assertEquals(/[؀-ۿ]/.test(out), false);
  assertEquals(out.includes("3f2a9c1e"), false);
  assertEquals(out.includes("1234567"), false);
  assertEquals(sanitizeError(""), "(empty)");
});

Deno.test("countBy ranks keys by count and caps the list", () => {
  const rows = ["a", "b", "a", "c", "a", "b"];
  assertEquals(countBy(rows, (r) => r, 2), { a: 3, b: 2 });
});
