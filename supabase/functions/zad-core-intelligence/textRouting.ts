// توجيه النص والـJSON (قرار ٢٠٢٦-٠٩-٣٠، بحرية المالك: «أفضل دقة بأرخص طريقة من غير نتايج فاشلة»).
//
// المقاس في AI Studio لمشروع واحد: gemini-3.5-flash = ٢٠ طلب/يوم و٥ في الدقيقة، وكان عدّى
// حده (٣٣ من ٢٠)؛ gemini-3.5-flash-lite = ٥٠٠/يوم و١٥ في الدقيقة و٢٥٠ ألف توكن/دقيقة. الموديل
// الخفيف بيشغّل لفة العقل كلها في zad-brain من ٢٠٢٦-٠٨، ونجح في اختبار فاتورة حقيقية (merchant
// و total و٤ أصناف صح، ٢٠٢٦-٠٨-١٥). القاعدة: النص والـJSON على الخفيف، والتقيل محجوز للصور —
// وللتصعيد: لو الخفيف رجّع JSON مايتقراش، الطلب بيتعاد مرة على التقيل بدل ما يرجع فاضي.

export const DEFAULT_TEXT_MODEL = "gemini-3.5-flash-lite";

/** JSON الموديل: الأسوار ```json اللي بتطلع أحياناً بتتشال قبل القراية. null = مايتقراش. */
export function parseModelJson(raw: string | null | undefined): unknown | null {
  if (!raw) return null;
  const t = raw.trim().replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/, "");
  try {
    return JSON.parse(t);
  } catch {
    // JSON mode still slips now and then (2026-11-15: `"text":"…" "recipes":[…]`, the comma
    // missing, on gemini-3.5-flash — the chef answered nothing). Repair, then read once more.
    try {
      return JSON.parse(repairModelJson(t));
    } catch {
      return null;
    }
  }
}

/**
 * يصلّح غلطتين بيعملهم الموديل حتى في JSON mode، برّه النصوص بس: فاصلة ناقصة بين قيمتين
 * (`"a":1 "b":2`) وفاصلة زيادة قبل `}` أو `]`. مابيضيفش ولا بيغيّر أي قيمة — نص مقطوع
 * (MAX_TOKENS) يفضل مايتقراش ويروح للتصعيد.
 */
export function repairModelJson(t: string): string {
  let out = "";
  let inString = false;
  let escaped = false;
  // The last thing outside a string closed a value, so the next value needs a comma first.
  let afterValue = false;
  for (let i = 0; i < t.length; i++) {
    const c = t[i];
    if (inString) {
      out += c;
      if (escaped) escaped = false;
      else if (c === "\\") escaped = true;
      else if (c === '"') { inString = false; afterValue = true; }
      continue;
    }
    if (/\s/.test(c)) { out += c; continue; }
    if (c === "}" || c === "]") {
      out = out.replace(/,(\s*)$/, "$1");
      out += c;
      afterValue = true;
      continue;
    }
    if (c === ":" || c === ",") { out += c; afterValue = false; continue; }
    if (afterValue) out += ",";
    if (c === '"') { out += c; inString = true; afterValue = false; continue; }
    if (c === "{" || c === "[") { out += c; afterValue = false; continue; }
    // A bare literal (number, true, false, null) is one token, read whole.
    let j = i;
    while (j < t.length && /[-+.\w]/.test(t[j])) j++;
    if (j === i) { out += c; afterValue = false; continue; }
    out += t.slice(i, j);
    afterValue = true;
    i = j - 1;
  }
  return out;
}

/**
 * الموديل اللي يتسأل لو رد [model] مايتقراش: موديل **تاني** دايماً. لما ZAD_MODEL_BRAIN بقى نفس
 * موديل الطلب (المفتاح المدفوع، 2026-11-15) التصعيد كان بيرجّع null من غير ما يسأل حد. null =
 * مفيش موديل تاني (الاتنين واحد).
 */
export function escalationModel(model: string, brain: string, text: string): string | null {
  const other = model === brain ? text : brain;
  return other === model ? null : other;
}

/**
 * لو [raw] مايتقراش، مرة واحدة على [heavy]. الفشل الكامل (raw = null) مش شغل الدالة دي —
 * السلسلة وGroq اتجربوا خلاص؛ التصعيد لـ«رد وصل بس بايظ» بس.
 */
export async function escalateOnBadJson(
  raw: string | null,
  heavy: () => Promise<string | null>,
): Promise<{ value: unknown | null; escalated: boolean }> {
  const first = parseModelJson(raw);
  if (first !== null || raw === null || raw.trim() === "") return { value: first, escalated: false };
  return { value: parseModelJson(await heavy()), escalated: true };
}
