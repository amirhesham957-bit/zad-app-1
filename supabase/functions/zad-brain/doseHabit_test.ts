import { assertEquals } from "jsr:@std/assert@1";
import { doseHabitFor, type HabitDose, type HabitItem, habitKey, shiftClock, spokenClock } from "./doseHabit.ts";
import { askedThisMorning } from "./curiosity.ts";

const TZ = "Africa/Cairo"; // UTC+3 until the last Thursday of October 2026 (summer time)
const ITEM: HabitItem = { id: "m1", name: "أوجمنتين", for_person: null, dose_times: "02:00,14:00" };

// [n] doses of the 14:00 Cairo slot (11:00 UTC on 10–22 October, summer time), each taken [lateMin[i]] minutes late.
function doses(lateMin: number[], slotUtc = "11:00"): HabitDose[] {
  return lateMin.map((late, i) => {
    const day = String(10 + i).padStart(2, "0");
    const s = Date.parse(`2026-10-${day}T${slotUtc}:00Z`);
    return { item_id: "m1", scheduled_at: new Date(s).toISOString(), taken_at: new Date(s + late * 60_000).toISOString(), status: "taken" };
  });
}

// The live account, 2026-11-01: 13 doses of the 14:00 slot, median 338 minutes late.
const MEASURED = [300, 320, 330, 335, 338, 338, 338, 340, 345, 360, 400, 645, 20];

Deno.test("the measured habit is found: 14:00 taken around 19:45", () => {
  const h = doseHabitFor(doses(MEASURED), [ITEM], TZ, new Set());
  assertEquals(h?.key, habitKey("m1", "14:00"));
  assertEquals(h?.scheduled, "14:00");
  assertEquals(h?.suggested, "19:45");
  assertEquals(h?.doses, 13);
  assertEquals(h?.question, "لاحظت إن «أوجمنتين» بتاع 2 الضهر بيتاخد عادةً على 7:45 بالليل — أنقل تذكيره لـ7:45 بالليل؟ ولو الدكتور محدد الميعاد نسيبه زي ما هو");
  const c = h?.facts.curiosity as { tool: string; record: string; kind: string };
  assertEquals(c.tool, "update_pharmacy_item");
  assertEquals(c.kind, "dose_habit");
  // Only the late slot moves; the 02:00 dose keeps its time.
  assertEquals(c.record.includes("dose_times = «02:00,19:45»"), true);
});

Deno.test("on time most days is not a habit", () => {
  assertEquals(doseHabitFor(doses([10, 20, 25, 30, 40, 200]), [ITEM], TZ, new Set()), null);
});

Deno.test("late but too few doses to call it a habit", () => {
  assertEquals(doseHabitFor(doses([300, 300, 300, 300]), [ITEM], TZ, new Set()), null);
});

Deno.test("median late but only half of them late — not steady enough", () => {
  // 5 of 7 late (71%) is steady; 4 of 8 (50%) is not, though the median (105) is past 90.
  assertEquals(doseHabitFor(doses([10, 10, 200, 200, 200, 200, 200]), [ITEM], TZ, new Set())?.key, habitKey("m1", "14:00"));
  assertEquals(doseHabitFor(doses([10, 10, 10, 10, 200, 200, 200, 200]), [ITEM], TZ, new Set()), null);
});

Deno.test("asked in the last 60 days ⇒ not again", () => {
  assertEquals(doseHabitFor(doses(MEASURED), [ITEM], TZ, new Set([habitKey("m1", "14:00")])), null);
});

Deno.test("the time was already changed, or the medicine is gone ⇒ nothing", () => {
  assertEquals(doseHabitFor(doses(MEASURED), [{ ...ITEM, dose_times: "02:00,19:00" }], TZ, new Set()), null);
  assertEquals(doseHabitFor(doses(MEASURED), [], TZ, new Set()), null);
});

Deno.test("skipped doses do not count as taken late", () => {
  const ds = doses(MEASURED).map((d) => ({ ...d, status: "skipped" }));
  assertEquals(doseHabitFor(ds, [ITEM], TZ, new Set()), null);
});

Deno.test("the slot is read on the account's clock", () => {
  // Same instants seen from Dubai (UTC+4) are 15:00 — not one of this medicine's times.
  assertEquals(doseHabitFor(doses(MEASURED), [ITEM], "Asia/Dubai", new Set()), null);
  // Across the change to winter time the 14:00 dose is 12:00 UTC, and still the same slot.
  const winter = doses([300, 300, 300], "11:00").concat(
    [1, 2, 3].map((d) => {
      const s = Date.parse(`2026-11-0${d}T12:00:00Z`);
      return { item_id: "m1", scheduled_at: new Date(s).toISOString(), taken_at: new Date(s + 300 * 60_000).toISOString(), status: "taken" };
    }),
  );
  assertEquals(doseHabitFor(winter, [ITEM], TZ, new Set())?.doses, 6);
});

Deno.test("a suggestion past midnight is not made", () => {
  assertEquals(shiftClock("21:00", 200), null);
  assertEquals(shiftClock("14:00", 338), "19:45");
});

Deno.test("clock words", () => {
  assertEquals(spokenClock("02:00"), "2 بالليل");
  assertEquals(spokenClock("09:30"), "9:30 الصبح");
  assertEquals(spokenClock("14:00"), "2 الضهر");
  assertEquals(spokenClock("16:15"), "4:15 العصر");
  assertEquals(spokenClock("00:00"), "12 بالليل");
});

Deno.test("the morning chat sees the tool and the instruction", () => {
  const h = doseHabitFor(doses(MEASURED), [ITEM], TZ, new Set())!;
  const sentAt = "2026-11-02T06:00:00Z";
  const asked = askedThisMorning({ sent_at: sentAt, facts: { daily_question: h.question, ...h.facts } }, Date.parse("2026-11-02T07:00:00Z"));
  assertEquals(asked?.kind, "curiosity");
  assertEquals(asked?.tool, "update_pharmacy_item");
  assertEquals(asked?.record?.includes("«02:00,19:45»"), true);
});
