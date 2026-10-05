// إيقاع النوم (الشريحة ٣٧): ساعات الهدوء من نافذة العميل، بحدودها، والأداة اليدوية.

import { assert, assertEquals } from "jsr:@std/assert@1";
import { DEFAULT_QUIET, isQuietHourIn, postponeForQuietHours, quietEndsAt, quietWindowOf } from "./shared.ts";
import { momentGate } from "./voiceMoments.ts";
import { freshContext, MUTATING_TOOLS, validateSetSleepWindow } from "./validators.ts";
import { intentToolHints } from "./specialists.ts";

Deno.test("the window: bedtime's hour to the hour after waking; nonsense or night shifts keep 23–7", () => {
  assertEquals(quietWindowOf("23:40:00", "07:10:00"), { start: 23, end: 8 });
  assertEquals(quietWindowOf("00:30", "06:00"), { start: 0, end: 6 });
  assertEquals(quietWindowOf(null, "07:00"), DEFAULT_QUIET);
  assertEquals(quietWindowOf("09:00", "17:00"), DEFAULT_QUIET); // شغل ليلي
  assertEquals(quietWindowOf("23:00", "14:00"), DEFAULT_QUIET);
});

Deno.test("quiet hours follow the window, across midnight or after it", () => {
  const late = { start: 0, end: 9 };
  assertEquals([23, 0, 8, 9].map((h) => isQuietHourIn(h, late)), [false, true, true, false]);
  const early = { start: 21, end: 6 };
  assertEquals([20, 21, 2, 6].map((h) => isQuietHourIn(h, early)), [false, true, true, false]);
});

Deno.test("a proactive task waits for this customer's waking hour, not 7", () => {
  // ٢١:٣٠ UTC = ٠٠:٣٠ القاهرة.
  const at = Date.parse("2026-09-29T21:30:00Z");
  assertEquals(quietEndsAt("Africa/Cairo", at, { start: 0, end: 9 }), "2026-09-30T06:00:00.000Z");
  assertEquals(postponeForQuietHours("bill_reminder", "Africa/Cairo", at, { start: 0, end: 9 }), "2026-09-30T06:00:00.000Z");
  // من غير نافذة: نفس السلوك القديم (٧ الصبح).
  assertEquals(postponeForQuietHours("bill_reminder", "Africa/Cairo", at), "2026-09-30T04:00:00.000Z");
  // ٢٢:٠٠ القاهرة: هادي لصاحب النوم ٢١، مش هادي للافتراضي.
  const ten = Date.parse("2026-09-29T19:00:00Z");
  assertEquals(postponeForQuietHours("bill_reminder", "Africa/Cairo", ten), null);
  assertEquals(postponeForQuietHours("bill_reminder", "Africa/Cairo", ten, { start: 21, end: 6 }), "2026-09-30T03:00:00.000Z");
});

Deno.test("voice moments hold for the window; doses never", () => {
  assertEquals(momentGate("weekly_money_story", 8, 0, 0, "normal", { start: 0, end: 9 }), "quiet_hours");
  assertEquals(momentGate("weekly_money_story", 8, 0, 0, "normal"), null);
  assertEquals(momentGate("dose_due", 3, 0, 0, "normal", { start: 0, end: 9 }), null);
});

Deno.test("set_sleep_window: HH:MM inside the bounds, or clear", async () => {
  const ok = async (i: Record<string, unknown>) => (await validateSetSleepWindow(i, {}, freshContext("u"))).ok;
  assertEquals(await ok({ bed: "23:30", wake: "07:00" }), true);
  assertEquals(await ok({ bed: "01:15", wake: "09:00" }), true);
  assertEquals(await ok({ clear: true }), true);
  assertEquals(await ok({ bed: "11 بالليل", wake: "07:00" }), false);
  assertEquals(await ok({ bed: "09:00", wake: "17:00" }), false);
  assertEquals(await ok({ bed: "03:30", wake: "10:00" }), false);
  assertEquals(await ok({ bed: "23:00", wake: "12:30" }), false);
  assert(MUTATING_TOOLS.includes("set_sleep_window"));
});

Deno.test("saying when one sleeps offers the tool", () => {
  for (const m of ["أنا بنام الساعة ١ وبصحى ٩", "ماتبعتليش حاجة قبل ٨ الصبح", "ماتصحينيش بالإشعارات"]) {
    assert(intentToolHints(m).includes("set_sleep_window"), m);
  }
  assert(!intentToolHints("نمت كويس امبارح").includes("set_sleep_window"));
});
