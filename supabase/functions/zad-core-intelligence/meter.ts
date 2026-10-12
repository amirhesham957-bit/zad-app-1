// العدّاد (فحص ما قبل الإطلاق ٢٠٢٦-١٠-١٢): الفنكشن دي ماكانتش بتخصم محاولات ولا بتعدّ —
// مسح الصور والصوت وكل الأكشنات النصية كانت مفتوحة لأي توكن، من غير حد. سكريبت واحد كان
// يقدر يخلّص مفاتيح Gemini المشتركة (٢٠ طلب في اليوم لكل مفتاح على 3.5-flash) على كل العملاء.
//
// القاعدة:
//   * توكن عميل: حد في الدقيقة وفي اليوم لكل نوع (zad_rate_take)، والمسح بيخصم محاولتين
//     (zad_entitlement_consume 'scan')، والصوت بيعدّي على نفس البوابة بسعره من zad_tiers
//     (مجاني دلوقتي بقرار المالك ٢٠٢٦-٠٩-١٤ — voice_monthly = -1).
//   * مسح رجع فاضي (صورة مش مقروءة، الموديل ماردّش) بيرجّع اللي اتخصم — العميل مابيدفعش
//     على حاجة ماخدهاش، والحد في الدقيقة واليوم هو اللي بيمنع استغلال ده.
//   * توكن الخدمة (العقل، بوت تليجرام): من غير عدّاد هنا — ليهم بواباتهم.
//   * من غير حساب (مفتاح anon اللي جوه الـAPK): المسح والصوت مرفوضين.
//
// الحدود دي حماية من الإساءة، مش حدود منتج: المسح ٦ في الدقيقة (العميل الحقيقي بيصوّر فاتورة
// كل كام دقيقة)، والصوت ٤٠ (رد واحد بيتقطّع لـ٦–١٠ أجزاء، voice_output_controller.dart)،
// والباقي ٤٠ (الشاشة الرئيسية بتطلب كذا أكشن مع بعض).

export type Bucket = "vision" | "voice" | "other";

export interface Meter {
  bucket: Bucket;
  /** نوع الخصم في zad_entitlement_consume، أو null لو الأكشن مابيخصمش. */
  kind: "scan" | "voice" | null;
  perMinute: number;
  perDay: number;
}

const SCAN_ACTIONS = new Set([
  "analyze_receipt",
  "analyze_inventory_image",
  "analyze_medicine_image",
  "analyze_document_image",
]);
const VOICE_ACTIONS = new Set(["voice_synthesize", "voice_agent"]);
// ليها حراسها الخاصة (مفتاح الخدمة أو أدمن) ومابتصرفش من مفاتيح العملاء.
const OWN_GUARD = new Set(["provider_health", "voice_selftest", "admin_recent_activity"]);

/** عدّاد الأكشن، أو null لو مالوش عدّاد هنا. */
export function meterFor(action: unknown): Meter | null {
  if (typeof action !== "string" || !action || OWN_GUARD.has(action)) return null;
  if (SCAN_ACTIONS.has(action)) return { bucket: "vision", kind: "scan", perMinute: 6, perDay: 100 };
  if (VOICE_ACTIONS.has(action)) return { bucket: "voice", kind: "voice", perMinute: 40, perDay: 1000 };
  return { bucket: "other", kind: null, perMinute: 40, perDay: 800 };
}

/** المسح رجع من غير قراءة — الأشكال الفاضية اللي كل أكشن بيرجّعها في index.ts. */
export function scanCameBackEmpty(action: string, body: unknown): boolean {
  if (!body || typeof body !== "object") return true;
  const b = body as Record<string, unknown>;
  if (typeof b.error === "string") return true;
  switch (action) {
    case "analyze_receipt":
      return !(Number(b.total) > 0) && !(Array.isArray(b.items) && b.items.length > 0);
    case "analyze_inventory_image":
      return !(Array.isArray(b.items) && b.items.length > 0);
    case "analyze_medicine_image":
      return b.medicine == null;
    case "analyze_document_image":
      return b.document == null;
    default:
      return false;
  }
}

export const TOO_FAST_MESSAGE = "بالراحة عليّ شوية 😅 طلبات كتير ورا بعض — جرّب تاني بعد دقيقة.";
export const DAY_CAP_MESSAGE = "وصلت لحد النهارده من الطلبات دي — نكمّل بكرة 🙏";
export const NO_ATTEMPTS_SCAN_MESSAGE =
  "رصيد محاولاتك مايكفيش قراية الصورة (القراية بمحاولتين). الرصيد بيتجدد لوحده، أو تقدر تشوف الباقات.";
export const NO_ATTEMPTS_VOICE_MESSAGE = "رصيد الصوت خلص لحد التجديد الجاي.";

export type Rpc = (fn: string, args: Record<string, unknown>) => Promise<{ data: unknown; error: { message: string } | null }>;

export interface GateResult {
  /** رد جاهز بدل تشغيل الأكشن. */
  refusal?: { status: number; body: Record<string, unknown> };
  /** اتخصم من الرصيد فعلاً — يرجع لو الأكشن رجع فاضي. */
  charged?: "scan" | "voice";
}

/** حد العميل، وبعده الخصم. الحد اللي فشل في الداتابيز مفتوح؛ الخصم اللي فشل مقفول. */
export async function openGate(rpc: Rpc, userId: string, meter: Meter): Promise<GateResult> {
  const { data: rate, error: rateErr } = await rpc("zad_rate_take", {
    p_user: userId, p_bucket: meter.bucket, p_per_minute: meter.perMinute, p_per_day: meter.perDay,
  });
  if (rateErr) console.error("[meter] zad_rate_take failed, letting the call through:", rateErr.message);
  const r = rate as { ok?: boolean; reason?: string } | null;
  if (!rateErr && r?.ok === false) {
    const day = r.reason === "day";
    return {
      refusal: {
        status: 429,
        body: { error: day ? "daily_cap" : "too_fast", message: day ? DAY_CAP_MESSAGE : TOO_FAST_MESSAGE },
      },
    };
  }
  if (!meter.kind) return {};

  const { data, error } = await rpc("zad_entitlement_consume", { p_user: userId, p_kind: meter.kind, p_tz: "UTC" });
  if (error) {
    console.error("[meter] zad_entitlement_consume failed:", error.message);
    return { refusal: { status: 503, body: { error: "entitlement_unavailable" } } };
  }
  const c = data as { allowed?: boolean; reason?: string } | null;
  if (c?.allowed !== true) {
    return {
      refusal: {
        status: 402,
        body: {
          error: "no_attempts",
          message: meter.kind === "scan" ? NO_ATTEMPTS_SCAN_MESSAGE : NO_ATTEMPTS_VOICE_MESSAGE,
          entitlement: c,
        },
      },
    };
  }
  // 'quota' بس معناها إن فيه خصم حصل؛ media_pass و unlimited مابيخصموش.
  return c.reason === "quota" ? { charged: meter.kind } : {};
}
