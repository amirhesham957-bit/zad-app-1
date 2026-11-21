// commitIntent.ts — أدوات المخزن بتكتب من الباب الوحيد (ZAD_OR_PLAN م٢.٥).
//
// العقل بيفهم الكلام ويلاقي الصنف (المطابقة فاضلة هنا)، وzad_commit_intent بيراجع القيود ويكتب الحدث والصف مع بعض،
// أو بيرفض ويسجل السبب في zad_guard_events. مفيش أداة مخزن بتلمس zad_inventory بإيدها بعد كده.
//
// مفتاح التكرار: نفس النداء (الأداة + المدخل) في نفس اللفة = نفس المفتاح، فالموديل لو بعت نفس الأداة مرتين
// الكتابة بتحصل مرة واحدة. من غير لفة (زرار تليجرام) المفتاح من اللي نادى (client_event_id)، وإلا عشوائي.

import { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import type { AuditScope } from "./audit.ts";

export type IntentKind =
  | "inventory.added" | "inventory.consumed" | "inventory.quantity_set" | "inventory.deleted" | "inventory.restock_mode_set";
export type IntentSource = "manual" | "receipt" | "bank" | "model" | "cron";

export type CommitResult =
  | { ok: true; duplicate: boolean; rowId: string | null; before: number | null; after: number | null }
  | { ok: false; reason: string };

/** JSON بترتيب مفاتيح ثابت، عشان نفس المدخل يدّي نفس المفتاح. */
function stable(v: unknown): string {
  if (Array.isArray(v)) return `[${v.map(stable).join(",")}]`;
  if (v && typeof v === "object") {
    return `{${Object.keys(v as Record<string, unknown>).sort().map((k) => `${JSON.stringify(k)}:${stable((v as Record<string, unknown>)[k])}`).join(",")}}`;
  }
  return JSON.stringify(v ?? null);
}

async function sha(text: string): Promise<string> {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return Array.from(new Uint8Array(buf).slice(0, 12), (b) => b.toString(16).padStart(2, "0")).join("");
}

/** مفتاح التكرار (≤ ١٠٠ حرف، شرط الباب). */
export async function intentKey(scope: AuditScope, tool: string, input: unknown): Promise<string> {
  const given = typeof scope.eventKey === "string" ? scope.eventKey.trim() : "";
  if (given) return `${tool}:${given}`.slice(0, 100);
  if (scope.runId) return `${scope.runId}:${tool}:${await sha(stable(input))}`;
  return `${tool}:${crypto.randomUUID()}`;
}

/** مين بدأ الكتابة: لفة شات = الموديل، لفة الكرون/الحدث = cron، زرار من غير لفة = العميل بإيده. */
export function intentSource(scope: AuditScope): IntentSource {
  if (scope.source === "daily" || scope.source === "event") return scope.runId ? "cron" : "manual";
  return scope.runId ? "model" : "manual";
}

export async function commitIntent(
  sb: SupabaseClient, userId: string, scope: AuditScope, tool: string, input: unknown,
  kind: IntentKind, payload: Record<string, unknown>,
): Promise<CommitResult> {
  const intent = {
    user_id: userId, kind, client_event_id: await intentKey(scope, tool, input),
    source: intentSource(scope), payload,
  };
  const { data, error } = await sb.rpc("zad_commit_intent", { p_intent: intent });
  if (error) return { ok: false, reason: `rpc: ${error.message}` };
  const r = (data ?? {}) as Record<string, unknown>;
  if (r.ok !== true) return { ok: false, reason: String(r.reason ?? "refused") };
  const num = (v: unknown) => (v === null || v === undefined || !Number.isFinite(Number(v)) ? null : Number(v));
  return {
    ok: true, duplicate: r.duplicate === true, rowId: typeof r.row_id === "string" ? r.row_id : null,
    before: num(r.before), after: num(r.after),
  };
}

const REASONS: Record<string, string> = {
  item_not_found: "الصنف مش في مخزن البيت ده",
  name_invalid: "اسم الصنف لازم يكون من ٢ لـ١٢٠ حرف",
  qty_not_positive: "الكمية لازم تكون أكبر من صفر",
  qty_too_large: "الكمية كبيرة بشكل مش منطقي — اتأكد من العميل",
  qty_negative: "الكمية مينفعش تبقى بالسالب",
  category_unknown: "الفئة مش من الفئات المعروفة",
  expiry_bad_format: "الصلاحية لازم تكون YYYY-MM-DD",
  expiry_before_purchase: "تاريخ الصلاحية قبل النهارده — اتأكد من العميل",
  amount_invalid: "الكمية المستعملة لازم تكون أكبر من صفر",
  amount_too_large: "الكمية المستعملة كبيرة بشكل مش منطقي",
  restock_mode_unknown: "النوع يا staple يا occasional",
};

/** سبب الرفض بالعربي للموديل (والكود الأصلي بين قوسين للتشخيص). */
export function refusalText(reason: string): string {
  return `مرفوض: ${REASONS[reason] ?? "الكتابة اترفضت"} (${reason}) — عدّل وحاول تاني.`;
}

/**
 * الرفض ده جه من الباب (وبالتالي اتسجل في zad_guard_events هناك)؟ شكل refusalText بس: كود الباب بين قوسين
 * (حروف صغيرة و_). فشل النداء نفسه «(rpc: …)» مابيطابقش، فبيتسجل من runTool لأن الباب ماسجلهوش.
 */
export function isDoorRefusal(text: string): boolean {
  return /^مرفوض: .* \([a-z_]+\) — عدّل وحاول تاني\.$/s.test(text);
}

/** أكبر مدخل بيتحفظ مع الرفض (فاتورة كاملة مثلاً) — اللي أكبر بيتحفظ مقصوص. */
const GUARD_INPUT_MAX = 4000;

/**
 * رفض قبل الباب (المدقق أو الأداة نفسها) بيتسجل في zad_guard_events زي رفض الباب، عشان «صحة العقل» تشوف كل الرفض
 * من مكان واحد. kind = `validator:<أداة>` أو `tool:<أداة>`. فشل التسجيل مابيغيّرش الرد.
 */
export async function logGuard(
  sb: SupabaseClient, userId: string, scope: AuditScope, stage: "validator" | "tool", tool: string, reason: string, input: unknown,
): Promise<void> {
  try {
    const raw = JSON.stringify(input ?? {});
    const intent = raw.length <= GUARD_INPUT_MAX ? { tool, input: input ?? {} } : { tool, input_truncated: raw.slice(0, GUARD_INPUT_MAX) };
    const { error } = await sb.from("zad_guard_events").insert({
      user_id: userId, kind: `${stage}:${tool}`, reason: reason.replace(/^مرفوض:\s*/, "").slice(0, 300),
      source: intentSource(scope), intent,
    });
    if (error) console.error("[guard] insert failed:", error.message);
  } catch (e) {
    console.error("[guard] insert threw:", String(e));
  }
}

/** نفس النداء اتعمل قبل كده في اللفة دي: مفيش كتابة تانية. */
export const DUPLICATE_REPLY = "النداء ده اتنفذ قبل كده في نفس الطلب — مفيش حاجة اتكررت.";
