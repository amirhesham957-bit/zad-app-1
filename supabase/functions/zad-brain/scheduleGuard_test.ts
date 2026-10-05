import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { clashNote, scheduleClashes } from "./scheduleGuard.ts";

const TZ = "Asia/Riyadh"; // +03:00 all year — no DST to blur the clock comparisons
const at = (local: string) => new Date(`${local}+03:00`).toISOString();
const titles = (r: Array<{ title?: string | null }>) => r.map((x) => x.title);

Deno.test("a new appointment within the hour of another one for the same person clashes", () => {
  const existing = [
    { id: "1", title: "دكتور الأسنان", starts_at: at("2026-10-08T17:00:00") },
    { id: "2", title: "البنك", starts_at: at("2026-10-08T19:00:00") },
  ];
  assertEquals(titles(scheduleClashes({ startsAt: at("2026-10-08T17:30:00"), existing, timeZone: TZ })), ["دكتور الأسنان"]);
  assertEquals(scheduleClashes({ startsAt: at("2026-10-08T18:00:00"), existing, timeZone: TZ }).length, 0, "an hour apart is not a clash");
});

Deno.test("another person's appointment, a cancelled one, and the one being moved do not clash", () => {
  const existing = [
    { id: "1", title: "تطعيم يوسف", starts_at: at("2026-10-08T17:00:00"), for_person: "يوسف" },
    { id: "2", title: "النادي", starts_at: at("2026-10-08T17:00:00"), status: "cancelled" },
    { id: "3", title: "الكوافير", starts_at: at("2026-10-08T17:10:00") },
  ];
  assertEquals(scheduleClashes({ startsAt: at("2026-10-08T17:00:00"), existing, timeZone: TZ, excludeId: "3" }).length, 0);
  assertEquals(titles(scheduleClashes({ startsAt: at("2026-10-08T17:00:00"), forPerson: " يوسف ", existing, timeZone: TZ })),
    ["تطعيم يوسف"], "the same child, spelled with spaces");
});

Deno.test("recurring ones clash by local clock: daily every day, weekly on its weekday, monthly on its day", () => {
  const existing = [
    { id: "d", title: "الجيم", starts_at: at("2026-10-01T20:00:00"), recurrence: "daily" },
    { id: "w", title: "درس العربي", starts_at: at("2026-10-04T16:00:00"), recurrence: "weekly" }, // a Sunday
    { id: "m", title: "اجتماع الشهر", starts_at: at("2026-09-15T10:00:00"), recurrence: "monthly" },
    { id: "h", title: "اشرب مية", starts_at: at("2026-10-01T09:00:00"), recurrence: "hourly" },
  ];
  assertEquals(titles(scheduleClashes({ startsAt: at("2026-10-20T20:30:00"), existing, timeZone: TZ })), ["الجيم"]);
  assertEquals(titles(scheduleClashes({ startsAt: at("2026-10-11T16:15:00"), existing, timeZone: TZ })), ["درس العربي"], "next Sunday");
  assertEquals(scheduleClashes({ startsAt: at("2026-10-12T16:15:00"), existing, timeZone: TZ }).length, 0, "a Monday");
  assertEquals(titles(scheduleClashes({ startsAt: at("2026-11-15T10:20:00"), existing, timeZone: TZ })), ["اجتماع الشهر"]);
  assertEquals(scheduleClashes({ startsAt: at("2026-09-30T20:00:00"), existing, timeZone: TZ }).length, 0, "before the daily one starts");
  assertEquals(scheduleClashes({ startsAt: at("2026-10-08T09:00:00"), existing, timeZone: TZ }).length, 0, "hourly never clashes");
});

Deno.test("midnight does not split two close times", () => {
  const existing = [{ id: "d", title: "دوا بالليل", starts_at: at("2026-10-01T23:50:00"), recurrence: "daily" }];
  assertEquals(scheduleClashes({ startsAt: at("2026-10-09T00:20:00"), existing, timeZone: TZ }).length, 1);
});

Deno.test("the clash note names the other appointment, asks, and forbids acting alone", () => {
  const note = clashNote([{ title: "دكتور الأسنان", starts_at: at("2026-10-08T17:00:00") }], TZ);
  assertStringIncludes(note, "«دكتور الأسنان»");
  assertStringIncludes(note, "اسأله");
  assertStringIncludes(note, "ماتلغيش");
  assertEquals(clashNote([], TZ), "");
});
