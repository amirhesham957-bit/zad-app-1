import { assertEquals } from "jsr:@std/assert@1";
import { isQuietHour, postponeForQuietHours, quietEndsAt } from "./shared.ts";
import { DAILY_VOICE_ALERT_CAP, momentGate, processVoiceMoments } from "./voiceMoments.ts";

// الفجوة ١٠ (قرار المالك ٢٠٢٦-٠٩-٢٩): هدوء من ١١ بالليل لـ٧ الصبح، ٥ في اليوم، الجرعات مستثناة تماماً.
// القاهرة في سبتمبر ٢٠٢٦ = UTC+3.

Deno.test("quiet hours are 23:00 up to 07:00, local", () => {
  assertEquals([22, 23, 0, 6, 7].map(isQuietHour), [false, true, true, true, false]);
});

Deno.test("quietEndsAt: 07:00 local — tomorrow before midnight, today after it", () => {
  assertEquals(quietEndsAt("Africa/Cairo", Date.parse("2026-09-29T20:30:00Z")), "2026-09-30T04:00:00.000Z"); // 23:30
  assertEquals(quietEndsAt("Africa/Cairo", Date.parse("2026-09-29T21:30:00Z")), "2026-09-30T04:00:00.000Z"); // 00:30
  assertEquals(quietEndsAt("Asia/Riyadh", Date.parse("2026-09-30T03:59:00Z")), "2026-09-30T04:00:00.000Z"); // 06:59
  assertEquals(quietEndsAt("Africa/Cairo", Date.parse("2026-09-29T12:00:00Z")), null); // 15:00
});

Deno.test("a proactive task waits for the morning; medication and the customer's own reminders do not", () => {
  const night = Date.parse("2026-09-29T21:30:00Z");
  assertEquals(postponeForQuietHours("bill_reminder", "Africa/Cairo", night), "2026-09-30T04:00:00.000Z");
  assertEquals(postponeForQuietHours("med_followup", "Africa/Cairo", night), null);
  assertEquals(postponeForQuietHours("reminder", "Africa/Cairo", night), null);
  assertEquals(postponeForQuietHours("bill_reminder", "Africa/Cairo", Date.parse("2026-09-29T12:00:00Z")), null);
});

Deno.test("momentGate: doses and appointments always go; the rest waits for quiet hours and the daily cap", () => {
  assertEquals(momentGate("dose_due", 2, 99), null);
  assertEquals(momentGate("dose_missed_again", 3, DAILY_VOICE_ALERT_CAP), null);
  assertEquals(momentGate("appointment_soon", 6, 99), null);
  assertEquals(momentGate("weekly_money_story", 23, 0), "quiet_hours");
  assertEquals(momentGate("good_night", 23, 0), null, "good night opens the quiet window");
  assertEquals(momentGate("good_night", 23, DAILY_VOICE_ALERT_CAP), "daily_cap");
  assertEquals(momentGate("morning_greeting", 10, DAILY_VOICE_ALERT_CAP - 1), null);
  assertEquals(momentGate("morning_greeting", 10, DAILY_VOICE_ALERT_CAP), "daily_cap");
});

// المعالج نفسه: لحظة ممسوكة بتتخطى قبل ما تصرف نداء موديل، والجرعة في نفس اللحظة بتتقال.
function fakeSb(moment: string) {
  const updates: Array<Record<string, unknown>> = [];
  const tables: Record<string, Array<Record<string, unknown>>> = {
    zad_voice_moments: [{ id: "q1", user_id: "u1", moment, status: "pending", attempts: 0, created_at: new Date().toISOString(),
      facts: { item_name: "كونكور", scheduled_at: "2026-09-29T21:00:00Z", dose_log_id: "d1", tone: "proud", spent: 1, last_week_spent: 2 } }],
    zad_dose_log: [{ id: "d1", taken_at: null, pharmacy_item_id: "p1", scheduled_at: "2026-09-29T21:00:00Z" }],
    zad_pharmacy_doses: [],
    zad_users: [{ id: "u1", country: "EG", name: "أمير" }],
  };
  const from = (table: string) => {
    const q: Record<string, unknown> = {
      select: () => q, eq: () => q, gte: () => q, or: () => q, order: () => q,
      limit: () => Promise.resolve({ data: tables[table] ?? [], error: null }),
      maybeSingle: () => Promise.resolve({ data: (tables[table] ?? [])[0] ?? null, error: null }),
      then: (resolve: (v: unknown) => unknown) => resolve({ data: tables[table] ?? [], error: null }),
      update: (values: Record<string, unknown>) => ({ eq: () => {
        if (values.status === "sending") return { or: () => ({ select: () => Promise.resolve({ data: [{ id: "q1" }], error: null }) }) };
        updates.push(values);
        return Promise.resolve({ error: null });
      } }),
    };
    return q;
  };
  // deno-lint-ignore no-explicit-any
  return { sb: { from } as any, updates };
}

for (const [moment, expected] of [["weekly_money_story", "quiet_hours"], ["dose_missed", "sent"]] as const) {
  Deno.test(`at 00:30 Cairo, ${moment} is ${expected}`, async () => {
    const { sb, updates } = fakeSb(moment);
    let composed = 0;
    await processVoiceMoments(sb, {
      compose: () => { composed++; return Promise.resolve('{"title":"💊 كونكور","text":"خد الكونكور","speech":"خد الكونكور"}'); },
      pushDevice: () => Promise.resolve("sent"),
      pushTelegram: () => Promise.resolve("delivered"),
      now: () => Date.parse("2026-09-29T21:30:00Z"),
      timeZoneOf: () => Promise.resolve("Africa/Cairo"),
    });
    const last = updates.at(-1) ?? {};
    if (expected === "quiet_hours") {
      assertEquals([last.status, last.error, composed], ["skipped", "quiet_hours", 0]);
    } else {
      assertEquals(last.status, "sent");
    }
  });
}
