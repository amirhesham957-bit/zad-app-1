// قفل الصوت والصور على تليجرام.
//
// النص بيتحاسب في zad-brain (نفس البوابة اللي شات التطبيق بيعدي منها)، فالملف ده
// مسؤول عن الحاجتين اللي البوت بينفذهم بنفسه من غير ما يعدي على العقل: الرسالة
// الصوتية وصورة الفاتورة. الاتنين بيروحوا لـ zad-core-intelligence مباشرة، يعني من
// غير الفحص ده مفيش أي حاجة بتمنع مستخدم مجاني من تفريغ صوت ومسح فواتير بلا حدود
// من برّه التطبيق.
//
// ودول بالظبط أغلى وأهم ميزتين للعميل وهو برّه البيت — تسجيل صوتي وهو ماشي، أو تصوير
// فاتورة في المطعم — فهما اللي بيبيعوا الاشتراك.

// deno-lint-ignore no-explicit-any
type Sb = any;

export type MediaKind = "voice" | "scan";

export interface MediaGate {
  allowed: boolean;
  reply?: string;
}

const LOCKED_VOICE =
  "🔒 الرسايل الصوتية على تليجرام متاحة لمشتركي باقات زاد المميزة — أو تقدر تفتحها بإعلان واحد! 🎬\n\n" +
  "افتح تطبيق زاد → عقل زاد → \"افتح الصوت بإعلان\" — الإعلان الواحد بيفتحلك الصوت والصور 24 ساعة كاملة.\n" +
  "والكتابة العادية شغالة زي ما هي ومجاناً — ابعتلي \\\"صرفت ٥٠ قهوة\\\" وهسجلها فوراً.";

const LOCKED_PHOTO =
  "🔒 مسح الفواتير بالصور على تليجرام متاح لمشتركي الباقات — أو افتحه بإعلان واحد! 🎬\n\n" +
  "افتح تطبيق زاد → عقل زاد → \"افتح الصور بإعلان\" — إعلان واحد = يوم كامل فويس + صور.\n" +
  "وتقدر برضه تكتب الفاتورة هنا عادي ومجاناً.";

const EXHAUSTED_VOICE = "🔒 خلص رصيد الرسايل الصوتية في باقتك الشهرية. تقدر ترقّي باقتك من التطبيق.";
const VOICE_TODAY_DONE = "🔒 خلصت أسئلتك الصوتية النهارده (٦ في اليوم في الباقة المجانية) — بترجع بكرة. اكتبلي عادي، أو اشترك من التطبيق وكلّمني بصوتك من غير حد.";
// مسح الصورة بمحاولتين من الرصيد الواحد (20261012020000).
const EXHAUSTED_PHOTO = "🔒 مسح الفاتورة محتاج محاولتين، ومحاولات باقتك خلصت الشهر ده. تقدر ترقّي باقتك من التطبيق.";

/**
 * بيتنادى **قبل** تنزيل الملف من تليجرام، مش بعده: التنزيل نفسه بيستهلك وقت وباندويدث
 * على مستخدم مقفول أصلاً، والأهم إنه بيوصل بايتات لـ zad-core-intelligence لو حد نسي
 * يفحص الرد.
 *
 * بيفشل **مقفول** هنا، بعكس بوابة zad-brain اللي بتفشل مفتوحة. السبب إن ده مسار مدفوع
 * بحت: لو الفحص وقع، إتاحته للكل معناها إن الميزة اللي بنبيعها بقت مجانية لأي حد
 * بيحاول في اللحظة دي. النص لسه شغال مجاناً في الحالة دي، فالعميل مش مقطوع.
 */
export async function mediaGate(sb: Sb, userId: string, kind: MediaKind): Promise<MediaGate> {
  const locked = kind === "voice" ? LOCKED_VOICE : LOCKED_PHOTO;
  let status: Record<string, unknown> | null = null;
  try {
    const { data, error } = await sb.rpc("zad_entitlement_status", { p_user: userId });
    if (error) {
      console.error("zad_entitlement_status failed, failing closed:", error.message);
      return { allowed: false, reply: locked };
    }
    status = data as Record<string, unknown>;
  } catch (e) {
    console.error("zad_entitlement_status threw, failing closed:", e);
    return { allowed: false, reply: locked };
  }

  // الباقة المجانية مالهاش صور على تليجرام — رسالة ترقية. الفويس بقى زي التطبيق (قرار المالك ٣/١١): أسئلة
  // صوتية في اليوم من نفس العدّاد (zad_tiers.voice_daily)، فالفويس نوت بيتسمع ويترد عليه بدل رسالة الترقية.
  if (status?.telegram_media !== true && kind !== "voice") return { allowed: false, reply: locked };

  // مشترك: الرصيد الشهري هو اللي بيتخصم منه. الخصم بيحصل هنا عشان نفس السبب — قبل
  // ما نصرف على تنزيل الملف والنداء على الموديل.
  try {
    const { data, error } = await sb.rpc("zad_entitlement_consume", { p_user: userId, p_kind: kind });
    if (error) {
      console.error("zad_entitlement_consume failed, failing closed:", error.message);
      return { allowed: false, reply: locked };
    }
    const d = data as { allowed?: boolean; reason?: string };
    if (d?.allowed === true) return { allowed: true };
    // المجاني ٦ أسئلة صوتية في اليوم (20261103230000؛ كانت ٣ من 20261028020000) — حتى بتصريح الإعلان القديم.
    if (d?.reason === "voice_daily_cap") return { allowed: false, reply: VOICE_TODAY_DONE };
    if (d?.reason === "quota_exhausted") {
      return { allowed: false, reply: kind === "voice" ? EXHAUSTED_VOICE : EXHAUSTED_PHOTO };
    }
    return { allowed: false, reply: locked };
  } catch (e) {
    console.error("zad_entitlement_consume threw, failing closed:", e);
    return { allowed: false, reply: locked };
  }
}
