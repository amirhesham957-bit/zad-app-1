import { assert, assertEquals } from "jsr:@std/assert@1";
import { DEAD_KEY_MS, DeadKeys } from "./deadKeys.ts";

Deno.test("a 401/403 key is skipped, a 429 key is not, and the dead key comes back after 30 minutes", () => {
  let now = 1_000_000;
  const d = new DeadKeys(() => now);
  assert(d.markIfRejected("k1", 401));
  assert(!d.markIfRejected("k2", 429));
  assertEquals(d.order(["k1", "k2"], 0), ["k2"]);
  now += DEAD_KEY_MS + 1;
  assertEquals(d.order(["k1", "k2"], 0), ["k1", "k2"]);
});

Deno.test("rotation starts where the cursor says, and if every key is dead they're all tried anyway", () => {
  const d = new DeadKeys(() => 0);
  assertEquals(d.order(["a", "b", "c"], 1), ["b", "c", "a"]);
  d.markIfRejected("a", 403);
  d.markIfRejected("b", 401);
  d.markIfRejected("c", 401);
  assertEquals(d.order(["a", "b", "c"], 0), ["a", "b", "c"]);
});
