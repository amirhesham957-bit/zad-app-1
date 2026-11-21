// ZAD_OR_PLAN م٤: اللقطة بتبدأ استعلاماتها كلها مع بعض. بناة supabase كسالى، فـprefetch لازم يبعتهم فعلاً.
import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import { prefetch } from "./index.ts";

/** زي PostgrestBuilder: مابيشتغلش غير لما حد يعمل then. */
function lazyQuery<T>(value: T, ran: string[], name: string, fail = false): PromiseLike<T> {
  return {
    then(ok, bad) {
      ran.push(name);
      const p = fail ? Promise.reject(new Error(name)) : Promise.resolve(value);
      return p.then(ok, bad);
    },
  };
}

Deno.test("prefetch starts every lazy query before anything awaits it", async () => {
  const ran: string[] = [];
  const a = prefetch(lazyQuery(1, ran, "a"));
  const b = prefetch(lazyQuery(2, ran, "b"));
  await Promise.resolve();
  assertEquals(ran, ["a", "b"]);
  assertEquals(await b, 2);
  assertEquals(await a, 1);
});

Deno.test("a rejected prefetch nobody awaits yet does not crash, and the awaiter still sees the error", async () => {
  const ran: string[] = [];
  const bad = prefetch(lazyQuery(0, ran, "boom", true));
  await new Promise((r) => setTimeout(r, 10));
  await assertRejects(() => bad, Error, "boom");
});
