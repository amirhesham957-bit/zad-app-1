import { assertEquals } from "jsr:@std/assert@1";
import {
  BANK_SOURCE_TYPE, type BankProposal, type BankRow, bankMatchOf, linkKeyboard, packUuid, parseLinkCallback,
  parseSeparateCallback, unpackUuid,
} from "./receiptBankMatch.ts";

const paid = new Date("2026-10-08T18:00:00Z");
const H = 3600_000;
const row = (id: string, amount: number, at: Date, over: Partial<BankRow> = {}): BankRow => ({
  id, amount, createdAt: at, title: "BDC", merchantName: null, sourceType: BANK_SOURCE_TYPE, isExpense: true, txnKind: "expense", ...over,
});
const prop = (id: string, amount: number, at: Date, over: Partial<BankProposal> = {}): BankProposal => ({
  id, amount, createdAt: at, title: "فيزا", merchantName: "كارفور", status: "awaiting_confirmation", txnKind: "expense", ...over,
});
const at = (ms: number) => new Date(paid.getTime() + ms);

Deno.test("exact amount matches a recorded bank row", () => {
  const m = bankMatchOf({ total: 100, spentAt: paid, rows: [row("a", 100, paid)] });
  assertEquals(m?.id, "a");
  assertEquals(m?.kind, "transaction");
});

Deno.test("within 2 percent matches, beyond does not", () => {
  const fits = (bank: number) => bankMatchOf({ total: 100, spentAt: paid, rows: [row("a", bank, paid)] }) !== null;
  assertEquals([fits(101.9), fits(98.1), fits(102.5), fits(97)], [true, true, false, false]);
});

Deno.test("a small total still allows a piaster of drift", () => {
  assertEquals(bankMatchOf({ total: 0.5, spentAt: paid, rows: [row("a", 0.51, paid)] })?.id, "a");
});

Deno.test("outside 24 hours does not match, 24h exactly does", () => {
  assertEquals(bankMatchOf({ total: 100, spentAt: paid, rows: [row("a", 100, at(25 * H))] }), null);
  assertEquals(bankMatchOf({ total: 100, spentAt: paid, rows: [row("a", 100, at(-24 * H))] })?.id, "a");
});

Deno.test("a pending proposal matches, merchant falls back to title", () => {
  const m = bankMatchOf({ total: 250, spentAt: paid, rows: [], proposals: [prop("p", 250, at(H))] });
  assertEquals([m?.kind, m?.id, m?.merchant], ["proposal", "p", "كارفور"]);
  const t = bankMatchOf({ total: 250, spentAt: paid, rows: [], proposals: [prop("p", 250, paid, { merchantName: " " })] });
  assertEquals(t?.merchant, "فيزا");
});

Deno.test("a proposal that needs classification (kind unknown) still matches", () => {
  const m = bankMatchOf({
    total: 250, spentAt: paid, rows: [], proposals: [prop("p", 250, paid, { txnKind: null, status: "needs_classification" })],
  });
  assertEquals(m?.id, "p");
});

Deno.test("transfers, cash withdrawals, income and answered proposals are ignored", () => {
  const m = bankMatchOf({
    total: 250, spentAt: paid, rows: [row("atm", 250, paid, { txnKind: "transfer" })],
    proposals: [
      prop("t", 250, paid, { txnKind: "transfer" }), prop("c", 250, paid, { txnKind: "cash_withdrawal" }),
      prop("i", 250, paid, { txnKind: "income" }), prop("r", 250, paid, { status: "rejected" }),
    ],
  });
  assertEquals(m, null);
});

Deno.test("rows not from the bank or not expenses are ignored", () => {
  const rows = [row("typed", 820, paid, { sourceType: null }), row("inc", 820, paid, { isExpense: false })];
  assertEquals(bankMatchOf({ total: 820, spentAt: paid, rows }), null);
});

Deno.test("a cash receipt matches nothing", () => {
  assertEquals(
    bankMatchOf({ total: 250, spentAt: paid, rows: [row("a", 250, paid)], proposals: [prop("p", 250, paid)], paidWith: "cash" }),
    null,
  );
});

Deno.test("closest in time wins across both sources", () => {
  const m = bankMatchOf({ total: 250, spentAt: paid, rows: [row("far", 250, at(5 * H))], proposals: [prop("near", 250, at(600_000))] });
  assertEquals(m?.id, "near");
});

Deno.test("equal gaps prefer the smaller amount difference", () => {
  const m = bankMatchOf({ total: 250, spentAt: paid, rows: [row("off", 251, at(H)), row("exact", 250, at(-H))] });
  assertEquals(m?.id, "exact");
});

Deno.test("uuid pack round-trips and callback_data stays under 64 bytes", () => {
  const a = "11111111-2222-3333-4444-555555555555";
  const b = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee";
  assertEquals(unpackUuid(packUuid(a)), a);
  const kb = linkKeyboard(a, { kind: "proposal", id: b, amount: 1, merchant: "x", at: paid });
  for (const btn of kb.flat()) assertEquals(new TextEncoder().encode(btn.callback_data).length <= 64, true);
  assertEquals(parseLinkCallback(kb[0][0].callback_data), { pendingId: a, targetKind: "proposal", targetId: b });
  assertEquals(parseSeparateCallback(kb[0][1].callback_data), a);
  assertEquals(parseLinkCallback("pk:x:pbad"), null);
});
