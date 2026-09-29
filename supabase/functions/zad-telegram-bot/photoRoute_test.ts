import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { captionIntent, routePhoto } from "./photoRoute.ts";

Deno.test("a restaurant, fuel or service receipt never fills the pantry", () => {
  assertEquals(routePhoto("general", null), "expense_only");
  assertEquals(routePhoto("general", ""), "expense_only");
  assertEquals(routePhoto("something_new", undefined), "expense_only");
});

Deno.test("without a caption, the reader's type decides", () => {
  assertEquals(routePhoto("grocery", null), "grocery");
  assertEquals(routePhoto("pharmacy", null), "pharmacy");
  assertEquals(routePhoto("budget_card", null), "budget_card");
});

Deno.test("the customer's caption wins over the reader", () => {
  assertEquals(routePhoto("grocery", "دي روشتة الدكتور"), "pharmacy");
  assertEquals(routePhoto("grocery", "فاتورة المطعم امبارح"), "expense_only");
  assertEquals(routePhoto("general", "مقاضي الشهر من كارفور"), "grocery");
  assertEquals(routePhoto("pharmacy", "بنزين العربية"), "expense_only");
});

Deno.test("a balance card stays a balance card whatever the caption says", () => {
  assertEquals(routePhoto("budget_card", "مقاضي"), "budget_card");
});

Deno.test("a caption that names no type says nothing", () => {
  assertEquals(captionIntent("شوف دي"), null);
  assertEquals(captionIntent("  "), null);
  assertEquals(captionIntent("فاتورة كهربا الشهر ده"), "expense_only");
  assertEquals(captionIntent("ilaç"), "pharmacy");
});
