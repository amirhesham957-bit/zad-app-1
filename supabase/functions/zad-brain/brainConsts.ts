// Shared model/config constants and small helpers used by more than one brain module (m4.5 pass3b). Values are unchanged: same Deno.env reads.
import { callModel } from "./callModel.ts";
import { GATE_RESPONSE_SCHEMA } from "./notificationGate.ts";
import { SupabaseClient } from "jsr:@supabase/supabase-js@2";

export const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;

// The agent loop's model, deliberately NOT ZAD_MODEL_ROUTINE any more.
//
// ZAD_MODEL_ROUTINE is a shared secret that zad-core-intelligence also reads for vision /
// OCR / SMS extraction, and it is currently set to gemini-3.5-flash. Two facts measured
// against this project on 2026-08-15 make that the wrong model for *this* loop, while
// saying nothing about whether it is right for scanning a receipt:
//
//   1. Quota. The 429s that failed 14 of 26 brain runs name
//      `GenerateRequestsPerDayPerProjectPerModel-FreeTier` = 20/day. Sharing one model
//      string across the agent loop and every camera scan means both spend the same
//      20 requests, and the loop makes several calls per conversation turn.
//   2. Thinking. gemini-3.5-flash burned 231 thought tokens on "سجل 50 جنيه قهوة" and
//      returned finishReason=MAX_TOKENS. gemini-3.5-flash-lite answered the identical
//      request with a correct tool call, 0 thought tokens, in a quarter of the time.
//
// So the agent gets its own knob with its own default. Whether the lite model is equally
// good at reading a blurry receipt is a separate question that was NOT tested here, which
// is exactly why this change does not touch ZAD_MODEL_ROUTINE's value. Set ZAD_MODEL_AGENT
// as a secret to override; callModel() falls through the rest of the chain from here.
export const MODEL_ROUTINE = Deno.env.get("ZAD_MODEL_AGENT") ?? "gemini-3.5-flash-lite";
// القرارات المصنّفة (ZAD_PLAN ٣.١٠): لما جيميناي كله يقع، الأصغر على جروك — القرار JSON صغير،
// ومش محتاج الـ١٢٠b بتاع الشات. اتقاس ٢٤/١٠: ٢٠٠ على الـ١١ مفتاح، ١٠٠٠ طلب/يوم لكل واحد.
export const DECISION_GROQ_MODEL = Deno.env.get("ZAD_DECISION_GROQ_MODEL") ?? "openai/gpt-oss-20b";

/**
 * نداء بوابة الإشعار: نفس النداء للإشعار الحقيقي ولـ bank_eval_run، عشان التقييم يقيس اللي شغال
 * فعلاً. الرد مقفول على GATE_RESPONSE_SCHEMA (النوع من القايمة)، والتفكير مقفول من callModel.
 */
export function gateCall(g: { system: string; user: string }, model = MODEL_ROUTINE) {
  return callModel({
    model, system: g.system, tools: [], history: [{ role: "user", text: g.user }], maxTokens: 300,
    responseSchema: GATE_RESPONSE_SCHEMA, groqModel: DECISION_GROQ_MODEL,
  });
}

/**
 * فيه قناة توصل اللحظة؟ توكن موبايل للجهاز، وربط تليجرام للفويس (المراجعة الشاملة ٢٠٢٦-١٠-٠٥). فشل القراية = آه — الأحسن نصيغ
 * زيادة من إننا نسكت عن جرعة.
 */
export async function momentChannels(sb: SupabaseClient, userId: string, o: { device: boolean; telegram: boolean }): Promise<boolean> {
  const none = Promise.resolve({ count: 0, error: null });
  const [t, b] = await Promise.all([
    o.device ? sb.from("zad_fcm_tokens").select("id", { count: "exact", head: true }).eq("user_id", userId) : none,
    o.telegram
      ? sb.from("telegram_bindings").select("id", { count: "exact", head: true }).eq("user_id", userId)
        .not("bound_at", "is", null).not("chat_id", "is", null)
      : none,
  ]);
  if (t.error || b.error) return true;
  return (t.count ?? 0) > 0 || (b.count ?? 0) > 0;
}

/** توقيت سوق العميل (zad_market_timezone على بلده). فشل = UTC، زي باقي الفانكشن. */
export async function accountTimeZone(sb: SupabaseClient, userId: string): Promise<string> {
  const { data: u } = await sb.from("zad_users").select("country").eq("id", userId).maybeSingle();
  const { data: tz, error } = await sb.rpc("zad_market_timezone", { p_country: (u as { country?: string | null } | null)?.country ?? null });
  if (error) console.error("[agent_tasks] zad_market_timezone failed:", error.message);
  return typeof tz === "string" && tz ? tz : "UTC";
}
