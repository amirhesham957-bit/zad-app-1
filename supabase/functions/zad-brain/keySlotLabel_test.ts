import { assertEquals } from "jsr:@std/assert@1";
import { keySlotLabel } from "./callModel.ts";

// The log said «Gemini key 12/1» for the test account's free keys: index over the customer pool.
Deno.test("the 429 log names the key inside its own pool", () => {
  // paid pool of 1, eval key at index 1, ten free keys from index 2.
  assertEquals(keySlotLabel(0, 1, 1, 2, 10, true), "paid key 1/1");
  assertEquals(keySlotLabel(1, 1, 1, 2, 10, true), "eval key");
  assertEquals(keySlotLabel(11, 1, 1, 2, 10, true), "free key 10/10");
  assertEquals(keySlotLabel(2, 1, 1, 2, 10, true), "free key 1/10");
  // no paid key: the pool itself is the free one.
  assertEquals(keySlotLabel(3, 5, null, 5, 0, false), "free key 4/5");
});
