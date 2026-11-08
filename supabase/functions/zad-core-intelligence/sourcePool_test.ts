import { assertEquals } from "jsr:@std/assert@1";
import { dealSearchCacheKey, refused, withoutResting } from "./sourcePool.ts";

Deno.test("only an explicit refusal rests a source", () => {
  assertEquals(refused(["tavily:429"]), true);
  assertEquals(refused(["google_cse:403", "brave:200"]), true);
  for (const a of ["tavily:200 hits=3", "tavily:threw timeout", "bing_news:500", "google_news:404", "x:4290"]) {
    assertEquals(refused([a]), false, a);
  }
  assertEquals(refused([]), false);
});

Deno.test("a resting source is skipped and the next one answers", () => {
  const list = [["a", 1], ["b", 2], ["c", 3]] as const;
  assertEquals(withoutResting(list, new Set(["a"])).map(([n]) => n), ["b", "c"]);
  assertEquals(withoutResting(list, new Set()).length, 3);
});

Deno.test("if every source rests the search still runs", () => {
  const list = [["a", 1], ["b", 2]] as const;
  assertEquals(withoutResting(list, new Set(["a", "b"])).map(([n]) => n), ["a", "b"]);
});

Deno.test("the same question shares a cached answer", () => {
  assertEquals(dealSearchCacheKey("عروض   كارفور", 8, "EG"), dealSearchCacheKey("عروض كارفور", 8, "EG"));
  assertEquals(dealSearchCacheKey("عروض كارفور", 8, "EG") === dealSearchCacheKey("عروض كارفور", 8, "SA"), false);
});
