// مجموعة اختبار رسايل البنوك (ZAD_DREAM_PLAN.md ح١) على البوابة. الموديل نفسه مابيتقاسش هنا —
// اللي بيتقاس هو كل حاجة حوالين الموديل: البنك معروف؟ ولو الموديل وقع، الرسالة بتتسأل ولا بتترمي؟
// ولو الموديل قال الصح، القرار بيطلع صح؟
import { assertEquals } from "jsr:@std/assert@1";
import { decideGate, knownFinancialSender, looksLikeMoneyMoved, ruleGate, type GateKind } from "./notificationGate.ts";
import { judgeBankCase } from "./evals/bankEval.ts";

interface Case {
  id: string;
  package: string;
  title: string;
  text: string;
  expect: "money" | "reminder" | "ignore";
  knownSender: boolean;
}

const corpus: Case[] = JSON.parse(
  await Deno.readTextFile(new URL("./testdata/bank_corpus.json", import.meta.url)),
).cases;

Deno.test("every bank and wallet in the corpus is recognised from its sender name or package", () => {
  const wrong = corpus
    .filter((c) => (knownFinancialSender(c.package, c.title) !== null) !== c.knownSender)
    .map((c) => `${c.id} (${c.title})`);
  assertEquals(wrong, []);
});

Deno.test("model down: no message where money moved is thrown away", () => {
  const dropped = corpus
    .filter((c) => c.expect === "money")
    .filter((c) => decideGate(null, knownFinancialSender(c.package, c.title), looksLikeMoneyMoved(c.text)) === "ignore")
    .map((c) => c.id);
  assertEquals(dropped, []);
});

Deno.test("a correct classification gives the expected decision, even at the bar's edge", () => {
  const kindFor: Record<Case["expect"], GateKind> = { money: "debit", reminder: "installment_due", ignore: "promo_or_ad" };
  const wrong = corpus.filter((c) => {
    const known = knownFinancialSender(c.package, c.title);
    // أقل ثقة لسه بتعدّي: ٠.٥ لبنك معروف، ٠.٧ لمجهول.
    const confidence = c.expect === "money" ? (known ? 0.5 : 0.7) : 0.5;
    const d = decideGate({ kind: kindFor[c.expect], amount: null, currency: null, counterparty: null, confidence }, known);
    return d !== c.expect;
  }).map((c) => c.id);
  assertEquals(wrong, []);
});

Deno.test("the fixed rule never removes a message where money moved", () => {
  assertEquals(corpus.filter((c) => c.expect === "money" && ruleGate(c.text) !== null).map((c) => c.id), []);
});

Deno.test("the eval runs the same ladder as the live gate: a declined purchase is ignored before the model", () => {
  const declined = corpus.find((c) => c.id === "eg-declined")!;
  assertEquals(ruleGate(declined.text), "failed_or_pending_transaction");
  // the model's answer does not matter once the rule has decided
  const debit = { kind: "debit" as const, amount: 780, currency: "EGP", counterparty: null, confidence: 0.9 };
  // deno-lint-ignore no-explicit-any
  assertEquals(judgeBankCase(declined as any, debit, knownFinancialSender(declined.package, declined.title)).decisionOk, true);
});
