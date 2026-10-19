// التنقيح: المبلغ والتاريخ والتاجر بيفضلوا، والكارت والحساب والموبايل والرصيد بيتغيروا.
import { assert, assertEquals } from "jsr:@std/assert@1";
import { redactBankMessage } from "./redactBankMessage.ts";

Deno.test("card, balance and account numbers go; the amount, the date and the merchant stay", () => {
  const r = redactBankMessage(
    "تم قيد معاملة مشتريات ب 245.50 EGP من KAZYON علي بطاقة رقم 9087 في 05/10/2026 الساعة 14:22 الرصيد المتاح 18,342.10",
    245.5,
  );
  assert(r.text.includes("245.50 EGP"));
  assert(r.text.includes("KAZYON"));
  assert(r.text.includes("05/10/2026"), r.text);
  assert(r.text.includes("14:22"));
  assert(!r.text.includes("9087"), r.text);
  assert(!r.text.includes("18,342.10"), r.text);
  assert(r.text.includes("الرصيد المتاح"));
  assertEquals(r.reviewNames, ["KAZYON"]);
});

Deno.test("a phone number and an InstaPay address are masked; an amount of four digits is not", () => {
  const r = redactBankMessage("تم استلام مبلغ 2000 جنيه من رقم 01098765432 إلى sara.m@instapay", 2000);
  assert(r.text.includes("2000 جنيه"));
  assert(!r.text.includes("01098765432"), r.text);
  assert(r.text.includes("01000000000"), r.text);
  assert(r.text.includes("user@instapay"), r.text);
});

Deno.test("Arabic digits are read as numbers", () => {
  const r = redactBankMessage("خصم ١٥٠ جنيه من حساب ٤٤١٠٢٢ رصيدك ٣٢٠٠", 150);
  assert(r.text.includes("١٥٠"));
  assert(!r.text.includes("٤٤١٠٢٢"), r.text);
  assert(!r.text.includes("٣٢٠٠"), r.text);
});

Deno.test("names after من/إلى are flagged for a look, not guessed", () => {
  const r = redactBankMessage("حوالة صادرة\nإلى: محمد علي\nمبلغ: 1,500.00 ر.س", 1500);
  assertEquals(r.reviewNames, ["محمد علي"]);
  assert(r.text.includes("1,500.00"));
});
