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
    return null;
  }
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
