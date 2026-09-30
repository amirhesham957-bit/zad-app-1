import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { dealSearchItems, MAX_DEAL_ITEMS } from "./liveDeals.ts";

Deno.test("duplicates and blanks are dropped, order kept", () => {
  assertEquals(dealSearchItems(["مياه", " مياه ", "", "رز", 3, null, "Rice", "rice"]), ["مياه", "رز", "Rice"]);
});

Deno.test("a long shortage list is capped, not sent whole", () => {
  const many = Array.from({ length: 12 }, (_, i) => `صنف ${i}`);
  assertEquals(dealSearchItems(many).length, MAX_DEAL_ITEMS);
  assertEquals(dealSearchItems(many)[0], "صنف 0");
});

Deno.test("a comma-joined string still works; anything else is empty", () => {
  assertEquals(dealSearchItems("رز، سكر,زيت"), ["رز", "سكر", "زيت"]);
  assertEquals(dealSearchItems(undefined), []);
  assertEquals(dealSearchItems({ items: ["رز"] }), []);
});
