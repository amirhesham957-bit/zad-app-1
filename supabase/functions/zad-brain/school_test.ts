// جدول الحصص في يوم العيلة: مواد كل طفل النهارده وبكرة، و«جهّز الشنطة» في تصبح على خير.
import { assert, assertEquals } from "jsr:@std/assert@1";
import { schoolDay, weekdayOfDate } from "./school.ts";
import { momentFallback } from "./voiceMoments.ts";

const rows = [
  { person: "عمر", weekday: 0, period: 2, starts: null, subject: "علوم" },
  { person: "عمر", weekday: 0, period: 1, starts: "07:45:00", subject: "رياضيات" },
  { person: "سلمى", weekday: 0, period: 1, starts: null, subject: "رسم" },
  { person: "عمر", weekday: 1, period: 1, starts: null, subject: "عربي" },
];

Deno.test("school day: each child's subjects in period order, with the first time when written", () => {
  assertEquals(schoolDay(rows, 0), [
    { person: "عمر", subjects: ["رياضيات", "علوم"], first_start: "07:45" },
    { person: "سلمى", subjects: ["رسم"], first_start: null },
  ]);
  assertEquals(schoolDay(rows, 5), [], "Friday: no school");
});

Deno.test("school day: the weekday of a local date, and of the next day", () => {
  assertEquals(weekdayOfDate("2026-10-04"), 0, "a Sunday");
  assertEquals(weekdayOfDate("2026-10-04", 1), 1);
  assertEquals(weekdayOfDate("2026-10-10", 1), 0, "Saturday → Sunday");
});

Deno.test("good night: no appointment tomorrow, so the reminder is the school bag", () => {
  const m = momentFallback("good_night", { school_tomorrow: [{ person: "عمر", subjects: ["رياضيات", "علوم"] }] });
  assert(m.text.includes("وجهّز شنطة عمر لبكرة: رياضيات، علوم"), m.text);
  const appt = momentFallback("good_night", {
    tomorrow_appointments: [{ title: "دكتور الأسنان" }],
    school_tomorrow: [{ person: "عمر", subjects: ["رياضيات"] }],
  });
  assert(appt.text.includes("دكتور الأسنان"), "an appointment still comes first");
  assertEquals(appt.text.includes("شنطة"), false);
});
