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

// ── ٨ج.٥: المراجعة قبل الحجز ──
import { atWork, bookingConflicts, bookingQuestion, isMedicineReminder, parseWorkSchedule } from "./scheduleGuard.ts";

const book = (over: Partial<Parameters<typeof bookingConflicts>[0]>) =>
  bookingConflicts({ title: "دكتور الأسنان", startsAt: at("2026-10-27T11:00:00"), timeZone: TZ, existing: [], ...over }).map((c) => c.kind);

Deno.test("work schedules read the way customers write them", () => {
  assertEquals(parseWorkSchedule("من ٩ لـ٥ غير الجمعة"), { days: [0, 1, 2, 3, 4, 6], start: 540, end: 1020 });
  assertEquals(parseWorkSchedule("الأحد للخميس ٨-٣"), { days: [0, 1, 2, 3, 4], start: 480, end: 900 });
  assertEquals(parseWorkSchedule("من 8:30 الصبح ل 4:30 العصر"), { days: [0, 1, 2, 3, 4, 6], start: 510, end: 990 });
  assertEquals(parseWorkSchedule("شفت من ١٠ بالليل لـ٦ الصبح ماعدا الجمعة والسبت"), { days: [0, 1, 2, 3, 4], start: 1320, end: 360 });
  assertEquals(parseWorkSchedule("من ٢ لـ١٠"), { days: [0, 1, 2, 3, 4, 6], start: 840, end: 1320 }, "no marker under 6 = afternoon");
  assertEquals(parseWorkSchedule("شغال من البيت"), null, "no hours ⇒ no guess");
  assertEquals(parseWorkSchedule("مواعيد متغيرة"), null);
  assertEquals(parseWorkSchedule(null), null);
});

Deno.test("a night shift that crosses midnight belongs to the day it started", () => {
  const w = parseWorkSchedule("من ١٠ بالليل لـ٦ الصبح ماعدا الجمعة والسبت")!;
  assertEquals(atWork(Date.parse(at("2026-10-29T23:00:00")), w, TZ), true, "Thursday night");
  assertEquals(atWork(Date.parse(at("2026-10-30T03:00:00")), w, TZ), true, "early Friday is still Thursday's shift");
  assertEquals(atWork(Date.parse(at("2026-10-31T03:00:00")), w, TZ), false, "early Saturday follows a Friday off");
  assertEquals(atWork(Date.parse(at("2026-10-29T12:00:00")), w, TZ), false);
});

Deno.test("booking inside working hours asks; outside them, a work meeting, someone else's, or a daily reminder does not", () => {
  const work = "من ٩ لـ٥ غير الجمعة";
  assertEquals(book({ workSchedule: work }), ["work"], "Tuesday 11:00");
  assertEquals(book({ workSchedule: work, startsAt: at("2026-10-27T18:00:00") }), [], "after work");
  assertEquals(book({ workSchedule: work, startsAt: at("2026-10-30T11:00:00") }), [], "Friday off");
  assertEquals(book({ workSchedule: work, kind: "work", title: "اجتماع" }), []);
  assertEquals(book({ workSchedule: work, forPerson: "بابا" }), [], "his father's appointment, not his schedule");
  assertEquals(book({ workSchedule: work, title: "اشرب مية", recurrence: "daily" }), []);
  assertEquals(book({ workSchedule: "شغال من البيت" }), [], "unreadable schedule never asks");
});

Deno.test("a medicine while he sleeps asks; at bedtime, awake, or for someone else it does not", () => {
  const sleep = { bed: "23:00", wake: "07:00" };
  assertEquals(book({ title: "دوا الضغط", startsAt: at("2026-10-27T03:00:00"), sleep }), ["sleep"]);
  assertEquals(book({ title: "حباية قبل النوم", startsAt: at("2026-10-27T23:00:00"), sleep }), [], "bedtime is not asleep");
  assertEquals(book({ title: "دوا الضغط", startsAt: at("2026-10-27T08:00:00"), sleep }), []);
  assertEquals(book({ title: "دوا يوسف", startsAt: at("2026-10-27T03:00:00"), sleep, forPerson: "يوسف" }), []);
  assertEquals(book({ title: "أصحى", startsAt: at("2026-10-27T05:00:00"), sleep }), [], "a wake-up alarm is not a medicine");
  assertEquals(book({ title: "دوا الضغط", startsAt: at("2026-10-27T03:00:00"), sleep: null }), [], "no learned sleep ⇒ no guess");
});

Deno.test("a medicine reminder on top of a dose the pharmacy already reminds asks", () => {
  const medicines = [{ name: "كونكور", for: null, times: "09:00,21:00" }, { name: "شراب يوسف", for: "يوسف", times: "14:00" }];
  assertEquals(book({ title: "دوا الضغط", startsAt: at("2026-10-27T21:15:00"), medicines }), ["dose"]);
  assertEquals(book({ title: "دوا الضغط", startsAt: at("2026-10-27T15:00:00"), medicines }), []);
  assertEquals(book({ title: "دوا يوسف", startsAt: at("2026-10-27T14:00:00"), medicines }), [], "Youssef's dose, not his");
  assertEquals(book({ title: "دوا يوسف", startsAt: at("2026-10-27T14:00:00"), medicines, forPerson: "يوسف" }), ["dose"]);
  assertEquals(book({ title: "البنك", startsAt: at("2026-10-27T21:00:00"), medicines }), [], "not a medicine");
});

Deno.test("an existing appointment at the same time is part of the same one question", () => {
  const existing = [{ id: "1", title: "البنك", starts_at: at("2026-10-27T11:20:00") }];
  const c = bookingConflicts({
    title: "دكتور الأسنان", startsAt: at("2026-10-27T11:00:00"), timeZone: TZ, existing, workSchedule: "من ٩ لـ٥",
  });
  assertEquals(c.map((x) => x.kind), ["clash", "work"]);
  const q = bookingQuestion(c);
  assertStringIncludes(q, "مرفوض:");
  assertStringIncludes(q, "«البنك»");
  assertStringIncludes(q, "confirm_conflict=true");
  assertStringIncludes(q, "سؤال واحد");
});

Deno.test("medicine reminders are read from the title, not the kind", () => {
  for (const t of ["دوا الضغط", "حباية السكر", "إبرة الأنسولين", "قطرة العين", "فيتامين د"]) assertEquals(isMedicineReminder(t), true, t);
  for (const t of ["اشرب مياه", "الجيم", "موعد الواي بروتين والكرياتين", "أصحى", "دكتور الأسنان"]) assertEquals(isMedicineReminder(t), false, t);
});
