// برومبتات رؤية المخزون والدوا ببلد العميل بدل «Saudi» ثابتة (visionPrompts.ts، طلب المالك ٢٠٢٦-١٠-١١).
import { assert, assertStringIncludes } from "jsr:@std/assert@1";
import { inventoryPrompt, marketSentence, medicinePrompt } from "./visionPrompts.ts";

Deno.test("vision: the customer's own country, or an Arab country when unknown — never a fixed Saudi", () => {
  assertStringIncludes(marketSentence("EG"), "lives in Egypt");
  assertStringIncludes(marketSentence("sa"), "lives in Saudi Arabia");
  assertStringIncludes(marketSentence("AE"), "the United Arab Emirates");
  for (const unknown of [null, undefined, "", "XX", "مصر"]) assertStringIncludes(marketSentence(unknown), "an Arab country");
  for (const p of [inventoryPrompt("EG"), medicinePrompt("EG"), inventoryPrompt(null), medicinePrompt(null)]) {
    assert(!/Saudi household|Saudi family/.test(p));
  }
  assertStringIncludes(medicinePrompt("EG"), "lives in Egypt");
});

Deno.test("vision: the rest of both prompts is the contract it was", () => {
  const inv = inventoryPrompt("EG");
  assertStringIncludes(inv, "never invent a product just to avoid an empty list");
  assertStringIncludes(inv, "البقالة، الخضار، الفواكه، اللحوم، الألبان، المشروبات، العناية، أخرى");
  assertStringIncludes(inv, "{\"items\":[{\"name\":\"\",\"quantity\":1.0,\"unit\":\"قطعة\",\"category\":\"الألبان\"}]}");
  const med = medicinePrompt("SA");
  assertStringIncludes(med, "`expiry_date`");
  assertStringIncludes(med, "'عام'، 'مسكن'، 'مضاد حيوي'، 'فيتامين'، 'مزمن'");
  assertStringIncludes(med, "\"suggested_times\":[\"08:00\"]");
});
