import { assert, assertEquals, assertNotEquals } from "jsr:@std/assert@1";
import { chooseArm, isMinor, type Posteriors, seededRng, update } from "./banditTone.ts";

const adult = { memberId: "m1", age: 30 };
const arms = ["warm", "formal", "short"];

Deno.test("minors get null", () => {
  assertEquals(chooseArm({ memberId: "k", age: 17 }, arms, {}, seededRng(1)), null);
  assertEquals(chooseArm({ memberId: "k", isMinor: true }, arms, {}, seededRng(1)), null);
  assert(isMinor({ memberId: "k", age: 17 }));
  assert(!isMinor({ memberId: "a", age: 18 }));
  assert(!isMinor({ memberId: "u" }));
});

Deno.test("empty approved list -> null", () => {
  assertEquals(chooseArm(adult, [], {}, seededRng(1)), null);
});

Deno.test("deterministic with same seed, result always approved", () => {
  const a = chooseArm(adult, arms, {}, seededRng(42));
  const b = chooseArm(adult, arms, {}, seededRng(42));
  assertEquals(a, b);
  assert(arms.includes(a!));
});

Deno.test("strong winner is chosen most of the time", () => {
  const post: Posteriors = {
    m1: { warm: { successes: 50, failures: 2 }, formal: { successes: 2, failures: 50 } },
  };
  const rng = seededRng(7);
  let warm = 0;
  for (let i = 0; i < 200; i++) if (chooseArm(adult, ["warm", "formal"], post, rng) === "warm") warm++;
  assert(warm > 190);
});

Deno.test("posteriors are per member", () => {
  const post: Posteriors = { m1: { warm: { successes: 60, failures: 0 }, formal: { successes: 0, failures: 60 } } };
  const rng = seededRng(3);
  let other = 0;
  for (let i = 0; i < 200; i++) if (chooseArm({ memberId: "m2", age: 40 }, ["warm", "formal"], post, rng) === "formal") other++;
  assert(other > 50 && other < 150);
});

Deno.test("update immutable, ignores minors and unapproved arms", () => {
  const p0: Posteriors = {};
  const p1 = update(p0, adult, "warm", arms, true);
  assertEquals(p1.m1.warm, { successes: 1, failures: 0 });
  assertEquals(p0, {});
  assertEquals(update(p1, { memberId: "k", age: 10 }, "warm", arms, true), p1);
  assertEquals(update(p1, adult, "secret", arms, true), p1);
  assertNotEquals(update(p1, adult, "warm", arms, false), p1);
});
