// «اشتريت لبن وعيش بـ٤٠» شرا واحد (٣.٦ د): سطور الموديل، ورد الدالة.
import { assert, assertEquals } from "jsr:@std/assert@1";
import { purchaseToolReply, toolPurchaseLines } from "./purchaseDoor.ts";
import { validateLogTransaction } from "./validators.ts";

Deno.test("tool lines: names kept, real amounts (٣.٨), medicine to the pharmacy, everything else the pantry", () => {
  assertEquals(toolPurchaseLines([
    { name: " لبن ", quantity: 2.2, unit: "علبة" },
    { name: "بنادول", to: "pharmacy" },
    { name: "فيتامين", quantity: 2.4, to: "pharmacy" },
    { name: "", quantity: 3 },
    { name: "عيش", to: "garage", price: 10 },
    "junk",
  ]), [
    { name: "لبن", quantity: 2.2, unit: "علبة", to: "pantry" },
    { name: "بنادول", quantity: 1, to: "pharmacy" },
    { name: "فيتامين", quantity: 2, to: "pharmacy" },
    { name: "عيش", quantity: 1, price: 10, to: "pantry" },
  ]);
  assertEquals(toolPurchaseLines(undefined), []);
  assertEquals(toolPurchaseLines(Array.from({ length: 50 }, (_, i) => ({ name: `x${i}` }))).length, 30);
});

Deno.test("reply: recorded says what went where", () => {
  const r = purchaseToolReply({
    ok: true, status: "recorded", transaction_id: "t1",
    pantry: { added: 1, topped_up: 1, ticked: 1 }, pharmacy: { restocked: 0 }, skipped: [],
  }, { title: "بقالة", amount: 40 });
  assert(r.ok);
  assertEquals(r.transactionId, "t1");
  assertEquals(r.text, "اتسجلت المعاملة: بقالة — 40 (2 صنف في المخزن، 1 اتشال من المشتريات)");
});

Deno.test("reply: a suspected duplicate asks, like the money-only path", () => {
  const now = Date.parse("2026-10-19T10:00:00Z");
  const r = purchaseToolReply({
    ok: false, status: "duplicate_suspected", twin: { id: "x", title: "كارفور", created_at: "2026-10-19T09:57:00Z" },
  }, { title: "بقالة", amount: 40 }, now);
  assert(!r.ok);
  assert(r.text.startsWith("مرفوض: فيه مصروف بنفس المبلغ (40) اتسجّل من 3 دقيقة"), r.text);
  assert(r.text.includes("allow_duplicate=true"));
});

Deno.test("reply: a refusal says nothing was written", () => {
  const r = purchaseToolReply({ ok: false, reason: "invalid_input" }, { title: "x", amount: 1 });
  assert(!r.ok);
  assert(r.text.includes("ولا حاجة اتكتبت"));
  assert(!purchaseToolReply(null, { title: "x", amount: 1 }).ok);
});

Deno.test("validator: lines are for an expense, and not too many", async () => {
  const ctx = { counts: {} } as Parameters<typeof validateLogTransaction>[2];
  const base = { amount: 40, txn_kind: "expense", title: "بقالة" };
  const ok = async (input: Record<string, unknown>) => (await validateLogTransaction(input, {} as never, ctx)).ok;
  assert(await ok({ ...base, lines: [{ name: "لبن" }] }));
  assert(!(await ok({ ...base, lines: "لبن" })));
  assert(!(await ok({ ...base, lines: Array.from({ length: 31 }, () => ({ name: "x" })) })));
  assert(!(await ok({ ...base, txn_kind: "income", lines: [{ name: "لبن" }] })));
});
