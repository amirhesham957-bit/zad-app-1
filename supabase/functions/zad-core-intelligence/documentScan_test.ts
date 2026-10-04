// الروشتة وجدول الحصص: الموديل بينقل، والكود بيتحقق — مفيش جرعة متخمّنة ولا يوم مش مفهوم.
import { assertEquals } from "jsr:@std/assert@1";
import { doseTimesFor, normalizePrescription, normalizeTimetable, weekdayOf } from "./documentScan.ts";

Deno.test("prescription: what is written becomes a line, with suggested times from the written frequency", () => {
  const p = normalizePrescription({
    patient_name: "عمر أحمد", doctor: "د. سامي", date: "2026-10-04",
    medicines: [
      { name: "Augmentin 1g", strength: "1 g", form: "قرص", instructions: "قرص كل ١٢ ساعة لمدة ٧ أيام", times_per_day: 2, duration_days: 7, as_needed: false, legible: true },
      { name: "Panadol", strength: "500 mg", form: "قرص", instructions: "عند اللزوم", times_per_day: 3, duration_days: null, as_needed: true, legible: true },
      { name: "Concor", strength: "5 mg", instructions: "١ يومياً", times_per_day: "١", duration_days: null, legible: true },
    ],
  });
  assertEquals(p.patient_name, "عمر أحمد");
  assertEquals(p.date, "2026-10-04");
  assertEquals(p.medicines[0].suggested_times, "09:00,21:00");
  assertEquals(p.medicines[0].course_doses, 14);
  assertEquals(p.medicines[1].times_per_day, null, "as needed has no schedule, whatever the model wrote");
  assertEquals(p.medicines[1].suggested_times, null);
  assertEquals(p.medicines[2].times_per_day, 1, "Arabic digits are read");
  assertEquals(p.medicines[2].course_doses, null, "no duration written: a chronic medicine, not a course");
});

Deno.test("prescription: an illegible line keeps its words but gets no schedule; nonsense is dropped", () => {
  const p = normalizePrescription({
    medicines: [
      { name: "Ce...x", instructions: "?", times_per_day: 3, duration_days: 5, legible: false },
      { name: "", instructions: "x3" },
      { name: "D", times_per_day: 2 },
      { name: "Brufen", times_per_day: 9 },
    ],
    date: "4/10/2026",
  });
  assertEquals(p.medicines.map((m) => m.name), ["Ce...x", "Brufen"]);
  assertEquals(p.medicines[0].suggested_times, null);
  assertEquals(p.medicines[0].course_doses, null);
  assertEquals(p.medicines[1].times_per_day, null, "nine times a day is not a frequency we schedule");
  assertEquals(p.date, null, "only YYYY-MM-DD");
  assertEquals(normalizePrescription(null).medicines, []);
});

Deno.test("prescription: suggested times for one to four doses, none beyond", () => {
  assertEquals(doseTimesFor(1, false), "09:00");
  assertEquals(doseTimesFor(3, false), "08:00,14:00,20:00");
  assertEquals(doseTimesFor(4, false), "08:00,12:00,16:00,20:00");
  assertEquals(doseTimesFor(5, false), null);
  assertEquals(doseTimesFor(2, true), null);
  assertEquals(doseTimesFor(null, false), null);
});

Deno.test("timetable: Arabic and English day names, periods in order, breaks and blanks skipped", () => {
  const t = normalizeTimetable({
    student_name: "سلمى", class_name: "٣/ب",
    days: [
      { day: "الأحد", periods: [{ order: 1, start: "7:45", end: "8:30", subject: "رياضيات" }, { subject: "فسحة" }, { subject: "علوم" }] },
      { day: "الإثنين", periods: [{ subject: "لغة عربية" }, { subject: "" }] },
      { day: "الاتنين", periods: [{ subject: "تكرار يوم" }] },
      { day: "Thursday", periods: [{ subject: "Science", start: "25:00" }] },
      { day: "يوم مش مفهوم", periods: [{ subject: "x" }] },
    ],
  });
  assertEquals(t.days.map((d) => d.weekday), [0, 1, 4]);
  assertEquals(t.days[0].periods, [
    { order: 1, start: "07:45", end: "08:30", subject: "رياضيات" },
    { order: 2, start: null, end: null, subject: "علوم" },
  ]);
  assertEquals(t.days[2].periods[0].start, null, "25:00 is not a time");
  assertEquals(t.student_name, "سلمى");
});

Deno.test("timetable: every school day name maps to its weekday", () => {
  const names: Array<[string, number]> = [
    ["الأحد", 0], ["احد", 0], ["الإثنين", 1], ["الاتنين", 1], ["اثنين", 1], ["الثلاثاء", 2], ["التلات", 2],
    ["الأربعاء", 3], ["الاربع", 3], ["الخميس", 4], ["الجمعة", 5], ["السبت", 6], ["Sunday", 0], ["sat", 6],
  ];
  for (const [n, d] of names) assertEquals(weekdayOf(n), d, n);
  assertEquals(weekdayOf("حصة"), null);
});
