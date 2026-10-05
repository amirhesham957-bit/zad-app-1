import { assertEquals } from "jsr:@std/assert@1";
import { nextRenewal } from "./nextRenewal.ts";

Deno.test("a passed monthly date rolls to next month; today and the future stay", () => {
  assertEquals(nextRenewal("2026-10-03", null, "MONTHLY", "2026-10-05"), "2026-11-03");
  assertEquals(nextRenewal("2026-10-05", null, "MONTHLY", "2026-10-05"), "2026-10-05");
  assertEquals(nextRenewal("2026-10-09", null, "MONTHLY", "2026-10-05"), "2026-10-09");
});

Deno.test("the 31st keeps its day through short months; yearly and weekly step their own way", () => {
  assertEquals(nextRenewal("2026-01-31", null, "MONTHLY", "2026-02-10"), "2026-02-28");
  assertEquals(nextRenewal("2026-01-31", null, "MONTHLY", "2026-03-01"), "2026-03-31");
  assertEquals(nextRenewal("2025-03-01", null, "YEARLY", "2026-10-05"), "2027-03-01");
  assertEquals(nextRenewal("2026-09-28", null, "WEEKLY", "2026-10-05"), "2026-10-05");
});

Deno.test("no date: due_day, or a day written in the text; nothing usable is null", () => {
  assertEquals(nextRenewal(null, 20, "MONTHLY", "2026-10-05"), "2026-10-20");
  assertEquals(nextRenewal(null, 2, "MONTHLY", "2026-10-05"), "2026-11-02");
  assertEquals(nextRenewal("30 مارس", null, "MONTHLY", "2026-10-05"), "2026-10-30");
  // نفس شذوذ SQL: تاريخ مش حقيقي بياخد أول رقمين من السنة («20») كيوم.
  assertEquals(nextRenewal("2026-02-31", null, "MONTHLY", "2026-10-05"), "2026-10-20");
  assertEquals(nextRenewal(null, null, "MONTHLY", "2026-10-05"), null);
});
