// م٤.٢ (ZAD_OR_PLAN): حارس الأرقام على أدوات المحرك. أي رقم في الرد مش جاي من نتيجة الأداة ولا من كلام العميل
// = الرد يتبدّل بنص الأداة نفسه (قالب ثابت)، مش بكلام الموديل. بيشتغل على أدوات المحرك بس، مش على كل رد.

import { checkNumbers, extractNumbers } from "../_shared/or/numberGuard.ts";

/** الأدوات اللي نتيجتها حساب مضمون، ورد الموديل عليها ما يضيفش أرقام. */
export const ENGINE_TOOLS: ReadonlySet<string> = new Set(["restock_on_budget", "plan_menu"]);

export type EngineOutput = { tool: string; content: string };

/** نتيجة رفض/خطأ مش حساب: مالهاش قالب. */
const isRefusal = (s: string) => s.startsWith("مرفوض") || s.startsWith("مقدرتش");

/** نص الأداة من غير سطور التعليمات للموديل (آخر سطر «الأرقام دي بس…» وجمل «قول للعميل»). */
export function templateFrom(outputs: readonly EngineOutput[]): string {
  return outputs.map((o) => o.content).join("\n\n")
    .split("\n")
    .filter((l) => !l.startsWith("الأرقام دي بس") && !/قول للعميل|اسأل العميل/.test(l))
    .join("\n")
    .trim();
}

export type GuardVerdict = { reply: string; replaced: boolean; unknown: number[] };

export function guardEngineReply(reply: string, userMessage: string, outputs: readonly EngineOutput[]): GuardVerdict {
  const engine = outputs.filter((o) => ENGINE_TOOLS.has(o.tool) && !isRefusal(o.content));
  if (engine.length === 0 || !reply.trim()) return { reply, replaced: false, unknown: [] };
  const allowed = [...engine.flatMap((o) => extractNumbers(o.content)), ...extractNumbers(userMessage)];
  const verdict = checkNumbers(reply, allowed);
  if (verdict.ok) return { reply, replaced: false, unknown: [] };
  return { reply: templateFrom(engine), replaced: true, unknown: verdict.unknown };
}
