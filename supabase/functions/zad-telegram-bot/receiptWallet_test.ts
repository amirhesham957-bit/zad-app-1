// صورة البون في تليجرام بتتسجل بطريقة الدفع (الموجة ٣، بند ٧؛ 20261010200000).
import { assert, assertEquals } from "jsr:@std/assert@1";
import { confirmSpendMessage, receiptWallet } from "./context.ts";

Deno.test("receipt wallet: what the paper said, a mobile wallet as a bank payment, nothing when it said nothing", () => {
  assertEquals(receiptWallet("cash"), "cash");
  assertEquals(receiptWallet(" CARD "), "card");
  // نفس التطبيق (2b257ef5): فودافون كاش/InstaPay = حساب بنك.
  assertEquals(receiptWallet("wallet"), "bank");
  for (const none of ["", null, undefined, "visa", 3]) assertEquals(receiptWallet(none), null, String(none));
});

Deno.test("confirm message: says how it was paid when the receipt said, and nothing otherwise", () => {
  const intent = { is_spend: true, kind: "expense" as const, amount: 120, title: "كارفور", category: "بقالة", confidence: 0.75 };
  assert(confirmSpendMessage(intent, "EGP", "cash").includes("اتدفعت: كاش (من البون)"));
  assert(confirmSpendMessage(intent, "EGP", "bank").includes("اتدفعت: محفظة/تحويل بنكي"));
  assert(!confirmSpendMessage(intent, "EGP", null).includes("اتدفعت"));
  assert(!confirmSpendMessage(intent, "EGP").includes("اتدفعت"));
});
