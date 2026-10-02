// تشخيص زاد ١.١: التحليل اليومي بيكتب رؤى العميل بيقراها — بنفس هوية الشات.
import { assert } from "jsr:@std/assert@1";
import { buildSystemPrompt } from "./index.ts";

Deno.test("the daily analysis speaks as the same Zad as the chat", () => {
  const prompt = buildSystemPrompt({ country: "EG", currency: "EGP" });
  assert(prompt.trimStart().startsWith("=== SOUL — هويتك ==="));
  assert(!prompt.includes("عقل مالي استباقي"));
});
