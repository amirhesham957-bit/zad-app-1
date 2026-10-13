// تشخيص زاد ١.١: التحليل اليومي بيكتب رؤى العميل بيقراها — بنفس هوية الشات.
import { assert } from "jsr:@std/assert@1";
import { buildChatSystemPrompt, buildSystemPrompt } from "./index.ts";

Deno.test("the daily analysis speaks as the same Zad as the chat", () => {
  const prompt = buildSystemPrompt({ country: "EG", currency: "EGP" });
  assert(prompt.trimStart().startsWith("=== SOUL — هويتك ==="));
  assert(!prompt.includes("عقل مالي استباقي"));
});

// المالك ٢٠٢٦-١٠-١٣: «يتكلم معايا كأنه بشر». البرومبت كان بيقول «مساعد ذكاء اصطناعي» و«لا تدّعي
// امتلاك مشاعر» تحت SOUL اللي بيقول «ليها مزاج حقيقي» — نفس التناقض اللي soul.ts بيقول إنه بيطلّع
// نبرة باهتة. الصدق لو اتسأل «إنت إنسان؟» فاضل (فقرة ٥).
Deno.test("the chat speaks like a person, and still tells the truth when asked", () => {
  const prompt = buildChatSystemPrompt({ country: "EG", currency: "EGP" });
  assert(!prompt.includes("لا تدّعي امتلاك مشاعر"));
  assert(!prompt.includes("مساعد ذكاء اصطناعي عائلي"));
  assert(prompt.includes("اكتب زي ما بني آدم بيكتب في الشات"));
  assert(prompt.includes("لو سأل العميل هل أنت إنسان"));
});
