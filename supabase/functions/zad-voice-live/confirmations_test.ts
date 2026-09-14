import { assert, assertEquals } from "jsr:@std/assert@1";
import { PENDING_TTL_MS, PendingMoneyActions, sameMoneyAction } from "./confirmations.ts";

Deno.test("'yes' repeats the call with a reworded title and an extra field — it still executes, with what the customer heard", () => {
  const p = new PendingMoneyActions(() => 1000);
  assertEquals(p.onToolCall("log_transaction", { amount: 50, txn_kind: "expense", title: "قهوة" }).action, "ask");
  const second = p.onToolCall("log_transaction", { title: "قهوة الصبح", category: "مشروبات", txn_kind: "expense", amount: 50 });
  assertEquals(second, { action: "execute", args: { amount: 50, txn_kind: "expense", title: "قهوة" } });
});

Deno.test("a different amount or kind is a new question, not a confirmation", () => {
  const p = new PendingMoneyActions(() => 0);
  p.onToolCall("log_transaction", { amount: 50, txn_kind: "expense", title: "x" });
  assertEquals(p.onToolCall("log_transaction", { amount: 70, txn_kind: "expense", title: "x" }).action, "ask");
  assertEquals(p.onToolCall("log_transaction", { amount: 70, txn_kind: "income", title: "x" }).action, "ask");
  assert(!sameMoneyAction("delete_transaction", { transaction_id: "" }, { transaction_id: "" }));
});

Deno.test("the explicit confirm tool executes the pending action once; cancel and expiry drop it", () => {
  let now = 0;
  const p = new PendingMoneyActions(() => now);
  p.onToolCall("set_monthly_limit", { monthly_limit: 9000 });
  assertEquals(p.confirm()?.args, { monthly_limit: 9000 });
  assertEquals(p.confirm(), null);
  p.onToolCall("set_monthly_limit", { monthly_limit: 9000 });
  assert(p.cancel());
  p.onToolCall("set_monthly_limit", { monthly_limit: 9000 });
  now = PENDING_TTL_MS + 1;
  assertEquals(p.confirm(), null);
});
