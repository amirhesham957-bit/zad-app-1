// م٤.٣ج — أدوات بالطلب (ZAD_ONDEMAND_PROMPT=1 بس، مقفول افتراضياً): النداء بيبعت كامل الأدوات اللي النية بتشاور
// عليها + الأساسيات + أداة واحدة صغيرة `load_tools` فيها أسماء الباقي. الموديل لو احتاج أداة تانية بينادي
// load_tools بالأسماء، واللفة اللي بعدها بتشوفها كاملة (والقواعد كلها). الأسماء كلها المتاحة للتخصص فعلاً بتفضل
// قابلة للطلب، فمفيش أداة بتضيع، بس بتتكلف نداء زيادة.
import type { ToolDef } from "./callModel.ts";

export const LOAD_TOOLS_NAME = "load_tools";
/** كاملين في أول نداء حتى من غير نية: الفلوس (مفيش مجازفة) والقراية العامة اللي أكتر أداة بتتنادى. */
export const LAZY_BASE_FULL_TOOLS: readonly string[] = ["log_transaction", "read_house"];

export function loadToolsDef(deferred: readonly string[]): ToolDef {
  return {
    name: LOAD_TOOLS_NAME,
    description: "حمّل أدوات تانية من الأسماء دي لو الطلب محتاج أداة مش معروضة. بعد التحميل نادِها في اللفة الجاية.",
    input_schema: {
      type: "object",
      properties: { names: { type: "array", items: { type: "string", enum: [...deferred] } } },
      required: ["names"],
    },
  };
}

/** أسماء الأدوات اللي الموديل طلبها بـload_tools في اللفات اللي فاتت. */
export function requestedTools(history: ReadonlyArray<{ role: string; toolCalls?: Array<{ name: string; input?: unknown }> }>): string[] {
  const out: string[] = [];
  for (const t of history) {
    for (const c of t.toolCalls ?? []) {
      if (c.name !== LOAD_TOOLS_NAME) continue;
      const names = (c.input as { names?: unknown } | undefined)?.names;
      if (Array.isArray(names)) for (const n of names) if (typeof n === "string") out.push(n);
    }
  }
  return out;
}

/** الأدوات اللي كاملة في النداء: الأساسيات + اللي عليها نية + اللي اتنادت + اللي اتطلبت (+ الملف لو فيه حقيقة). */
export function lazyFullSet(hinted: readonly string[], called: readonly string[], requested: readonly string[], extra: readonly string[] = []): Set<string> {
  return new Set([...LAZY_BASE_FULL_TOOLS, ...hinted, ...called, ...requested, ...extra]);
}

/** المعروض: كامل الأدوات اللي في [full] بس، + load_tools بأسماء الباقي (لو في باقي). */
export function lazyTools<T extends ToolDef>(scoped: readonly T[], full: ReadonlySet<string>): ToolDef[] {
  const shown = scoped.filter((t) => full.has(t.name));
  const deferred = scoped.filter((t) => !full.has(t.name)).map((t) => t.name);
  return deferred.length > 0 ? [...shown, loadToolsDef(deferred)] : shown;
}
