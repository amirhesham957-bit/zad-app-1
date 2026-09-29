import { assertEquals } from "jsr:@std/assert@1";
import { needsCheckIn, rateConfidence } from "../_shared/consumptionRate.ts";

// الفجوة ٧: لبن ١ ← ٠ في ١٧.٦ ساعة (٢٠٢٦-٠٨-١٧) بقى ليه معدل تقريبي ١.٣٦ في اليوم.
Deno.test("rateConfidence: one purchase cycle is an approximate rate, not an unknown one", () => {
  assertEquals(rateConfidence(1.36, false), "approximate");
  assertEquals(rateConfidence(0.9, true), "known");
  assertEquals(rateConfidence(null, false), "unknown");
  assertEquals(rateConfidence(0, true), "unknown");
});

Deno.test("needsCheckIn: an approximate rate asks before the item runs out", () => {
  // ٢ علب بمعدل ١.٣٦ في اليوم = أقل من يومين → يسأل، حتى والمعدل تقريبي.
  assertEquals(needsCheckIn(3, 1, 1.36), false);
  assertEquals(needsCheckIn(2.5, 1, 1.36), true);
  assertEquals(needsCheckIn(10, null, 0.13), false);
  assertEquals(needsCheckIn(2, null, null), true, "under the default threshold of 2");
  assertEquals(needsCheckIn(5, 1, null), false, "no rate, above the threshold");
});
