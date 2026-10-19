// مجموعة اختبار البنك على الموديل (ZAD_PLAN ٣.٧): الحكم من غير موديل، عشان الرقم الليلي يبقى
// مقاس صح — والملف نفسه فيه كل اللي التقييم محتاجه.
import { assert, assertEquals } from "jsr:@std/assert@1";
import type { GateVerdict } from "../notificationGate.ts";
import { type BankCase, directionOf, failureOf, judgeBankCase, sameMerchant, summarize } from "./bankEval.ts";

const corpus: BankCase[] = JSON.parse(
  await Deno.readTextFile(new URL("../testdata/bank_corpus.json", import.meta.url)),
).cases;

const kazyon = corpus.find((c) => c.id === "eg-bdc-purchase")!;
const salary = corpus.find((c) => c.id === "eg-banquemisr-salary")!;
const otp = corpus.find((c) => c.id === "eg-otp")!;

const v = (over: Partial<GateVerdict>): GateVerdict => ({
  kind: "debit", amount: null, currency: null, counterparty: null, confidence: 0.9, ...over,
});

Deno.test("every money message says which way it went; merchants are real strings", () => {
  const missing = corpus.filter((c) => c.expect === "money" && c.direction !== "out" && c.direction !== "in").map((c) => c.id);
  assertEquals(missing, []);
  for (const c of corpus) {
    assert(c.merchant === null || (typeof c.merchant === "string" && c.merchant.trim().length > 0), c.id);
    assert(c.origin === "real" || c.origin === "shape", c.id);
  }
  assertEquals(new Set(corpus.map((c) => c.id)).size, corpus.length, "ids are unique");
});

Deno.test("a right reading passes everything", () => {
  const r = judgeBankCase(kazyon, v({ amount: 245.5, counterparty: "Kazyon Market" }), "BDC");
  assertEquals([r.decisionOk, r.amountOk, r.directionOk, r.merchantOk], [true, true, true, true]);
  assertEquals(failureOf(r, kazyon), null);
});

Deno.test("each field fails on its own", () => {
  const amount = judgeBankCase(kazyon, v({ amount: 24.55, counterparty: "KAZYON" }), "BDC");
  assertEquals(amount.amountOk, false);
  assertEquals(failureOf(amount, kazyon), "amount wrong, want 245.5");

  const direction = judgeBankCase(salary, v({ kind: "debit", amount: 12500 }), "BanqueMisr");
  assertEquals(direction.directionOk, false);
  assertEquals(direction.merchantOk, null, "no merchant to measure on a salary");

  const merchant = judgeBankCase(kazyon, v({ amount: 245.5, counterparty: "BDC" }), "BDC");
  assertEquals(merchant.merchantOk, false);
});

Deno.test("a transfer to someone else read as an own-account transfer is the wrong direction", () => {
  assertEquals(directionOf("transfer"), null);
  assertEquals(directionOf("refund"), "in");
  assertEquals(directionOf("promo_or_ad"), null);
});

Deno.test("model down: a known bank's money is asked about, not hit and not dropped", () => {
  const r = judgeBankCase(kazyon, null, "BDC");
  assertEquals(r.decision, "ask");
  assertEquals(r.decisionOk, false);
  const s = summarize([kazyon], [r]);
  assertEquals(s.moneyDropped, []);
});

Deno.test("noise: only the decision is measured", () => {
  const r = judgeBankCase(otp, v({ kind: "otp_or_security" }), "CIB");
  assertEquals(r.decision, "ignore");
  assertEquals([r.decisionOk, r.amountOk, r.directionOk, r.merchantOk], [true, null, null, null]);
});

Deno.test("merchant matching ignores case, spaces and letter forms, not the name", () => {
  assert(sameMerchant("carrefour maadi", "CARREFOUR MAADI"));
  assert(sameMerchant("STARBUCKS COFFEE", "STARBUCKS"));
  assert(sameMerchant("أحمد", "احمد"));
  assert(!sameMerchant("Spinneys", "CARREFOUR MAADI"));
  assert(!sameMerchant(null, "NOON"));
  assert(!sameMerchant("  ", "NOON"));
});

Deno.test("the bar: 95% amount and direction, 90% merchant, and no money dropped", () => {
  const money = corpus.filter((c) => c.expect === "money");
  const perfect = money.map((c) =>
    judgeBankCase(c, v({ kind: c.direction === "in" ? "credit" : "debit", amount: c.amount, counterparty: c.merchant }), "X")
  );
  const s = summarize(money, perfect);
  assertEquals(s.amount.rate, 1);
  assert(s.meetsBar);

  // One wrong direction in 14 is 92.9% — under 95%.
  const oneWrong = perfect.map((r, i) => (i === 0 ? { ...r, directionOk: false } : r));
  assertEquals(summarize(money, oneWrong).meetsBar, false);

  // A dropped money message fails the night whatever the rates say.
  const dropped = perfect.map((r, i) => (i === 0 ? { ...r, decision: "ignore" as const } : r));
  const d = summarize(money, dropped);
  assertEquals(d.moneyDropped, [money[0].id]);
  assertEquals(d.meetsBar, false);
});
