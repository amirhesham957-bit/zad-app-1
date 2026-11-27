import { assertEquals } from "jsr:@std/assert";
import { eventsToBusy } from "./memberBusy.ts";
import { bestGatherings } from "./gatheringTime.ts";

const W = "2026-11-27T00:00:00+02:00";

Deno.test("eventsToBusy: دقايق من أول الأسبوع والمدة الافتراضية ساعة", () => {
  const b = eventsToBusy([{ member: "a", startIso: "2026-11-27T10:00:00+02:00" }], W);
  assertEquals(b, [{ member: "a", start: 600, end: 660 }]);
});

Deno.test("eventsToBusy: بيقص برا الأسبوع ويتجاهل الفاسد", () => {
  const b = eventsToBusy([
    { member: "a", startIso: "2026-11-26T23:00:00+02:00", endIso: "2026-11-27T01:00:00+02:00" },
    { member: "b", startIso: "bad" },
    { member: "c", startIso: "2026-12-05T10:00:00+02:00" },
    { member: "d", startIso: "2026-11-27T10:00:00+02:00", endIso: "2026-11-27T09:00:00+02:00" },
  ], W);
  assertEquals(b, [{ member: "a", start: 0, end: 60 }]);
});

Deno.test("eventsToBusy يغذي bestGatherings: الميعاد المشغول مابيتختارش لليوم ده", () => {
  const busy = eventsToBusy([
    { member: "a", startIso: "2026-11-27T18:00:00+02:00", durationMinutes: 120 },
  ], W);
  const s = bestGatherings(busy, {
    members: ["a", "b"],
    minutes: 60,
    earliest: 18 * 60,
    latest: 20 * 60,
  }, 1);
  // اليوم ٠ كله مشغول لـa في الفترة دي، فالأحسن ييجي في يوم تاني وبالحضور الكامل
  assertEquals(s[0].missing.length, 0);
  assertEquals(s[0].start >= 1440, true);
});
