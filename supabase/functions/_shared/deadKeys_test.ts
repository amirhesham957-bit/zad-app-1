import { assert, assertEquals } from "jsr:@std/assert@1";
import { DEAD_KEY_MS, DeadKeys, RATE_LIMIT_DEFAULT_MS, RATE_LIMIT_MAX_MS } from "./deadKeys.ts";

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

Deno.test("a 429 key rests as long as retry-after says, a minute without it, an hour at most", () => {
  let now = 0;
  const d = new DeadKeys(() => now);
  assert(!d.markIfRateLimited("k0", 401, 5_000));
  assert(d.markIfRateLimited("k1", 429, 5_000));
  assert(d.markIfRateLimited("k2", 429));
  assert(d.markIfRateLimited("k3", 429, 24 * 60 * 60 * 1000));
  assertEquals(d.order(["k0", "k1", "k2", "k3"], 0), ["k0"]);
  now = 5_001;
  assertEquals(d.order(["k0", "k1", "k2", "k3"], 0), ["k0", "k1"]);
  now = RATE_LIMIT_DEFAULT_MS + 1;
  assertEquals(d.order(["k0", "k1", "k2", "k3"], 0), ["k0", "k1", "k2"]);
  now = RATE_LIMIT_MAX_MS + 1;
  assertEquals(d.order(["k0", "k1", "k2", "k3"], 0), ["k0", "k1", "k2", "k3"]);
});

Deno.test("a 429 never shortens a 401's 30 minutes", () => {
  let now = 0;
  const d = new DeadKeys(() => now);
  d.markIfRejected("k", 401);
  d.markIfRateLimited("k", 429, 1_000);
  now = 2_000;
  assert(d.isDead("k"));
});
