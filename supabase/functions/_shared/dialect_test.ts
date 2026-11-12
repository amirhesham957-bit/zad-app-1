import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { detectDialectFromText, dialectPromptBlock, dialectReminder, regionForCity, resolveDialect, resolveRegion, voiceCountry } from "./dialect.ts";

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

// ١٠.١٦: جدة مش الرياض.
Deno.test("Saudi cities map to their region however the customer spells them", () => {
  assertEquals(regionForCity("جدة"), "SA_HIJAZ");
  assertEquals(regionForCity("جده"), "SA_HIJAZ");
  assertEquals(regionForCity("Jeddah, Saudi Arabia"), "SA_HIJAZ");
  assertEquals(regionForCity("المدينة المنورة"), "SA_HIJAZ");
  assertEquals(regionForCity("مدينة الرياض"), "SA_NAJD");
  assertEquals(regionForCity("بريدة"), "SA_NAJD");
  assertEquals(regionForCity("الأحساء"), "SA_EAST");
  assertEquals(regionForCity("الاحساء"), "SA_EAST");
  assertEquals(regionForCity("أبها"), "SA_SOUTH");
  assertEquals(regionForCity("القاهرة"), null);
  assertEquals(regionForCity(""), null);
  assertEquals(regionForCity(null), null);
});

Deno.test("a region only refines its own dialect: an Egyptian in Jeddah stays Egyptian", () => {
  assertEquals(resolveRegion("SA", { city: "جدة" }), "SA_HIJAZ");
  assertEquals(resolveRegion("EG", { city: "جدة" }), null);
  assertEquals(resolveRegion("SA", { city: "مدينة مش معروفة" }), null);
  // كلام العميل المصري بيغلب البلد والمدينة.
  const d = resolveDialect({ text: "عايز اعرف صرفت كام دلوقتي", country: "SA" });
  assertEquals(resolveRegion(d, { city: "جدة" }), null);
});

Deno.test("Jeddah gets Hijazi, Riyadh keeps Najdi, and both stay respectful", () => {
  const hijaz = dialectPromptBlock("SA", "SA_HIJAZ");
  assertStringIncludes(hijaz, "حجازي");
  assertStringIncludes(hijaz, "دحين");
  assertStringIncludes(hijaz, "ممنوع الفصحى");
  assertStringIncludes(hijaz, "من غير شتايم");
  assert(!hijaz.includes("نجدي عادي"));
  assertStringIncludes(dialectReminder("SA", "SA_HIJAZ"), "حجازي");
  assertStringIncludes(dialectPromptBlock("SA", "SA_NAJD"), "نجدي");
  // من غير منطقة = زي ما كان.
  assertEquals(dialectPromptBlock("SA", null), dialectPromptBlock("SA"));
  // منطقة مش بتاعة اللهجة دي بتتجاهل.
  assertEquals(dialectPromptBlock("EG", "SA_HIJAZ"), dialectPromptBlock("EG"));
  assertStringIncludes(dialectPromptBlock("EG"), "من غير شتايم");
});

Deno.test("the voice follows the dialect chosen in the profile, else the account's country (10.16)", () => {
  // مصري حسابه سعودي: الصوت مصري زي الكلام.
  assertEquals(voiceCountry("SA", "EG"), "EG");
  // سعودي حسابه مصري.
  assertEquals(voiceCountry("EG", "SA"), "SA");
  // إماراتي اختار «خليجي»: بلده هو، مش الإمارات بدل الكويت.
  assertEquals(voiceCountry("KW", "GULF"), "KW");
  assertEquals(voiceCountry("SA", "GULF"), "AE");
  assertEquals(voiceCountry("EG", "LEVANT"), "JO");
  assertEquals(voiceCountry("EG", "TR"), "TR");
  assertEquals(voiceCountry("EG", "EN"), null);
  // من غير اختيار، أو قيمة مش معروفة = بلد الحساب زي الأول.
  assertEquals(voiceCountry("SA", null), "SA");
  assertEquals(voiceCountry("SA", ""), "SA");
  assertEquals(voiceCountry("SA", "XX"), "SA");
  assertEquals(voiceCountry("السعودية", "eg"), "EG");
  assertEquals(voiceCountry(null, null), null);
});

Deno.test("the region chosen in the profile outranks the city, and «عام» drops it (10.16)", () => {
  // اختار حجازي ومدينته الرياض: حجازي.
  assertEquals(resolveRegion("SA", { city: "الرياض", chosen: "SA_HIJAZ" }), "SA_HIJAZ");
  // «عام» ومدينته جدة: سعودي عام.
  assertEquals(resolveRegion("SA", { city: "جدة", chosen: "GENERAL" }), null);
  assertEquals(resolveRegion("SA", { city: "جدة", chosen: "general" }), null);
  // ماختارش: المدينة زي الأول.
  assertEquals(resolveRegion("SA", { city: "جدة", chosen: null }), "SA_HIJAZ");
  assertEquals(resolveRegion("SA", { city: "جدة" }), "SA_HIJAZ");
  // قيمة مش معروفة بتتجاهل، والمدينة تكمّل.
  assertEquals(resolveRegion("SA", { city: "الدمام", chosen: "SA_MARS" }), "SA_EAST");
  // منطقة سعودية لعميل لهجته مصري: مصري.
  assertEquals(resolveRegion("EG", { city: "جدة", chosen: "SA_NAJD" }), null);
});
