import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { receiptPurchaseDate } from "./receiptDate.ts";

const now = new Date("2026-09-28T12:00:00Z");

Deno.test("a printed date inside the last year is kept", () => {
  assertEquals(receiptPurchaseDate("2026-08-12", now), "2026-08-12");
  assertEquals(receiptPurchaseDate(" 2026-09-28 ", now), "2026-09-28");
});

Deno.test("tomorrow in UTC is still today somewhere the app serves", () => {
  assertEquals(receiptPurchaseDate("2026-09-29", now), "2026-09-29");
});

Deno.test("anything a misread could produce is refused", () => {
  for (const bad of ["", "12/08/2026", "2026-8-12", "2026-02-30", "2026-10-15", "2024-01-01", "null", 20260812, null, undefined]) {
    assertEquals(receiptPurchaseDate(bad, now), null, String(bad));
  }
});

Deno.test("the payment method is one of three or nothing", async () => {
  const { receiptPaymentMethod } = await import("./receiptDate.ts");
  assertEquals(receiptPaymentMethod("card"), "card");
  assertEquals(receiptPaymentMethod(" Cash "), "cash");
  assertEquals(receiptPaymentMethod("wallet"), "wallet");
  for (const bad of ["visa", "فيزا", "", null, 3, undefined, "unknown"]) {
    assertEquals(receiptPaymentMethod(bad), "", String(bad));
  }
});
