// مجموعة اختبار رسايل البنوك (ZAD_DREAM_PLAN.md ح١) على البوابة. الموديل نفسه مابيتقاسش هنا —
// اللي بيتقاس هو كل حاجة حوالين الموديل: البنك معروف؟ ولو الموديل وقع، الرسالة بتتسأل ولا بتترمي؟
// ولو الموديل قال الصح، القرار بيطلع صح؟
import { assertEquals } from "jsr:@std/assert@1";
import { decideGate, knownFinancialSender, looksLikeMoneyMoved, ruleGate, type GateKind } from "./notificationGate.ts";
import { judgeBankCase } from "./evals/bankEval.ts";
import { gatePrompt } from "./notificationGate.ts";

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

Deno.test("what the model reads is masked, but every amount it must find is still there (ZAD_PLAN 8.2)", () => {
  const lost = corpus.filter((c) => {
    const amount = (c as unknown as { amount: number | null }).amount;
    if (amount == null) return false;
    const { user } = gatePrompt({ packageName: c.package, title: c.title, text: c.text, knownSender: null });
    const nums = [...user.replace(/[٠-٩]/g, (d) => String(d.charCodeAt(0) - 0x0660)).replace(/٬/g, ",").matchAll(/[0-9]+(?:,[0-9]{3})*(?:\.[0-9]+)?/g)]
      .map((m) => Number(m[0].replace(/,/g, "")));
    return !nums.some((n) => Math.abs(n - amount) < 0.005);
  }).map((c) => c.id);
  assertEquals(lost, []);
});

// نفس الرسالة بالطرق التانية اللي البنوك والموبايلات بتكتبها بيها: أرقام عربي، العملة بالشكل التاني، من غير فاصلة
// الآلاف. بتتولّد هنا ومابتتخزنش في المجموعة، فالمجموعة فيها بس رسايل اتشافت أو شكلها معروف.
function variants(text: string): Record<string, string> {
  const out: Record<string, string> = {
    "arabic digits": text.replace(/[0-9]/g, (d) => String.fromCharCode(0x0660 + Number(d))),
    "no thousands separator": text.replace(/(\d),(\d{3})/g, "$1$2"),
  };
  const swaps: [string, string][] = [["SAR", "ر.س"], ["ر.س", "SAR"], ["ريال", "ر.س"], ["EGP", "ج.م"], ["ج.م", "EGP"], ["جنيه", "ج.م"]];
  const swap = swaps.find(([from]) => text.includes(from));
  if (swap) out[`${swap[0]} → ${swap[1]}`] = text.replaceAll(swap[0], swap[1]);
  return Object.fromEntries(Object.entries(out).filter(([, v]) => v !== text));
}

Deno.test("the other ways the same message is written: never dropped, and the model still sees the amount", () => {
  const wrong: string[] = [];
  let checked = 0;
  for (const c of corpus.filter((c) => c.expect === "money")) {
    const amount = (c as unknown as { amount: number | null }).amount;
    for (const [how, text] of Object.entries(variants(c.text))) {
      checked++;
      const known = knownFinancialSender(c.package, c.title);
      if (ruleGate(text) !== null) wrong.push(`${c.id} (${how}): the fixed rule removed it`);
      if (decideGate(null, known, looksLikeMoneyMoved(text)) === "ignore") wrong.push(`${c.id} (${how}): dropped with the model down`);
      if (amount != null) {
        const { user } = gatePrompt({ packageName: c.package, title: c.title, text, knownSender: null });
        const nums = [...user.replace(/[٠-٩]/g, (d) => String(d.charCodeAt(0) - 0x0660)).replace(/٬/g, ",").matchAll(/[0-9]+(?:,[0-9]{3})*(?:\.[0-9]+)?/g)]
          .map((m) => Number(m[0].replace(/,/g, "")));
        if (!nums.some((n) => Math.abs(n - amount) < 0.005)) wrong.push(`${c.id} (${how}): the amount is masked away`);
      }
    }
  }
  assertEquals(checked >= corpus.filter((c) => c.expect === "money").length, true);
  assertEquals(wrong, []);
});
