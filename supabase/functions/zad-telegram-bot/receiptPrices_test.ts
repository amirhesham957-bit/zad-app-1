import { assertEquals } from "jsr:@std/assert@1";
import { RECEIPT_REPORTS_MAX, receiptPriceReports } from "./receiptPrices.ts";

Deno.test("receipt lines become reports at their unit price, as the app sends them", () => {
  assertEquals(receiptPriceReports("  كارفور   المعادي ", [
    { name: "لبن", price: 12.5, quantity: 2, category: "ألبان" },
    { name: " عيش  بلدي ", price: 25, quantity: 1 },
  ]), [
    { item: "لبن", unitPrice: 6.25, category: "ألبان" },
    { item: "عيش بلدي", unitPrice: 25, category: null },
  ]);
});

Deno.test("no shop, no report; a line the server would refuse is left out", () => {
  assertEquals(receiptPriceReports("", [{ name: "لبن", price: 10, quantity: 1 }]), []);
  assertEquals(receiptPriceReports(null, [{ name: "لبن", price: 10, quantity: 1 }]), []);
  assertEquals(receiptPriceReports("بنده", [
    { name: "x", price: 10, quantity: 1 },
    { name: "زيت", price: 0, quantity: 1 },
    { name: "سكر", price: Number.NaN, quantity: 1 },
    { name: "رز", price: 30, quantity: 0 },
  ]), [{ item: "رز", unitPrice: 30, category: null }]);
});

Deno.test("a long receipt reports twenty lines at most", () => {
  const lines = Array.from({ length: 30 }, (_, i) => ({ name: `صنف ${i}`, price: 5, quantity: 1 }));
  assertEquals(receiptPriceReports("بنده", lines).length, RECEIPT_REPORTS_MAX);
});
