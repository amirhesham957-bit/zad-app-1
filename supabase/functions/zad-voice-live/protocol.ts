// protocol.ts — منطق النقل الصافي بتاع relay المكالمة الحية، معزول عن Deno.serve عشان
// يتختبر من غير شبكة.
//
// ليه الملف ده موجود (٢٠٢٦-٠٩-١٤): المكالمة الحية كانت بتفشل على جهاز حقيقي برسالة
// "تعذّر الاتصال" وخلاص، والسبب الحقيقي كان إن رصيد الصوت للحساب صفر (402). الفانكشن
// كانت بترد على طلب الـupgrade بـResponse عادي (401/402/503)، وبوابة Supabase بتحوّل أي
// رد مش 101 على طلب WebSocket لفشل عام (اتقاس: curl بـupgrade رجّع 502 من غير body) —
// فالعميل عمره ما شاف الكود، ومفيش ولا سطر لوج. الحل: نقبل الـupgrade دايمًا ونقفل
// بكود تطبيقي (4000-4999) وسبب مقروء — ده بيعدّي البوابة لأنه جوه اتصال مفتوح فعلاً.

/** أكواد إغلاق خاصة بالتطبيق. نفس الأرقام في ZadVoiceController.kt — غيّرهم مع بعض. */
export const CLOSE_UNAUTHORIZED = 4401;
export const CLOSE_ENTITLEMENT = 4402;
export const CLOSE_PROVIDER_UNAVAILABLE = 4503;
export const CLOSE_UPSTREAM_ENDED = 4502;

/** سبب إغلاق WebSocket محدود بـ123 بايت UTF-8 — أطول من كده الـclose() بيرمي. القص
 *  بالبايت مش بالحرف، لأن الحرف العربي بايتين. */
export function closeReason(text: string, maxBytes = 123): string {
  const encoder = new TextEncoder();
  if (encoder.encode(text).length <= maxBytes) return text;
  let out = "";
  for (const ch of text) {
    if (encoder.encode(out + ch).length > maxBytes) break;
    out += ch;
  }
  return out;
}

/** جيميناي بيقفل بأكواد قياسية (1000 طبيعي، 1007/1008/1011 أخطاء — منها الحصة والموديل
 *  غير الصالح) وسببه نص إنجليزي. العميل محتاج يفرّق بين "المكالمة خلصت" و"المزوّد رفض"،
 *  فأي إغلاق مش 1000 بيتحوّل لـ4502 مع سبب جيميناي نفسه بدل 1011 عام بيضيّع السبب. */
export function clientCloseForUpstream(code: number, reason: string): { code: number; reason: string } {
  if (code === 1000) return { code: 1000, reason: "session ended" };
  return { code: CLOSE_UPSTREAM_ENDED, reason: closeReason(`upstream ${code}: ${reason || "no reason"}`) };
}

/** فريم جيميناي ممكن ييجي نص أو binary (JSON جوه بايتات) حسب الـruntime — الـSDK الرسمي
 *  نفسه بيتعامل مع الاتنين. التمرير الأعمى لفريم binary كان بيوصل للعميل اللي مالوش
 *  handler للبايتات، فالصوت كان بيتفقد من غير أثر، والـtoolCall جواه ماكانش بيتعترض. */
export function frameToText(data: unknown): string | null {
  if (typeof data === "string") return data;
  if (data instanceof ArrayBuffer) return new TextDecoder().decode(new Uint8Array(data));
  if (ArrayBuffer.isView(data)) {
    return new TextDecoder().decode(new Uint8Array(data.buffer, data.byteOffset, data.byteLength));
  }
  return null;
}

/** `realtimeInput.mediaChunks` مهجور في Live API، والحقل الحالي `realtimeInput.audio`.
 *  نسخ التطبيق المتثبتة بتبعت mediaChunks، فالتحويل هنا بيغطي كل النسخ من غير تحديث.
 *  أي فريم مش بالشكل ده بيرجع زي ما هو بالظبط. */
export function normalizeClientFrame(text: string): string {
  let parsed: unknown;
  try {
    parsed = JSON.parse(text);
  } catch {
    return text;
  }
  const input = (parsed as { realtimeInput?: Record<string, unknown> })?.realtimeInput;
  const chunks = input?.mediaChunks;
  if (!input || !Array.isArray(chunks) || chunks.length !== 1 || input.audio) return text;
  const chunk = chunks[0] as { mimeType?: unknown; data?: unknown };
  if (typeof chunk?.mimeType !== "string" || !chunk.mimeType.startsWith("audio/")) return text;
  if (typeof chunk.data !== "string") return text;
  const { mediaChunks: _dropped, ...rest } = input;
  return JSON.stringify({ realtimeInput: { ...rest, audio: { mimeType: chunk.mimeType, data: chunk.data } } });
}

/** شخصية الصوت اللي العميل اختارها → صوت جيميناي. نفس جدول `zad-core-intelligence/voice.ts`
 *  (VOICE_IDS) بالحرف — مفيش استيراد بين الفانكشنز في المشروع ده، فالتست بيقفل التطابق.
 *  من غير ده الإعداد كان بيغيّر صوت قراءة النصوص بس، والمكالمة الحية فضلت على صوت واحد. */
export const LIVE_VOICE_BY_PERSONA: Record<string, string> = {
  sarah_warm: "Aoede",
  karim_pro: "Charon",
  pet_mascot: "Leda",
};

/** شخصية مش معروفة أو مش مبعوتة = الصوت الافتراضي. أي قيمة من العميل مابتوصلش لجيميناي
 *  غير لو هي صوت من الجدول — setup بصوت غلط بيقفل الجلسة بـ1007. */
export function liveVoiceFor(persona: string | null | undefined, fallback: string): string {
  return (persona && Object.hasOwn(LIVE_VOICE_BY_PERSONA, persona)) ? LIVE_VOICE_BY_PERSONA[persona] : fallback;
}
