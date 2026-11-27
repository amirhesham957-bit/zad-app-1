// بوابة الشات الواحدة (P1.1): حجز، وبعد الرد تأكيد أو رجوع، على نفس دفتر الماسح
// (zad_energy_*، مايجريشن 20261127121500). قبلها handleAgentTurn كان بيخصم المحاولة
// (zad_entitlement_consume) ومفيش رجوع: الموديل يقع أو يرد فاضي والعميل يخسر محاولة.
//
// القواعد:
//   * الحجز هو zad_entitlement_consume زي ما كان (ذرّي في SQL، فطلبين متوازيين مايعدّوش الرصيد مرتين).
//     فشل الـRPC نفسه = مفتوح (gate_unavailable) زي entitlement.ts، ومفيش خصم فمفيش حاجة تتسوّى.
//   * بس لما السبب 'quota' فيه خصم فعلي، والخصم ده بيتسجّل في zad_energy_open. media_pass
//     والروتين والمالك/الاختبار مابيخصموش ومابيتسجّلوش.
//   * بعد الرد: done لو فيه نتيجة، refund لو الموديل رمى خطأ أو الرد فاضي. الرجوع مرة واحدة:
//     الدفتر نفسه بيمنع التكرار (open -> refunded)، وكمان settled هنا.
//   * تسجيل الدفتر فشل = السلوك القديم (من غير رجوع)، مايوقفش الرد. والكرون بيرجّع أي open أقدم من ١٠ دقايق.

import { consume as consumeEntitlement, type EntitlementDecision, type EntitlementKind } from "./entitlement.ts";

export interface ChatCharge {
  kind?: EntitlementKind;
  chargeId?: string;
  settled?: boolean;
}

// deno-lint-ignore no-explicit-any
type Sb = any;

/** حجز المحاولة. بيملا `charge` لو اتخصم فعلاً. */
export async function openChatCharge(
  sb: Sb, userId: string, kind: EntitlementKind, tz: string, charge: ChatCharge,
): Promise<EntitlementDecision> {
  const decision = await consumeEntitlement(sb, userId, kind, tz);
  if (!decision.allowed || decision.reason !== "quota") return decision;
  charge.kind = kind;
  try {
    const { data: id, error } = await sb.rpc("zad_energy_open", { p_user: userId, p_kind: kind });
    if (error) console.error("[gate] zad_energy_open failed:", error.message);
    else if (typeof id === "string" && id) charge.chargeId = id;
  } catch (e) {
    console.error("[gate] zad_energy_open threw:", e);
  }
  return decision;
}

/** الرد رجع من غير حاجة تتسلّم: خطأ، أو نص فاضي من غير أي تنفيذ أو اقتراح. */
export function chatBodyEmpty(status: number, body: unknown): boolean {
  if (status >= 500) return true;
  if (!body || typeof body !== "object") return false;
  const b = body as Record<string, unknown>;
  if (b.ok === false || typeof b.error === "string") return true;
  const hasWork = (v: unknown) => Array.isArray(v) && v.length > 0;
  if (hasWork(b.executed) || hasWork(b.proposals) || hasWork(b.app_commands)) return false;
  return typeof b.reply === "string" && !b.reply.trim();
}

/** تأكيد أو رجوع، مرة واحدة. بيرجع بعد الفشل بدون ما يرمي (الكرون بيكمّل). */
export async function settleChatCharge(sb: Sb, charge: ChatCharge, outcome: "done" | "refund", userId: string): Promise<void> {
  if (!charge.kind || charge.settled) return;
  charge.settled = true;
  try {
    if (outcome === "refund") {
      const { error } = charge.chargeId
        ? await sb.rpc("zad_energy_refund", { p_id: charge.chargeId, p_by: "function" })
        : await sb.rpc("zad_entitlement_refund", { p_user: userId, p_kind: charge.kind });
      if (error) console.error("[gate] refund failed:", error.message);
      return;
    }
    if (!charge.chargeId) return;
    for (let i = 0; i < 2; i++) {
      const { error } = await sb.rpc("zad_energy_done", { p_id: charge.chargeId });
      if (!error) return;
      console.error("[gate] zad_energy_done failed:", error.message);
    }
  } catch (e) {
    console.error("[gate] settle threw:", e);
  }
}

/** يشغّل اللفة ويقفل الحجز على نتيجتها: رمت خطأ أو رجعت فاضية = رجوع، غير كده done. */
export async function withChargeSettlement(
  sb: Sb, userId: string, charge: ChatCharge, run: () => Promise<Response>,
): Promise<Response> {
  let res: Response;
  try {
    res = await run();
  } catch (e) {
    await settleChatCharge(sb, charge, "refund", userId);
    throw e;
  }
  if (charge.kind && !charge.settled) {
    let body: unknown = null;
    try {
      body = await res.clone().json();
    } catch { /* مش JSON: نعتبره اتسلّم */ }
    await settleChatCharge(sb, charge, chatBodyEmpty(res.status, body) ? "refund" : "done", userId);
  }
  return res;
}
