// برومبت analyze_receipt (الموجة ٣، بند ٧): من غير افتراض إن البون سعودي وبالريال؛ الباقي زي ما هو.
import { assert, assertStringIncludes } from "jsr:@std/assert@1";
import { RECEIPT_SYSTEM_PROMPT } from "./receiptPrompt.ts";

Deno.test("receipt prompt: no Saudi/SAR assumption — the amount as printed, never converted", () => {
  assert(!/Saudi household/i.test(RECEIPT_SYSTEM_PROMPT));
  assert(!/amounts are in SAR/i.test(RECEIPT_SYSTEM_PROMPT));
  assertStringIncludes(RECEIPT_SYSTEM_PROMPT, "mostly in Egypt");
  assertStringIncludes(RECEIPT_SYSTEM_PROMPT, "exactly as printed and never convert it to another currency");
});

Deno.test("receipt prompt: the rest of the contract is untouched", () => {
  for (const c of ["البقالة", "المطاعم", "الفواتير", "المواصلات", "الوقود", "الاشتراكات", "الأقساط", "الرعاية الصحية", "التعليم", "تحويلات", "أخرى"]) {
    assertStringIncludes(RECEIPT_SYSTEM_PROMPT, `"${c}"`);
  }
  assertStringIncludes(RECEIPT_SYSTEM_PROMPT, "never today's date as a guess");
  assertStringIncludes(RECEIPT_SYSTEM_PROMPT, "\"\" when the receipt does not say — never guess");
  assertStringIncludes(RECEIPT_SYSTEM_PROMPT, "\"paymentMethod\":\"\"");
  assertStringIncludes(RECEIPT_SYSTEM_PROMPT, "Return ONLY a JSON object");
});
