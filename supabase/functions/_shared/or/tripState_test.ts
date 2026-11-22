import { assertEquals } from "jsr:@std/assert@1";
import { tripState } from "./tripState.ts";

// رحلة من ١ لـ ١٠ نوفمبر (١٠ أيام).
const START = "2026-11-01T00:00:00Z";
const END = "2026-11-10T23:59:59Z";

Deno.test("نص الرحلة: اليوم الخامس من عشرة، والباقي ستة أيام", () => {
  const s = tripState({ startISO: START, endISO: END, todayISO: "2026-11-05T08:00:00Z", budget: 1000, spent: 400 });
  assertEquals(s, { day: 5, of: 10, daysLeft: 6, remaining: 600, perDayLeft: 100, overBudget: false });
});

Deno.test("أول يوم في الرحلة", () => {
  const s = tripState({ startISO: START, endISO: END, todayISO: "2026-11-01", budget: 1000, spent: 0 });
  assertEquals(s.day, 1);
  assertEquals(s.daysLeft, 10);
});

Deno.test("آخر يوم في الرحلة", () => {
  const s = tripState({ startISO: START, endISO: END, todayISO: "2026-11-10", budget: 1000, spent: 0 });
  assertEquals(s.day, 10);
  assertEquals(s.daysLeft, 1);
});

Deno.test("قبل بداية الرحلة: اليوم بيفضل ١ والأيام الفاضلة كلها", () => {
  const s = tripState({ startISO: START, endISO: END, todayISO: "2026-10-25", budget: 1000, spent: 0 });
  assertEquals(s.day, 1);
  assertEquals(s.daysLeft, 10);
});

Deno.test("بعد نهاية الرحلة: الأيام الفاضلة صفر والميزانية لكل يوم صفر", () => {
  const s = tripState({ startISO: START, endISO: END, todayISO: "2026-11-15", budget: 1000, spent: 200 });
  assertEquals(s.day, 10);
  assertEquals(s.daysLeft, 0);
  assertEquals(s.perDayLeft, 0);
});

Deno.test("صرف أكتر من الميزانية: الباقي سالب وoverBudget true", () => {
  const s = tripState({ startISO: START, endISO: END, todayISO: "2026-11-05", budget: 500, spent: 620 });
  assertEquals(s.remaining, -120);
  assertEquals(s.overBudget, true);
  assertEquals(s.perDayLeft, -20);
});

Deno.test("رحلة يوم واحد", () => {
  const s = tripState({
    startISO: "2026-11-22T00:00:00Z",
    endISO: "2026-11-22T00:00:00Z",
    todayISO: "2026-11-22",
    budget: 100,
    spent: 30,
  });
  assertEquals(s, { day: 1, of: 1, daysLeft: 1, remaining: 70, perDayLeft: 70, overBudget: false });
});
