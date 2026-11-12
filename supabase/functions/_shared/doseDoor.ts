// باب واحد لجرعات الدوا وكتم سؤال المخزن (ZAD_PLAN ٣.٤).
//
// قبل كده البوت كان بيكتب بنفسه في zad_pharmacy_doses («مخدتهاش»)، zad_dose_snoozes («فكّرني بعدين»)،
// وzad_memory («بطّل تسألني»)، والعقل له طريقه هو — فاللي البوت يسجله ممكن يختلف عن اللي العقل يعرفه.
// دلوقتي الكتابة دي في الملف ده بس، والعقل هو اللي بيناديه (أدوات answer_dose_reminder و mute_checkin
// في zad-brain، اللي البوت بيوصلها بـagent_execute زي باقي أدواته). الحارس: _schema/one_writer_test.ts.

import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";

/** دقايق التأجيل لما العميل يدوس «فكّرني بعدين» — نفس الرقم في SQL (zad_dose_snoozes). */
export const DOSE_SNOOZE_MINUTES = 15;

export type DoseAction = "taken" | "skipped" | "snooze";

export function isDoseAction(v: unknown): v is DoseAction {
  return v === "taken" || v === "skipped" || v === "snooze";
}

/**
 * خانة كل دوا في تذكير الجرعة. تذكير المجموعة (20260926120000) بيحمل `facts.slots`
 * — دوائين بينهم نص ساعة في رسالة واحدة، وكل واحد لازم يتسجّل في خانته هو عشان
 * الفهرس الفريد (user_id, item_id, scheduled_at) ومولّد التذكيرات يشوفوه متجاوب عليه.
 * التذكير القديم مافيهوش slots، فكل الأدوية بتاخد `fallback` (facts.scheduled_at).
 */
export function doseSlots(facts: Record<string, unknown> | null | undefined, fallback: string): (itemId: string) => string {
  const map = new Map<string, string>();
  const slots = Array.isArray(facts?.slots) ? facts!.slots as unknown[] : [];
  for (const s of slots) {
    const o = s as { item_id?: unknown; scheduled_at?: unknown } | null;
    if (typeof o?.item_id === "string" && typeof o?.scheduled_at === "string") map.set(o.item_id, o.scheduled_at);
  }
  return (itemId) => map.get(itemId) ?? fallback;
}

/**
 * «أخدتها» على جرعة متسجلة قبل كده — تذكيرين لنفس الخانة، أو ضغطة على رسالة قديمة. الـRPC
 * مابيعدّهاش مرتين (duplicate) بس البوت كان بيرد «اتسجلت جرعة … ✅» كل مرة: يوم ٢٠٢٦-١٠-٠١
 * خمس رسايل تأكيد على تلات جرعات، فبانت كأن الدوا اتسجل خمس مرات.
 */
export function doseAlreadyReply(names: readonly string[]): string {
  const label = [...new Set(names)].join(" و");
  return `جرعة ${label} دي متسجلة قبل كده ✅ — مش هتتحسب مرتين.`;
}

/**
 * «أجّل جرعة البنادول ربع ساعة» بالكلام (ZAD_PLAN ١٠.٢أ) — نفس صف «فكّرني بعدين»، بس الخانة محسوبة من
 * مواعيد الدوا مش من تذكير. الدوا لازم يكون بتاع العميل (اتقرا بـuser_id قبلها في العقل)، والدقايق ٥–٢٤٠.
 */
export async function snoozeDose(
  sb: SupabaseClient, userId: string, itemId: string, scheduledAt: string, minutes: number,
): Promise<{ ok: true; until: string } | { ok: false; reason: string }> {
  const until = new Date(Date.now() + minutes * 60_000).toISOString();
  const { data, error } = await sb.from("zad_dose_snoozes").upsert(
    { user_id: userId, item_id: itemId, scheduled_at: scheduledAt, snooze_until: until },
    { onConflict: "user_id,item_id,scheduled_at" },
  ).select("item_id");
  if (error) return { ok: false, reason: error.message };
  if (!data?.length) return { ok: false, reason: "التأجيل ما اتكتبش" };
  return { ok: true, until };
}

// ── تسوية تذكير الجرعة: زرار أو كلام، نفس المسار (٢٠٢٦-٠٩-١٩، ومخدتهاش ٢٠٢٦-٠٩-٢٥) ──
//
// الترتيب مقصود بالحرف: بنقرا اللحظة من `zad_voice_moments` (مصدر الحقيقة الوحيد لأسماء
// الأدوية ومواعيدها — مفيش أي اسم بييجي من كلام الموديل)، بنكتب في الداتابيز، وبنرد على
// العميل **بس** لو الكتابة نجحت. أي فشل بيقول له صراحةً إنها ماتسجلتش.
export async function settleDoseReminder(sb: SupabaseClient, userId: string, momentId: string, action: DoseAction): Promise<string> {
  const { data: momentRow } = await sb.from("zad_voice_moments")
    .select("id,user_id,moment,facts")
    .eq("id", momentId).eq("user_id", userId).maybeSingle();
  const moment = momentRow as { moment: string; facts: Record<string, unknown> } | null;
  if (!moment) {
    return "التذكير ده مش موجود عندي — افتح صفحة الصيدلية في التطبيق وسجّل الجرعة من هناك.";
  }
  const itemIds = Array.isArray(moment.facts?.item_ids)
    ? (moment.facts.item_ids as unknown[]).map(String).filter((v) => /^[0-9a-fA-F-]{36}$/.test(v))
    : [];
  const scheduledAt = typeof moment.facts?.scheduled_at === "string" ? moment.facts.scheduled_at : null;
  if (itemIds.length === 0 || !scheduledAt) {
    return "التذكير ده قديم ومش مربوط بدوا محدد — سجّل الجرعة من صفحة الصيدلية في التطبيق.";
  }
  // تذكير المجموعة (20260926120000) فيه خانة كل دوا لوحده؛ القديم فيه خانة واحدة للكل.
  const slotOf = doseSlots(moment.facts, scheduledAt);

  if (action === "snooze") {
    // التأجيل بيتكتب في جدول، مش في الذاكرة: الكرون هو اللي بيقرا منه فبيسكت عن
    // نفس الجرعة لحد ما الوقت يعدّي، وبعدها بيبعت تذكير واحد جديد.
    const until = new Date(Date.now() + DOSE_SNOOZE_MINUTES * 60_000).toISOString();
    const { error: snoozeErr } = await sb.from("zad_dose_snoozes").upsert(
      itemIds.map((itemId) => ({
        user_id: userId, item_id: itemId, scheduled_at: slotOf(itemId), snooze_until: until,
      })),
      { onConflict: "user_id,item_id,scheduled_at" },
    );
    if (snoozeErr) {
      console.error("[dose] snooze failed:", snoozeErr.message);
      return "معلش، مقدرتش أأجّل التذكير — هفضل أفكّرك زي ما هو.";
    }
    return `تمام، هسكت ${DOSE_SNOOZE_MINUTES} دقيقة وأفكّرك تاني.`;
  }

  const names: string[] = [];
  const already: string[] = [];
  const failed: string[] = [];
  if (action === "skipped") {
    // صف `skipped` في نفس الخانة الزمنية: الفهرس الفريد (user_id, item_id, scheduled_at)
    // بيخليه الإجابة الوحيدة على الجرعة دي، و`zad_enqueue_missed_doses` بيعتبره إجابة
    // فبيبطّل «فاتتك الجرعة». units = 0 لأن مفيش حاجة خرجت من العلبة. الـinsert مش upsert
    // عن قصد: الفهرس جزئي (WHERE scheduled_at IS NOT NULL) وON CONFLICT مايقدرش يستنتجه؛
    // وتكرار (23505) معناه إن الجرعة اتجاوب عليها قبل كده — مش فشل.
    const { data: items } = await sb.from("zad_pharmacy_items").select("id,name").eq("user_id", userId).in("id", itemIds);
    const nameOf = new Map(((items ?? []) as Array<{ id: string; name: string }>).map((i) => [i.id, i.name]));
    for (const itemId of itemIds) {
      const { error } = await sb.from("zad_pharmacy_doses").insert({
        user_id: userId, item_id: itemId, scheduled_at: slotOf(itemId), status: "skipped", units: 0,
      });
      if (error && (error as { code?: string }).code !== "23505") {
        console.error("[dose] skip failed:", itemId, error.message);
        failed.push(itemId);
      } else {
        names.push(String(nameOf.get(itemId) ?? "الدوا"));
      }
    }
  } else {
    for (const itemId of itemIds) {
      const { data: result, error } = await sb.rpc("zad_log_pharmacy_dose_atomic", {
        p_user: userId,
        p_item: itemId,
        // الخانة الزمنية بتاعة التذكير نفسه، مش دلوقتي: الفهرس الفريد
        // (user_id, item_id, scheduled_at) بيخلي ضغطتين على نفس الزر عملية واحدة،
        // وبيخلي الكرون يشوف إن الجرعة دي بالذات اتاخدت.
        p_scheduled_at: slotOf(itemId),
        p_taken_at: new Date().toISOString(),
      });
      const r = result as { ok?: boolean; duplicate?: boolean; name?: string; remaining_quantity?: number } | null;
      if (error || !r?.ok) {
        console.error("[dose] log failed:", itemId, error?.message ?? JSON.stringify(r));
        failed.push(itemId);
      } else if (r.duplicate) {
        // الخانة دي اتسجلت قبل كده (تذكيرين لنفس الجرعة، أو ضغطة تانية): مش جرعة جديدة.
        already.push(String(r.name ?? "الدوا"));
      } else {
        names.push(String(r.name ?? "الدوا"));
      }
    }
  }
  if (names.length === 0 && already.length > 0 && failed.length === 0) {
    return doseAlreadyReply(already);
  }
  if (names.length === 0) {
    return "معلش، مقدرتش أسجّل ده دلوقتي — ماتسجلش، جرّب من صفحة الصيدلية في التطبيق.";
  }
  // التذكير ده خلص شغله: مايتبعتش تاني ولا يتحسب كجرعة فايتة.
  await sb.from("zad_voice_moments")
    .update({ status: "sent", error: null })
    .eq("id", momentId).eq("user_id", userId);
  const label = names.join(" و");
  const partial = failed.length > 0 ? " — بس فيه دوا مقدرتش أسجله، راجع صفحة الصيدلية." : "";
  return action === "skipped"
    ? `تمام، سجّلت إنك مخدتش جرعة ${label} المرة دي، ومش هعاتبك عليها. الجرعة الجاية هفكّرك بيها في ميعادها${partial}`
    : failed.length > 0
      ? `اتسجلت جرعة ${label} ✅${partial}`
      : `اتسجلت جرعة ${label} ✅ تمام عليك.`;
}


/** كتم سؤال المخزن بالليل [days] يوم («🔕 بطّل تسألني»). صف ذاكرة واحد بيتجدد، مش صف كل ضغطة. */
export async function muteCheckin(sb: SupabaseClient, userId: string, days = 30): Promise<boolean> {
  const until = new Date(Date.now() + days * 86_400_000).toISOString();
  const note = "العميل طلب يبطّل سؤال المخزون بالليل على تليجرام — مايتسألش لحد ما هو يطلب";
  const { data: existing } = await sb.from("zad_memory").select("id")
    .eq("user_id", userId).eq("scope", "dismissal").eq("subject_kind", "checkin").limit(1).maybeSingle();
  const { error } = existing
    ? await sb.from("zad_memory").update({ suppress_until: until, note, last_seen: new Date().toISOString() })
      .eq("id", (existing as { id: string }).id)
    : await sb.from("zad_memory").insert({
      user_id: userId, scope: "dismissal", subject_kind: "checkin", suppress_until: until, confidence: 0.9, note,
    });
  if (error) console.error("[checkin_off] write failed:", error.message);
  return !error;
}
