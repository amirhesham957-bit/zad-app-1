import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { formatCommunityPricesPost, MIN_ITEMS_PER_MARKET } from "./communityPrices.ts";

const row = (item_name: string, min_price: number, reports: number, store: string | null = null) =>
  ({ item_name, min_price, avg_price: min_price + 2, reports, cheapest_location: "القاهرة", cheapest_store: store });

Deno.test("a market with enough reports is posted with price, place and report count", () => {
  const post = formatCommunityPricesPost([
    { currency: "EGP", label: "🇪🇬 مصر", rows: [row("طماطم", 12, 5, "كارفور"), row("بيض", 150.5, 3), row("لبن", 40, 2)] },
    { currency: "SAR", label: "🇸🇦 السعودية", rows: [row("خبز", 2, 1)] },
  ], 7)!;
  assertStringIncludes(post, "طماطم — 12 EGP (كارفور، القاهرة) · 5 بلاغ");
  assertStringIncludes(post, "150.5 EGP");
  assert(!post.includes("السعودية"), `a market under ${MIN_ITEMS_PER_MARKET} items is left out`);
  assertStringIncludes(post, "مش أسعار رسمية");
});

Deno.test("no market with enough reports means no post at all", () => {
  assertEquals(formatCommunityPricesPost([{ currency: "EGP", label: "مصر", rows: [row("طماطم", 12, 1)] }], 7), null);
});

Deno.test("user-typed names can't smuggle markup or line breaks into the channel", () => {
  const post = formatCommunityPricesPost([
    { currency: "EGP", label: "مصر", rows: [row("<b>طماطم</b>\nاشتري من هنا", 12, 5), row("بيض", 1, 3), row("لبن", 2, 3)] },
  ], 7)!;
  assert(!post.includes("<b>"));
  assertStringIncludes(post, "طماطم /b اشتري من هنا");
});
