// The decision on a life event card (ZAD_PLAN ٢.٨): one place for both doors — the app's card (zad-brain
// life_event_decide) and the Telegram buttons (zad-telegram-bot). «أيوة» makes a reminded appointment in
// zad_appointments; «لأ», a past date or a result makes it dismissed. One answer per event.

import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";

export type LifeKind = "appointment" | "government" | "result_ready" | "shipment";

const MEDICAL = /مستشف|عياد|معمل|مختبر|تحليل|تحاليل|أشع|اشع|سونار|رنين|أسنان|اسنان|دكتور|طبيب|صحتي|موعد طبي|hospital|clinic|lab|radiology|dental/i;

/** Medical or an errand, as zad_appointments.kind has it. */
export function appointmentKindFor(ev: { kind: LifeKind; title: string; place: string | null }): "medical" | "errand" {
  return ev.kind === "appointment" && MEDICAL.test(`${ev.title} ${ev.place ?? ""}`) ? "medical" : "errand";
}

/** التذكير قبلها بكام دقيقة: موعد ساعتين، حكومي (موعد نهائي) يوم، استلام شحنة ساعة. */
export function remindMinutesFor(kind: LifeKind): number {
  return kind === "government" ? 1440 : kind === "shipment" ? 60 : 120;
}

/** «أيوة/لأ» على كارت حدث حياة: أيوة ⇐ ميعاد بتذكير في zad_appointments (والمتابعة بعده من تحية الصبح). */
export async function decideLifeEvent(sb: SupabaseClient, userId: string, id: string, yes: boolean): Promise<{ ok: boolean; status: string; appointment_id?: string }> {
  const { data: ev } = await sb.from("zad_life_events")
    .select("id,kind,title,event_at,place,action_hint,link,status,appointment_id")
    .eq("id", id).eq("user_id", userId).maybeSingle();
  const row = ev as {
    id: string; kind: LifeKind; title: string; event_at: string | null;
    place: string | null; action_hint: string | null; link: string | null; status: string; appointment_id: string | null;
  } | null;
  if (!row) return { ok: false, status: "not_found" };
  if (row.status !== "proposed") return { ok: true, status: row.status, ...(row.appointment_id ? { appointment_id: row.appointment_id } : {}) };
  const decidedAt = new Date().toISOString();
  if (!yes || !row.event_at || Date.parse(row.event_at) <= Date.now() || row.kind === "result_ready") {
    await sb.from("zad_life_events").update({ status: "dismissed", decided_at: decidedAt }).eq("id", id).eq("user_id", userId).eq("status", "proposed");
    return { ok: true, status: "dismissed" };
  }
  const notes = [row.action_hint, row.link].filter(Boolean).join(" — ").slice(0, 500) || null;
  const { data: appt, error } = await sb.from("zad_appointments").insert({
    user_id: userId,
    title: row.title,
    kind: appointmentKindFor(row),
    starts_at: row.event_at,
    place_label: row.place,
    remind_minutes_before: remindMinutesFor(row.kind),
    recurrence: "once",
    source: "notification",
    notes,
  }).select("id").maybeSingle();
  if (error || !appt) {
    console.error("[life_event_decide] appointment insert failed:", error?.message ?? "no row");
    return { ok: false, status: "appointment_failed" };
  }
  const apptId = (appt as { id: string }).id;
  await sb.from("zad_life_events").update({ status: "confirmed", appointment_id: apptId, decided_at: decidedAt })
    .eq("id", id).eq("user_id", userId).eq("status", "proposed");
  return { ok: true, status: "confirmed", appointment_id: apptId };
}
