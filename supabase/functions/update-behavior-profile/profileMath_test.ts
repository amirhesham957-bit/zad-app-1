import { assertAlmostEquals, assertEquals } from "jsr:@std/assert@1";
import { observedWeeks } from "./profileMath.ts";

const NOW = Date.parse("2026-11-06T00:00:00Z");

Deno.test("a new account divides by at least one week, not by 90 days", () => {
  // حساب المالك: ٥٠ في أيام ⇒ ٥٠ في الأسبوع، مش ٣٫٨٩.
  assertEquals(observedWeeks("2026-11-03T00:00:00Z", NOW), 1);
  assertEquals(50 / observedWeeks("2026-11-03T00:00:00Z", NOW), 50);
});

Deno.test("a month of history is about four weeks", () => {
  assertAlmostEquals(observedWeeks("2026-10-07T00:00:00Z", NOW), 30 / 7, 1e-9);
});

Deno.test("an old account is capped at the 90-day window", () => {
  assertAlmostEquals(observedWeeks("2025-01-01T00:00:00Z", NOW), 90 / 7, 1e-9);
  assertAlmostEquals(observedWeeks(null, NOW), 90 / 7, 1e-9);
  assertAlmostEquals(observedWeeks("not a date", NOW), 90 / 7, 1e-9);
});
