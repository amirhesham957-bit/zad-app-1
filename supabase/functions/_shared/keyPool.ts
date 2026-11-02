/**
 * مسابح المفاتيح — مصدر واحد لكل الفانكشنز.
 *
 * كانت كل فانكشن بتقرا `ZAD_API_KEY_1..5` و`GROQ_API_KEY_1/2` بإيدها (٦ نسخ)، فأي مفتاح
 * سادس بيتحط في الأسرار كان بيتجاهل بصمت. دلوقتي أي رقم من ١ لحد [MAX_KEYS] بيتقرا —
 * مش لازم يكونوا متتاليين (مفتاح اتشال من النص مايقطعش اللي بعده) — والمكرر بيتشال.
 *
 * السعة = مفاتيح × موديلات × حصة الموديل (اتقاس ٢٠٢٦-٠٨-١٥: كل مفتاح في مشروع جوجل
 * منفصل، يعني كل مفتاح زيادة = حصة زيادة فعلاً).
 */

/** أعلى رقم بيتقرا من `ZAD_API_KEY_n` / `GROQ_API_KEY_n`. */
export const MAX_KEYS = 20;

type Env = (name: string) => string | undefined;

function numbered(env: Env, prefix: string): string[] {
  const keys: string[] = [];
  for (let n = 1; n <= MAX_KEYS; n++) {
    const k = env(`${prefix}${n}`)?.trim();
    if (k) keys.push(k);
  }
  return keys;
}

const unique = (keys: string[]) => [...new Set(keys)];

/**
 * مفاتيح جيميناي المدفوعة (ZAD_PLAN ٨.٢): `ZAD_PAID_KEY_1..20`، من مشروع عليه فاتورة. شروط جوجل
 * للمجاني صريحة: «Do not submit sensitive, confidential, or personal information to the Unpaid
 * Services» — وبيستخدموا الطلبات في تحسين منتجاتهم ومراجعين بشر ممكن يقروها. المدفوع لأ.
 */
export function paidGeminiKeys(env: Env): string[] {
  return unique(numbered(env, "ZAD_PAID_KEY_"));
}

/** داتا العملاء ماشية على أنهي طبقة: "paid" لو فيه مفتاح مدفوع، وإلا "free". */
export function aiDataTier(env: Env): "paid" | "free" {
  return paidGeminiKeys(env).length > 0 ? "paid" : "free";
}

/**
 * مفاتيح جيميناي اللي بتشيل داتا العملاء. لو فيه مفتاح مدفوع، **هو بس** — المجاني مابيتلمسش حتى
 * كاحتياطي، لأن احتياطي مجاني = نفس التسريب لما المدفوع يقع (الاحتياطي بعده جروك).
 * من غير مدفوع: `ZAD_API_KEY_1..20`، ولو ولا واحد متحط، المفرد القديم
 * (`ZAD_API_KEY` ثم `GEMINI_API_KEY`) عشان مشروع نصه متنقل مايخسرش جيميناي.
 */
export function geminiKeys(env: Env): string[] {
  const paid = paidGeminiKeys(env);
  return paid.length > 0 ? paid : freeGeminiKeys(env);
}

/**
 * مفاتيح المجاني (`ZAD_API_KEY_1..20`، أو المفرد القديم) من غير اعتبار للمدفوع. لما المدفوع متحط، دي
 * بتشيل حساب الاختبار بس (حارة `internal` في zad-brain) — داتا مصطنعة، مش داتا عميل (قرار المالك ٢/١١).
 */
export function freeGeminiKeys(env: Env): string[] {
  const pool = unique(numbered(env, "ZAD_API_KEY_"));
  if (pool.length > 0) return pool;
  const legacy = env("ZAD_API_KEY")?.trim() || env("GEMINI_API_KEY")?.trim();
  return legacy ? [legacy] : [];
}

/** مفاتيح جروك: `GROQ_API_KEY_1..20` ثم المفرد الأصلي `GROQ_API_KEY`، من غير تكرار. */
export function groqKeys(env: Env): string[] {
  const single = env("GROQ_API_KEY")?.trim();
  return unique([...numbered(env, "GROQ_API_KEY_"), ...(single ? [single] : [])]);
}
