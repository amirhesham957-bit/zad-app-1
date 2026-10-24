// الحارة الحرجة (ZAD_PLAN ١.٣، قرار المالك ٢٤/١٠): الجرعات، المواعيد، تذكيرات العميل، أمان الأولاد،
// وتنبيه ولي الأمر بجرعة فاتت — مافيش سقف ولا هدوء ولا مسافة ولا يوم مزحوم ولا ظرف بيمسكهم. ولو
// الموديل وقع بيتقالوا بنص ثابت (momentFallback). الاختبار ده بيفشل لو أي حارس من دول اتغيّر ومسك
// نوع حرج، من أي مصدر: اللحظات الصوتية أو مهام العقل.
import { assert, assertEquals } from "jsr:@std/assert@1";
import { dailyCapDecision, pacingDecision, postponeForQuietHours } from "./shared.ts";
import {
  DOSE_MOMENTS, FAMILY_ZONE_MOMENTS, momentGate, NEVER_HELD_MOMENTS, tooSoonAfterLast, UNCOUNTED_MOMENTS,
} from "./voiceMoments.ts";

const CRITICAL_MOMENTS = [...DOSE_MOMENTS, "appointment_soon", ...FAMILY_ZONE_MOMENTS, "family_dose_missed"];
/** مهام: تذكير طلبه العميل («فكّرني») ومتابعة الدوا. */
const CRITICAL_TASKS = ["reminder", "med_followup"];

const TZ = "Africa/Cairo";
const NIGHT = Date.parse("2026-10-24T00:30:00Z"); // ٣:٣٠ الفجر القاهرة
const crowded = Array.from({ length: 8 }, (_, i) => ({
  kind: i % 2 ? "spending_ahead" : "goal_review",
  at: new Date(NIGHT - (i + 1) * 60_000).toISOString(),
}));

Deno.test("every critical moment is never held", () => {
  for (const m of CRITICAL_MOMENTS) assert(NEVER_HELD_MOMENTS.has(m), m);
});

Deno.test("a critical moment goes out at 3 a.m., over the cap, on a busy day, in an emergency", () => {
  for (const m of CRITICAL_MOMENTS) {
    for (const mode of ["normal", "recovery", "exceptional"] as const) {
      assertEquals(momentGate(m, 3, 99, 9, mode), null, `${m} / ${mode}`);
    }
  }
});

Deno.test("a critical moment does not wait behind the last message, and does not count against the cap", () => {
  for (const m of CRITICAL_MOMENTS) {
    assertEquals(tooSoonAfterLast(m, NIGHT - 60_000, NIGHT), false, m);
    assert(UNCOUNTED_MOMENTS.includes(m), m);
  }
});

Deno.test("a critical task skips quiet hours, pacing and the daily cap", () => {
  for (const k of CRITICAL_TASKS) {
    assertEquals(postponeForQuietHours(k, TZ, NIGHT), null, k);
    assertEquals(pacingDecision(k, false, crowded, NIGHT), { action: "deliver" }, k);
    assertEquals(dailyCapDecision(k, crowded, TZ, NIGHT), { action: "deliver" }, k);
  }
});

Deno.test("an ordinary proactive task is still held at night — the contract is not «nothing is held»", () => {
  assert(postponeForQuietHours("spending_ahead", TZ, NIGHT) !== null);
  assert(momentGate("weekly_money_story", 3, 0) !== null);
});
