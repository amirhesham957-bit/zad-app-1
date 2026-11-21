import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import {
  daysOfSupply,
  nextDose,
  localDate,
  reorderPoint,
  remainingUnits,
  shouldReorder,
} from "./pharmacyStock.ts";

Deno.test("pharmacyStock - basic scenario", () => {
  const i = {
    restockQty: 30,
    dosesTakenSince: 10,
    unitsPerDose: 1,
    timesPerDay: 2,
  };
  assertEquals(remainingUnits(i), 20);
  assertEquals(daysOfSupply(i), 10);
  assertEquals(reorderPoint(i), 10);
  assertEquals(shouldReorder(i), false);
});

Deno.test("pharmacyStock - should reorder", () => {
  const i = {
    restockQty: 30,
    dosesTakenSince: 21,
    unitsPerDose: 1,
    timesPerDay: 2,
  };
  assertEquals(remainingUnits(i), 9);
  assertEquals(shouldReorder(i), true);
  assertEquals(shouldReorder(i), true);
  
  const i2 = { ...i, dosesTakenSince: 40 };
  assertEquals(remainingUnits(i2), 0);
});

Deno.test("pharmacyStock - timesPerDay 0", () => {
  const i = {
    restockQty: 30,
    dosesTakenSince: 10,
    unitsPerDose: 1,
    timesPerDay: 0,
  };
  assertEquals(daysOfSupply(i), null);
  assertEquals(shouldReorder(i), false);
});

Deno.test("pharmacyStock - localDate", () => {
  assertEquals(localDate("2026-11-21T22:30:00Z", "Africa/Cairo"), "2026-11-22");
  assertEquals(localDate("2026-11-21T22:30:00Z", "UTC"), "2026-11-21");
});

Deno.test("pharmacyStock - nextDose today", () => {
  assertEquals(
    nextDose(["08:00", "20:00"], "2026-11-21T10:00:00Z", "Africa/Cairo"),
    { date: "2026-11-21", time: "20:00" },
  );
});

Deno.test("pharmacyStock - nextDose tomorrow", () => {
  assertEquals(
    nextDose(["08:00", "20:00"], "2026-11-21T19:00:00Z", "Africa/Cairo"),
    { date: "2026-11-22", time: "08:00" },
  );
});

Deno.test("pharmacyStock - nextDose year end", () => {
  assertEquals(
    nextDose(["09:00"], "2026-12-31T20:00:00Z", "Asia/Riyadh"),
    { date: "2027-01-01", time: "09:00" },
  );
});

Deno.test("pharmacyStock - nextDose different zones", () => {
  const times = ["08:00", "15:00"];
  const now = "2026-11-21T12:00:00Z";
  
  // Cairo (GMT+2) -> 14:00 local, next 15:00
  assertEquals(nextDose(times, now, "Africa/Cairo"), { date: "2026-11-21", time: "15:00" });
  
  // New York (GMT-5) -> 07:00 local, next 08:00
  assertEquals(nextDose(times, now, "America/New_York"), { date: "2026-11-21", time: "08:00" });
});

Deno.test("pharmacyStock - just after local midnight, today's doses are still ahead", () => {
  // 22:05Z = 00:05 on 22 Nov in Cairo.
  assertEquals(nextDose(["08:00"], "2026-11-21T22:05:00Z", "Africa/Cairo"), { date: "2026-11-22", time: "08:00" });
});

Deno.test("pharmacyStock - the night before a 23-hour DST day does not skip a date", () => {
  // 2027-03-14 is 23 hours long in New York. 04:30Z = 23:30 on 13 Mar local.
  assertEquals(nextDose(["08:00"], "2027-03-14T04:30:00Z", "America/New_York"), { date: "2027-03-14", time: "08:00" });
});

Deno.test("pharmacyStock - stock exactly at the reorder point reorders", () => {
  const i = { restockQty: 30, dosesTakenSince: 10, unitsPerDose: 1, timesPerDay: 2, leadTimeDays: 5, safetyDays: 5 };
  assertEquals(reorderPoint(i), 20);
  assertEquals(remainingUnits(i), 20);
  assertEquals(shouldReorder(i), true);
});

Deno.test("pharmacyStock - a dose at this exact minute is not the next one", () => {
  // 18:00Z = 20:00 in Cairo.
  assertEquals(nextDose(["08:00", "20:00"], "2026-11-21T18:00:00Z", "Africa/Cairo"), { date: "2026-11-22", time: "08:00" });
});

Deno.test("pharmacyStock - errors", () => {
  assertThrows(() => nextDose(["24:00"], "2026-11-21T10:00:00Z", "UTC"), RangeError);
  assertThrows(() => nextDose(["7:00"], "2026-11-21T10:00:00Z", "UTC"), RangeError);
  assertThrows(() => nextDose(["08:60"], "2026-11-21T10:00:00Z", "UTC"), RangeError);
  assertThrows(() => {
    reorderPoint({ restockQty: -1, dosesTakenSince: 0, unitsPerDose: 1, timesPerDay: 1 });
  }, RangeError);
});
