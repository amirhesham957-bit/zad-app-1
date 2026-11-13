// دقة قراءة رسايل البنوك (١٣/١١، بلاغ المالك): التاجر لازم يبقى مكتوب في الرسالة، والعنوان هو التاجر مش اسم البنك،
// والرسالة التانية لنفس العملية بتكمّل الأولى.
import { assert, assertEquals } from "jsr:@std/assert@1";
import { merchantFromText, proposalFieldsFromVerdict, proposalTitle, writtenIn, type GateVerdict } from "./notificationGate.ts";
import { twinEnrichment } from "./shared.ts";

const corpus: Array<{ id: string; text: string; expect: string; merchant: string | null }> = JSON.parse(
  await Deno.readTextFile(new URL("./testdata/bank_corpus.json", import.meta.url)),
).cases;

const KAZYON = "تم قيد معاملة مشتريات ب 141.50 EGP من KAZYON علي بطاقة رقم  9766 في 12/11 16:11 ورصيدكم الحالي 421.60 etisalat";

function verdict(counterparty: string | null): GateVerdict {
  return { kind: "debit", confidence: 0.97, amount: 141.5, currency: "EGP", counterparty, cardLastDigits: "9766" } as GateVerdict;
}

Deno.test("a merchant the model made up is not recorded — KAZYON stays KAZYON, not «دانوب» (12/11)", () => {
  const f = proposalFieldsFromVerdict({ gate: "money", verdict: verdict("دانوب"), parsed: {}, rawText: KAZYON, packageName: "com.google.android.apps.messaging", title: "BDC", knownSender: "BDC" });
  assertEquals(f.merchantName, "KAZYON");
  assertEquals(f.amount, 141.5);
});

Deno.test("a merchant the model read from the text is kept", () => {
  const f = proposalFieldsFromVerdict({ gate: "money", verdict: verdict("kazyon"), parsed: {}, rawText: KAZYON, packageName: "x", title: "BDC", knownSender: "BDC" });
  assertEquals(f.merchantName, "kazyon");
});

Deno.test("a client merchant that is not in the text does not win either", () => {
  const f = proposalFieldsFromVerdict({ gate: "money", verdict: verdict(null), parsed: { merchant_name: "Danube" }, rawText: KAZYON, packageName: "x", title: "BDC", knownSender: "BDC" });
  assertEquals(f.merchantName, "KAZYON");
});

Deno.test("every merchant in the bank corpus is read from the text alone, and none is invented", () => {
  const wrong = corpus.filter((c) => c.expect === "money").filter((c) => {
    const got = merchantFromText(c.text);
    return c.merchant ? !got.toLowerCase().includes(c.merchant.toLowerCase()) : got !== "";
  }).map((c) => `${c.id}: ${merchantFromText(c.text)}`);
  assertEquals(wrong, []);
});

Deno.test("live wordings: InstaPay handle and D360 with direction marks", () => {
  assertEquals(merchantFromText("لقد استلمت 350.00 جنيه من ahmedheshamfab0@instapay"), "ahmedheshamfab0@instapay");
  assertEquals(merchantFromText("‏حوالة واردة: Saudi National Bank‏\n‏مبلغ: SAR 500.00‏\n‏من: ميرفت محمد ع****‏\n‏حساب: ****2899‏"), "ميرفت محمد ع");
});

Deno.test("writtenIn folds letters, digits and case", () => {
  assert(writtenIn("Kazyon", KAZYON));
  assert(writtenIn("أمازون", "شراء من امازون"));
  assert(!writtenIn("دانوب", KAZYON));
});

Deno.test("the title is the merchant, not the bank's name (Amazon was «BDC», 10/11)", () => {
  assertEquals(proposalTitle({ merchant: "AMAZON Ca", bank: "BDC", clientTitle: "", notificationTitle: "BDC", packageName: "p" }), "AMAZON Ca");
  assertEquals(proposalTitle({ merchant: "BDC", bank: "BDC", clientTitle: "", notificationTitle: "BDC", packageName: "p" }), "BDC");
  assertEquals(proposalTitle({ merchant: "a@instapay", bank: "انستاباي", clientTitle: "", notificationTitle: "انستاباي", packageName: "p" }), "انستاباي");
});

Deno.test("the second message fills in the merchant when the first only had the bank", () => {
  assertEquals(twinEnrichment({ status: "awaiting_confirmation", merchant_name: "BDC", bank_name: "BDC" }, { merchant: "KAZYON", bank: "InstaPay" }),
    { merchant_name: "KAZYON", title: "KAZYON" });
  assertEquals(twinEnrichment({ status: "awaiting_confirmation", merchant_name: "KAZYON", bank_name: "BDC" }, { merchant: "Other", bank: "X" }), null);
  assertEquals(twinEnrichment({ status: "posted", merchant_name: "BDC", bank_name: "BDC" }, { merchant: "KAZYON", bank: "X" }), null);
  assertEquals(twinEnrichment({ status: "awaiting_confirmation", merchant_name: null, bank_name: "BDC" }, { merchant: "x@instapay", bank: "InstaPay" }), null);
});
