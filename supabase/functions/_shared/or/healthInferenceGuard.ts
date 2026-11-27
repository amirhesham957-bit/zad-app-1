// حارس م٧.١٢: زاد ما يستنتجش مرض أو حمل من المشتريات أو السلوك، ومايدّعيش تشخيص.
// بيفحص النص الصادر للعميل (رد الشات والإشعار الاستباقي). جملة فيها صياغة استنتاج/ادعاء لحالة صحية
// ما قالهاش العميل بنفسه بتتشال. لو الحالة اتقالت في كلام العميل (declared) الجملة بتعدّي.
// الحالة المعلنة = اللي العميل كتبه بنفسه (رسايله، أو conditions الصحية اللي وافق عليها). دالة صافية: مافيش I/O.

interface Group {
  /** أسماء الحالة اللي بتتفحص في النص الصادر (دقيقة، عشان «سكر» المنتج ما يتحسبش مرض). */
  strict: RegExp;
  /** أي إشارة في كلام العميل بتعني إنه هو اللي قال الحالة. */
  declared: RegExp;
}

const GROUPS: readonly Group[] = [
  { strict: /(حامل|حبلي|حمل مبكر|الحمل|pregnan)/i, declared: /(حامل|حبلي|حمل|pregnan)/i },
  { strict: /(سكري|مرض السكر|بالسكر|ارتفاع السكر|diabet)/i, declared: /(سكري|سكر|diabet)/i },
  { strict: /(ضغط الدم|ضغط عالي|ارتفاع الضغط|بالضغط|hypertens|blood pressure)/i, declared: /(ضغط|hypertens|blood pressure)/i },
  { strict: /(انيميا|فقر الدم|anemi|anaemi)/i, declared: /(انيميا|فقر|anemi|anaemi)/i },
  { strict: /(سرطان|cancer)/i, declared: /(سرطان|cancer)/i },
  { strict: /(اكتئاب|depress)/i, declared: /(اكتئاب|depress)/i },
  { strict: /(سيلياك|حساسيه القمح|celiac|coeliac)/i, declared: /(سيلياك|حساسيه|celiac|coeliac)/i },
  { strict: /(عقم|infertil)/i, declared: /(عقم|infertil)/i },
  { strict: /(مرض|امراض|مريض|مصاب|illness|disease|sick)/i, declared: /(مرض|امراض|مريض|مصاب|illness|disease|sick)/i },
];

// صياغة الاستنتاج أو الادعاء الطبي: «أظن إنك…»، «شكلك…»، «عندك…»، «you might have…».
const INFERENCE =
  /(اظن|اعتقد|اتوقع|احتمال|يبدو|باين|شكلك|شكل|واضح ان|غالبا|اكيد|ممكن (انك|انتي|انت)|يمكن (انك|انتي|انت)|تعاني|بتعاني|مصاب|مصابه|عندك (مرض|سكري|ضغط|انيميا|سرطان|اكتئاب|حمل)|تشخيص|شخصت|i think|i suspect|you (might|may|could|must|probably|seem|appear)|looks like|seems like|probably|you have|you are|you're|diagnos|based on your purchases)/i;

/** تطبيع عربي: بيشيل التشكيل والتطويل ويوحّد الألف والياء والتاء المربوطة. */
export function normalizeArabic(s: string): string {
  return s
    .replace(/[ً-ٰٟـ]/g, "")
    .replace(/[أإآ]/g, "ا")
    .replace(/ى/g, "ي")
    .replace(/ة/g, "ه");
}

export const HEALTH_SAFE_FALLBACK = "خليني أركّز على اللي إنت قلته لي بنفسك. لو في حاجة صحية عايزني آخدها في الحساب، قولّي عليها.";

export interface HealthGuardVerdict {
  text: string;
  /** جمل اتشالت. */
  removed: string[];
}

/** جملة فيها استنتاج/ادعاء صحي غير معلن؟ */
export function isUndeclaredHealthInference(sentence: string, declaredText: string): boolean {
  const s = normalizeArabic(sentence);
  if (!INFERENCE.test(s)) return false;
  const declared = normalizeArabic(declaredText);
  return GROUPS.some((g) => g.strict.test(s) && !g.declared.test(declared));
}

/**
 * يشيل جمل الاستنتاج الصحي غير المعلن من [text]. لو ماتبقاش حاجة بيرجع [HEALTH_SAFE_FALLBACK].
 * [declaredText] = كلام العميل نفسه (الرسالة الحالية + رسايله السابقة + حالاته الصحية المصرّحة).
 */
export function guardHealthInference(text: string, declaredText = ""): HealthGuardVerdict {
  const parts = text.split(/(?<=[.!؟?\n۔])\s*/u);
  const removed: string[] = [];
  const kept = parts.filter((p) => {
    if (isUndeclaredHealthInference(p, declaredText)) {
      removed.push(p.trim());
      return false;
    }
    return true;
  });
  if (removed.length === 0) return { text, removed };
  const out = kept.join(" ").trim();
  return { text: out === "" ? HEALTH_SAFE_FALLBACK : out, removed };
}
