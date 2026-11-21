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
  | "inventory.added" | "inventory.consumed" | "inventory.quantity_set" | "inventory.deleted" | "inventory.restock_mode_set"
  | "shopping.added" | "shopping.completed" | "shopping.deleted"
  | "pharmacy.added" | "pharmacy.updated" | "pharmacy.deleted" | "pharmacy.dose_taken"
  | "money.logged" | "money.updated" | "money.deleted" | "money.purchase" | "money.limit_set" | "money.category_budget_set"
  | "subscription.added" | "subscription.updated" | "subscription.deleted"
  | "debt.added" | "debt.updated" | "debt.deleted"
  | "obligation.added" | "obligation.updated" | "obligation.deactivated"
  | "maintenance.added" | "maintenance.updated" | "maintenance.deleted"
  | "document.saved" | "document.deleted"
  | "appointment.added" | "appointment.updated" | "appointment.deleted";
export type IntentSource = "manual" | "receipt" | "bank" | "model" | "cron";

export type CommitResult =
  | {
    ok: true; duplicate: boolean; rowId: string | null; before: number | null; after: number | null;
    /** الـpayload اللي اتكتب في الحدث (الصيدلية بتقرا منه نتيجة الجرعة). فاضي في التكرار. */
    payload: Record<string, unknown>;
  }
  | { ok: false; reason: string; detail?: Record<string, unknown> | null };

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
  if (r.ok !== true) {
    const detail = r.detail && typeof r.detail === "object" ? r.detail as Record<string, unknown> : null;
    return { ok: false, reason: String(r.reason ?? "refused"), detail };
  }
  const num = (v: unknown) => (v === null || v === undefined || !Number.isFinite(Number(v)) ? null : Number(v));
  return {
    ok: true, duplicate: r.duplicate === true, rowId: typeof r.row_id === "string" ? r.row_id : null,
    before: num(r.before), after: num(r.after),
    payload: r.payload && typeof r.payload === "object" ? r.payload as Record<string, unknown> : {},
  };
}

const REASONS: Record<string, string> = {
  item_not_found: "السجل ده مش موجود عندك",
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
  already_purchased: "السطر ده اتشطب من القايمة قبل كده",
  member_not_granted: "الفرد ده مش في العيلة أو مش موافق إنك تتابع أدويته",
  patch_empty: "مفيش حاجة تتعدل",
  patch_field_unknown: "الحقل ده مايتعدلش من هنا",
  dose_times_invalid: "مواعيد الجرعات لازم تكون HH:MM مفصولة بفاصلة",
  dose_count_invalid: "عدد الجرعات في اليوم من ١ لـ٢٤",
  qty_invalid: "الكمية لازم تكون رقم صحيح من ٠ لـ١٠٠٠٠",
  dosage_too_long: "الجرعة مكتوبة طويلة أوي",
  dose_already_logged: "الجرعة دي متسجلة قبل كده — الكمية ماتخصمتش تاني",
  amount_not_positive: "المبلغ لازم يكون رقم موجب",
  amount_over_cap: "المبلغ ده كبير بشكل غير منطقي — تأكد منه",
  title_invalid: "اكتب وصف قصير للمعاملة (لحد ٨٠ حرف)",
  title_guessed: "الوصف ده تخمين — اسأل العميل الفلوس دي راحت على إيه قبل ما تسجلها",
  txn_kind_unknown: "النوع يا expense يا income",
  wallet_unknown: "المحفظة يا cash يا card يا bank",
  transfer_to_missing: "التحويل لازم يقول رايح فين",
  transfer_change_unsupported: "التحويل مايتعملش بالتعديل — سجّله معاملة جديدة",
  text_too_long: "الفئة أو اسم المحل طويل أوي",
  for_person_invalid: "«لمين» لازم يكون من ١ لـ٤٠ حرف",
  date_invalid: "تاريخ العملية مش مفهوم أو في المستقبل أو أقدم من سنة",
  category_invalid: "اسم الفئة لازم يكون من ٢ لـ٤٠ حرف",
  no_category_budget: "مفيش سقف على الفئة دي أصلاً",
  subscription_title_invalid: "اسم الاشتراك لازم يكون من ٢ لـ١٢٠ حرف",
  renewal_date_invalid: "تاريخ التجديد لازم يكون تاريخ حقيقي بصيغة YYYY-MM-DD",
  billing_cycle_invalid: "دورة الدفع يا MONTHLY يا YEARLY",
  due_day_invalid: "يوم الاستحقاق لازم يكون من ١ لـ٣١",
  is_active_invalid: "التفعيل لازم يكون true أو false",
  debt_name_invalid: "اسم الدين لازم يكون من ٢ لـ١٢٠ حرف",
  minimum_invalid: "الحد الأدنى الشهري لازم يكون رقم مش سالب",
  interest_invalid: "نسبة الفايدة لازم تكون من ٠ لـ١٠٠٠",
  balance_negative: "الرصيد المتبقي مينفعش يبقى بالسالب",
  obligation_title_invalid: "اسم الالتزام لازم يكون من ٢ لـ١٢٠ حرف",
  obligation_kind_invalid: "نوع الالتزام يا rent يا installment يا tuition يا utility يا other",
  recurrence_invalid: "التكرار يا monthly يا quarterly يا yearly يا once",
  installments_invalid: "عدد الأقساط لازم يكون رقم صحيح من ١ لـ٦٠٠",
  already_inactive: "الالتزام ده اتلغى قبل كده",
  device_name_invalid: "اسم الجهاز لازم يكون من ٢ لـ١٢٠ حرف",
  device_category_invalid: "فئة الجهاز طويلة أوي (٦٠ حرف بالكتير)",
  day_invalid: "التاريخ لازم يوم حقيقي بصيغة YYYY-MM-DD",
  interval_invalid: "الفاصل بين الصيانات لازم عدد أيام صحيح موجب",
  cost_invalid: "التكلفة لازم رقم موجب في الحدود المنطقية",
  kind_invalid: "النوع مش من الأنواع المعروفة",
  holder_invalid: "اسم صاحب المستند لازم يكون من غير مسافات زيادة ولحد ٤٠ حرف",
  label_invalid: "اسم المستند لازم يكون من غير مسافات زيادة ولحد ٤٠ حرف",
  label_required: "مستند «other» محتاج اسم",
  date_out_of_range: "تاريخ الانتهاء مش معقول (بين ٢٠٠٠ و٢١٠٠)",
  appt_title_invalid: "اسم الميعاد لازم من ٢ لـ١٦٠ حرف",
  starts_at_invalid: "وقت الميعاد مش مفهوم",
  appt_recurrence_invalid: "التكرار لازم once أو hourly أو daily أو weekly أو monthly",
  source_invalid: "مصدر الميعاد مش معروف",
  remind_invalid: "التذكير قبلها لازم دقايق صحيحة من ٠ لـ١٠٠٨٠",
  place_too_long: "اسم المكان طويل أوي (١٢٠ حرف بالكتير)",
  status_invalid: "الحالة لازم upcoming أو done أو cancelled",
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
