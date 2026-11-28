import { assertEquals } from "jsr:@std/assert@1";
import { ownPriceReply, ownPricesFor } from "./ownPurchasePrice.ts";

const rows = [
  { created_at: "2026-11-20T10:00:00Z", shop: "بشاير للخضراوات والفاكهة", lines: [
    { name: "ملوخية", quantity: 2, unit: "كجم", price: 50, to: "pantry" },
    { name: "طماطم", quantity: 3, unit: "كجم", price: 60, to: "pantry" },
    { name: "باذنجان", quantity: 1, price: 0, to: "pantry" },
  ] },
  { created_at: "2026-11-27T10:00:00Z", shop: null, lines: [{ name: "الملوخية", quantity: 1, unit: "كجم", price: 30 }] },
];

Deno.test("«سعر الملوخية كام» returns the price recorded on the receipt lines, newest first", () => {
  const p = ownPricesFor(rows, "ملوخية");
  assertEquals(p.length, 2);
  assertEquals(p[0].unitPrice, 30);
  assertEquals(p[1].unitPrice, 25, "50 for 2 kg = 25 per kg");
  assertEquals(p[1].shop, "بشاير للخضراوات والفاكهة");
  const reply = ownPriceReply(p, "ملوخية", "EGP")!;
  assertEquals(reply.includes("25 EGP لكل كجم"), true);
});

Deno.test("a line with no price, another item, or a bank-total row yields nothing", () => {
  assertEquals(ownPricesFor(rows, "باذنجان"), []);
  assertEquals(ownPricesFor(rows, "لبن"), []);
  assertEquals(ownPricesFor([{ created_at: "2026-11-01", lines: [] }], "ملوخية"), []);
  assertEquals(ownPriceReply([], "ملوخية", "EGP"), null);
});
