import { assert, assertEquals } from "jsr:@std/assert@1";
import { buildRestaurantArrivalMessage, normalizeStoreCategory, placesMatchingArrival } from "./shared.ts";
import { dealsAtPlace } from "./tasteDeals.ts";

// ZAD_PLAN ٤.١٨: «انت جنب المطعم» — عروضه السارية بس، ومن غير عرض مفيش رسالة.

const row = (store: string, item: string, price: number, extra: Record<string, unknown> = {}) => ({
  store, item_name: item, price, price_before: null, source_kind: "search", source_url: "https://x.example", valid_until: null, ...extra,
});

Deno.test("restaurant is a category the phone can send, and it fires no shopping reminders", () => {
  assertEquals(normalizeStoreCategory("Restaurant"), "restaurant");
  assertEquals(placesMatchingArrival("restaurant"), []);
  assertEquals(placesMatchingArrival("supermarket").sort(), ["any", "supermarket"]);
});

Deno.test("deals at the place: that store only, one line per item, three at most, a bad price is dropped", () => {
  const rows = [
    row("البيك", "وجبة بروستد ١+١", 25, { price_before: 40, valid_until: "2026-11-07T00:00:00Z", source_kind: "instagram" }),
    row("البيك", "وجبة بروستد ١+١", 22),
    row("كودو", "برجر", 15),
    row("البيك", "بطاطس", 0),
    row("البيك", "مسحب", 18), row("البيك", "شاورما", 12), row("البيك", "عصير", 5),
  ];
  const got = dealsAtPlace(rows, "البيك");
  assertEquals(got.length, 3);
  assert(!got.some((d) => d.item === "برجر"));
  assert(!got.some((d) => d.price <= 0));
  assertEquals(got[0], { item: "وجبة بروستد ١+١", price: 25, price_before: 40, until: "2026-11-07", source_kind: "instagram" });
  assertEquals(dealsAtPlace(rows, "ماكدونالدز"), []);
});

Deno.test("restaurant message: the deal with its source and date, nothing at all without one", () => {
  const msg = buildRestaurantArrivalMessage("البيك", [{ item: "وجبة ١+١", price: 25, price_before: 40, until: "2026-11-07", source_kind: "instagram" }]);
  assertEquals(msg?.title, "🍽️ أنت جنب «البيك»");
  assert(msg?.body.includes("وجبة ١+١ بـ25 بدل 40 لحد 2026-11-07 (حسابهم على إنستجرام)"));
  assert(msg?.body.includes("ممكن يكون خلص"));
  assertEquals(buildRestaurantArrivalMessage("البيك", []), null);
});
