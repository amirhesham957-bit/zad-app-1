// ميزان اللفة (ZAD_DREAM_PLAN.md ع١ — «رجيم السياق»): كل لفة شات بتسجّل حجم كل جزء بعتته للموديل
// في zad_brain_runs.prompt_sizes، عشان القص يتعمل على الجزء التقيل فعلاً مش على التخمين.
//
// المقاس بالحروف مش بالتوكنز: التوكنايزر بتاع كل موديل مختلف، والحروف بتتقارن بين لفتين ومع
// input_tokens اللي الموديل رجّعها في نفس الصف. الأجزاء الفاضية مابتتسجلش.

export interface PromptSizes {
  /** حجم كل بلوك نصي في البرومبت، بالحروف. */
  parts: Record<string, number>;
  /** أتقل مفاتيح الـSNAPSHOT، بالحروف بعد JSON.stringify. */
  snapshot_keys: Record<string, number>;
  /** تعريفات الأدوات المعروضة (JSON)، وعددها. */
  tools_chars: number;
  tools_count: number;
  /** المحادثة اللي اتبعتت مع اللفة. */
  history_chars: number;
  history_turns: number;
  total_chars: number;
}

/** أتقل [top] مفاتيح في كائن، من الأتقل للأخف. */
export function heaviestKeys(obj: Record<string, unknown> | null | undefined, top = 12): Record<string, number> {
  const sizes: Array<[string, number]> = [];
  for (const [k, v] of Object.entries(obj ?? {})) {
    if (v == null) continue;
    const n = JSON.stringify(v)?.length ?? 0;
    if (n > 2) sizes.push([k, n]);
  }
  sizes.sort((a, b) => b[1] - a[1]);
  return Object.fromEntries(sizes.slice(0, top));
}

export function promptSizes(input: {
  parts: Record<string, string | null | undefined>;
  snapshot: Record<string, unknown> | null | undefined;
  tools: unknown[];
  history: ReadonlyArray<object>;
}): PromptSizes {
  const parts: Record<string, number> = {};
  for (const [k, v] of Object.entries(input.parts)) {
    const n = typeof v === "string" ? v.length : 0;
    if (n > 0) parts[k] = n;
  }
  const tools_chars = JSON.stringify(input.tools).length;
  const history_chars = input.history.reduce((s, t) => s + String((t as { text?: unknown }).text ?? "").length, 0);
  const total_chars = Object.values(parts).reduce((s, n) => s + n, 0) + tools_chars + history_chars;
  return {
    parts,
    snapshot_keys: heaviestKeys(input.snapshot),
    tools_chars,
    tools_count: input.tools.length,
    history_chars,
    history_turns: input.history.length,
    total_chars,
  };
}

/**
 * تعريف أداة خفيف للنداء التاني في اللفة وما بعده (رجيم السياق ٢): الاسم وأول جملة من الوصف
 * والـschema بأنواعها وenumها وrequired — من غير شرح الحقول. الموديل كان قرر خطته في النداء الأول
 * بالتعريف الكامل؛ هنا غالباً بيكتب الرد. الأداة اللي اتنادت أو اللي نية الرسالة بتشاور عليها
 * بتفضل كاملة ([keepFull]) — دي اللي ممكن تتنادى تاني بجد.
 */
export function leanTools<T extends { name: string; description?: string; input_schema?: unknown }>(
  tools: T[],
  keepFull: ReadonlySet<string>,
): T[] {
  const strip = (s: unknown): unknown => {
    if (Array.isArray(s)) return s.map(strip);
    if (s && typeof s === "object") {
      const o: Record<string, unknown> = {};
      for (const [k, v] of Object.entries(s)) if (k !== "description") o[k] = strip(v);
      return o;
    }
    return s;
  };
  return tools.map((t) => keepFull.has(t.name) ? t : {
    ...t,
    description: String(t.description ?? "").split(/[.؛:\n]/)[0].slice(0, 120),
    input_schema: strip(t.input_schema),
  });
}
