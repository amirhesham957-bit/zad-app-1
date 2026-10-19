// صورة الفاتورة كشرا واحد (٣.٦ ج): الأزرار التلاتة ومدخل zad_record_purchase_service.
import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  parsePurchaseCallback, purchaseDoneLine, purchaseFromPending, purchaseKeyboard,
  purchaseLinesFromPhoto, purchasePreview, type PendingPurchase,
} from "./purchasePhoto.ts";

const ID = "11111111-1111-1111-1111-111111111111";

const row = (over: Partial<PendingPurchase> = {}): PendingPurchase => ({
  id: ID, amount: 250.5, title: "كارفور", category: "بقالة", wallet: "cash",
  merchant_name: "كارفور", source_type: "receipt",
  purchase_lines: [{ name: "لبن", quantity: 2, to: "pantry", price: 60 }],
  ...over,
});

Deno.test("photo lines: blank names out, real amounts (half a kilo is 0.5), price and unit when read", () => {
  const lines = purchaseLinesFromPhoto([
    { name: "  لبن   جهينة ", quantity: 2.4, unit: "علبة", category: "ألبان", price: 60 },
    { name: "  ", quantity: 3 },
    { name: "عيش", quantity: 0, price: 0 },
  ], "pantry");
  assertEquals(lines, [
    { name: "لبن جهينة", quantity: 2.4, unit: "علبة", category: "ألبان", price: 60, to: "pantry" },
    { name: "عيش", quantity: 1, to: "pantry" },
  ]);
});

Deno.test("«سجّل الكل»: the money and the lines, under the pending row's id", () => {
  const p = purchaseFromPending(row(), "all")!;
  assertEquals(p.id, ID, "a double tap replays, it does not write twice");
  assertEquals(p.amount, 250.5);
  assertEquals(p.wallet, "cash");
  assertEquals(p.merchant_name, "كارفور");
  assertEquals((p.lines as unknown[]).length, 1);
});

Deno.test("«المخزن بس»: the lines with no amount, so no expense", () => {
  const p = purchaseFromPending(row(), "lines")!;
  assert(!("amount" in p), "amount absent = lines-only on the server");
  assert(!("wallet" in p));
  assertEquals((p.lines as unknown[]).length, 1);
});

Deno.test("a mode with nothing to record is refused before the server", () => {
  assertEquals(purchaseFromPending(row({ amount: null }), "all"), null);
  assertEquals(purchaseFromPending(row({ purchase_lines: [] }), "lines"), null);
  assertEquals(purchaseFromPending(row({ purchase_lines: null }), "lines"), null);
});

Deno.test("keyboard: the owner's three buttons, and only the ones that can do something", () => {
  const all = purchaseKeyboard(ID, { hasAmount: true, hasLines: true })[0];
  assertEquals(all.map((b) => b.callback_data), [`pa:${ID}`, `pl:${ID}`, `c:${ID}`]);
  assertEquals(all.map((b) => b.text), ["✅ سجّل الكل", "📦 المخزن بس", "✖️ لأ"]);
  const linesOnly = purchaseKeyboard(ID, { hasAmount: false, hasLines: true })[0];
  assertEquals(linesOnly.map((b) => b.callback_data), [`pl:${ID}`, `c:${ID}`]);
  for (const b of all) assert(new TextEncoder().encode(b.callback_data!).length <= 64);
});

Deno.test("callback: pa/pl with a uuid, nothing else", () => {
  assertEquals(parsePurchaseCallback(`pa:${ID}`), { mode: "all", pendingId: ID });
  assertEquals(parsePurchaseCallback(`pl:${ID}`), { mode: "lines", pendingId: ID });
  assertEquals(parsePurchaseCallback(`x:${ID}`), null);
  assertEquals(parsePurchaseCallback("pa:nope"), null);
  assertEquals(parsePurchaseCallback(`pa:${ID}:x`), null);
});

Deno.test("preview and done line say what goes where", () => {
  assertEquals(
    purchasePreview([{ name: "لبن", quantity: 1, to: "pantry" }, { name: "بنادول", quantity: 1, to: "pharmacy" }]),
    "🧾 قريت 1 صنف للمخزن و1 دوا للصيدلية — مش هضيفهم غير لما تختار.",
  );
  assertEquals(purchasePreview([]), "");
  assertEquals(
    purchaseDoneLine({ pantry: { added: 1, topped_up: 2, ticked: 1 }, pharmacy: { restocked: 0 } }),
    "1 جديد في المخزن، 2 زادت كميته، 1 اتشال من المشتريات",
  );
});
