import { assertAlmostEquals, assertEquals, assertThrows } from "jsr:@std/assert@1";
import { convertTrip, homeEquivalent, localTimeOf } from "./tripFx.ts";

Deno.test("الرجوع والذهاب بيرجعوا لنفس المبلغ جوّه ٠.٠١", () => {
  const back = homeEquivalent(convertTrip(100, 3.67), 3.67);
  assertAlmostEquals(back, 100, 0.01);
});
Deno.test("التقريب لمنزلتين عشريتين", () => {
  assertEquals(convertTrip(1.234, 1), 1.23);
  assertEquals(convertTrip(1.236, 1), 1.24);
  assertEquals(homeEquivalent(10, 3), 3.33);
});
Deno.test("المبلغ صفر بيرجع صفر", () => {
  assertEquals(convertTrip(0, 3.67), 0);
  assertEquals(homeEquivalent(0, 3.67), 0);
});
Deno.test("سعر صفر أو سالب أو NaN بيرمي RangeError", () => {
  assertThrows(() => convertTrip(10, 0), RangeError);
  assertThrows(() => convertTrip(10, -1), RangeError);
  assertThrows(() => convertTrip(10, NaN), RangeError);
  assertThrows(() => homeEquivalent(10, 0), RangeError);
  assertThrows(() => homeEquivalent(10, -2), RangeError);
  assertThrows(() => homeEquivalent(10, NaN), RangeError);
});
Deno.test("الوقت المحلي مع +180", () => {
  assertEquals(localTimeOf("2026-11-22T10:00:00Z", 180), "13:00");
});
Deno.test("الوقت المحلي مع -300", () => {
  assertEquals(localTimeOf("2026-11-22T10:00:00Z", -300), "05:00");
});
Deno.test("الوقت المحلي بيعدّي منتصف الليل (wrap)", () => {
  assertEquals(localTimeOf("2026-11-22T22:30:00Z", 180), "01:30");
  assertEquals(localTimeOf("2026-11-22T02:00:00Z", -300), "21:00");
});
