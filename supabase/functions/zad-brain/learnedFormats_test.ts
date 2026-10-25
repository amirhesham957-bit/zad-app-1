// صيغ البنوك المتعلَّمة من ردود العملاء (ZAD_PLAN ٢.٣).
import { assertEquals } from "jsr:@std/assert@1";
import { type LearnedFormat, learnedCases, learnedSenders, senderKnown } from "./learnedFormats.ts";
import { decideGate } from "./notificationGate.ts";
import { judgeBankCase } from "./evals/bankEval.ts";

const row = (over: Partial<LearnedFormat>): LearnedFormat => ({
  sender: "emkanpay", market: "SA", template: "emkanpay شراء بطاقة: [بطاقة] مبلغ: {n} SAR لدى: {party} في: {n}",
  users: 3, money: 3, not_money: 0, top_kind: "expense", agreed: true, ...over,
});

Deno.test("a bank three customers agreed on becomes known; one customer's bank does not", () => {
  const learned = learnedSenders([row({}), row({ sender: "mybank", agreed: false, users: 1 })]);
  assertEquals(senderKnown("com.google.android.apps.messaging", "EmkanPay", learned), "emkanpay");
  assertEquals(senderKnown("com.google.android.apps.messaging", "MyBank", learned), null);
  // the fixed list still answers first
  assertEquals(senderKnown("com.google.android.apps.messaging", "CIB", learned), "cib");
  // a learned "not money" sender is not a bank
  assertEquals(learnedSenders([row({ sender: "promo", money: 0, not_money: 3 })]).size, 0);
});

Deno.test("a learned bank is asked about when the model is down, instead of being dropped", () => {
  const learned = learnedSenders([row({})]);
  const known = senderKnown("com.google.android.apps.messaging", "EmkanPay", learned);
  assertEquals(decideGate(null, known), "ask");
  assertEquals(decideGate(null, null), "ignore");
});

Deno.test("learned shapes join the nightly eval with numbers and a name filled in, scored on decision and direction", () => {
  const cases = learnedCases([row({}), row({ template: "x", agreed: false }), row({ sender: "stc pay", template: "استلمت {n} ريال من {party}", top_kind: "income" })]);
  assertEquals(cases.length, 2);
  assertEquals(cases[0].text, "emkanpay شراء بطاقة: [بطاقة] مبلغ: 125.50 SAR لدى: Store في: 125.50");
  assertEquals([cases[0].expect, cases[0].direction, cases[1].direction], ["money", "out", "in"]);
  assertEquals(cases[0].origin, "learned");
  // amount and merchant are not scored for a shape
  const r = judgeBankCase(cases[0], { kind: "debit", amount: 1, currency: null, counterparty: null, confidence: 0.9 }, "emkanpay");
  assertEquals([r.decisionOk, r.directionOk, r.amountOk, r.merchantOk], [true, true, null, null]);
});

Deno.test("never more than the nightly cap of learned shapes", () => {
  assertEquals(learnedCases(Array.from({ length: 100 }, () => row({}))).length, 40);
});
