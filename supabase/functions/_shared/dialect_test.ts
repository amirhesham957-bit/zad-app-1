import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { detectDialectFromText, dialectPromptBlock, dialectReminder, resolveDialect } from "./dialect.ts";

Deno.test("clear dialect in the customer's own words is detected; one shared word is not enough", () => {
  assertEquals(detectDialectFromText("عايز اعرف صرفت كام دلوقتي"), "EG");
  assertEquals(detectDialectFromText("ابغى اعرف وش صرفت الحين"), "SA");
  assertEquals(detectDialectFromText("شو صرفت هلق؟ بدي اعرف"), "LEVANT");
  assertEquals(detectDialectFromText("بغيت نعرف شحال صرفت دابا"), "MA");
  assertEquals(detectDialectFromText("شي"), null);
  assertEquals(detectDialectFromText("How much did I spend on groceries this week?"), "EN");
});

Deno.test("priority: the customer's own choice, then how they write, then market, then currency, then Egyptian", () => {
  assertEquals(resolveDialect({ preferred: "EG", text: "ابغى وش الحين", country: "SA" }), "EG");
  assertEquals(resolveDialect({ text: "ابغى اعرف وش صرفت الحين", country: "EG" }), "SA");
  assertEquals(resolveDialect({ country: "KW" }), "GULF");
  assertEquals(resolveDialect({ country: "مصر" }), "EG");
  assertEquals(resolveDialect({ currency: "SAR" }), "SA");
  assertEquals(resolveDialect({}), "EG");
});

Deno.test("the dialect block is written in the dialect, bans formal Arabic and gives real examples", () => {
  const eg = dialectPromptBlock("EG");
  assertStringIncludes(eg, "اتكلم مصري");
  assertStringIncludes(eg, "ممنوع الفصحى");
  assertStringIncludes(eg, "هظبطهالك");
  assert(!dialectPromptBlock("SA").includes("اتكلم مصري"));
  assertStringIncludes(dialectPromptBlock("SA"), "أبشر");
  assertStringIncludes(dialectReminder("SA"), "سعودي");
});
