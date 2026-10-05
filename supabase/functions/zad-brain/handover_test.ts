// كارت تسليم الشفت (الشريحة ٣٤): الأيام الجاية بتوقيت السوق، اللي هيخلص، المدارس، والمستحقات.

import { assert, assertEquals } from "jsr:@std/assert@1";
import { handoverCard, type HandoverInput, handoverNoteFor, localDate } from "./handover.ts";
import { CHILD_BLOCKED_TOOLS, freshContext, MUTATING_TOOLS, validateHandoverCard } from "./validators.ts";
import { intentToolHints } from "./specialists.ts";

// ٢٠٢٦-١٠-٠٥ = اتنين.
const base: HandoverInput = {
  today: "2026-10-05",
  timeZone: "Africa/Cairo",
  days: 3,
  country: "EG",
  currency: "EGP",
  medicines: [
    { name: "فيتامين د", dosage: "قرص", dose_times: "09:00", remaining_quantity: 2, daily_dose_count: 1, for_person: "عمر", is_recurring: true },
    { name: "ضغط", dosage: null, dose_times: "08:00,20:00", remaining_quantity: 40, daily_dose_count: 2, for_person: null, is_recurring: true },
    { name: "مسكن", dosage: null, dose_times: null, remaining_quantity: 10, daily_dose_count: null, for_person: null, is_recurring: false },
  ],
  appointments: [
    { title: "دكتور أسنان", starts_at: "2026-10-06T10:00:00+03:00", kind: "medical", for_person: "عمر" },
    // ٢٣:٣٠ UTC يوم ٧ = ٨ الصبح بدري في القاهرة ⇒ برّه الـ٣ أيام (٥، ٦، ٧).
    { title: "اجتماع", starts_at: "2026-10-07T23:30:00Z", kind: null, for_person: null },
    { title: "فات", starts_at: "2026-10-04T10:00:00+03:00", kind: null, for_person: null },
  ],
  timetable: [
    { person: "عمر", weekday: 2, period: 2, subject: "علوم", starts: null },
    { person: "عمر", weekday: 2, period: 1, subject: "رياضيات", starts: "07:45:00" },
    { person: "سلمى", weekday: 3, period: 1, subject: "رسم", starts: null },
    { person: "عمر", weekday: 4, period: 1, subject: "عربي", starts: null },
  ],
  budget: { daily_allowance_left: 250, available: 4000 },
  obligations: [{ title: "إيجار", amount: 3000, due_day: 6 }, { title: "قسط", amount: 500, due_day: 15 }],
  shopping: ["عيش", "لبن"],
};

Deno.test("the card covers the coming days only, in the market's zone", () => {
  const c = handoverCard(base);
  assertEquals([c.from, c.to, c.days], ["2026-10-05", "2026-10-07", 3]);
  assertEquals(c.appointments.map((a) => a.title), ["دكتور أسنان"]);
  assertEquals(localDate("2026-10-07T23:30:00Z", "Africa/Cairo"), "2026-10-08");
  assertEquals(c.ambulance, "123");
});

Deno.test("scheduled doses are listed with whose they are, and what runs out before the trip ends is flagged", () => {
  const c = handoverCard(base);
  assertEquals(c.doses.map((d) => `${d.name}/${d.who}/${d.days_left}`), ["فيتامين د/عمر/2", "ضغط/العميل نفسه/20"]);
  assertEquals(c.running_low, ["فيتامين د (عمر)"]);
});

Deno.test("each school day lists each child's subjects in order, with the first bell when known", () => {
  const c = handoverCard(base);
  assertEquals(c.school, [
    { day: "التلات 2026-10-06", person: "عمر", subjects: ["رياضيات", "علوم"], first_period: "07:45" },
    { day: "الأربع 2026-10-07", person: "سلمى", subjects: ["رسم"], first_period: null },
  ]);
});

Deno.test("money: today's allowance, what is available, and only the bills that fall due inside the trip", () => {
  const c = handoverCard(base);
  assertEquals(c.money.per_day, 250);
  assertEquals(c.money.due, [{ title: "إيجار", amount: 3000, day: "2026-10-06" }]);
  assertEquals(handoverCard({ ...base, days: 20 }).days, 14);
  assertEquals(handoverCard({ ...base, days: 20 }).money.due.map((d) => d.title), ["إيجار", "قسط"]);
});

Deno.test("the trip note: once, only when a trip just began and someone else lives there", () => {
  const now = Date.parse("2026-10-05T09:00:00Z");
  assert(handoverNoteFor("2026-10-04T20:00:00Z", 2, now));
  assertEquals(handoverNoteFor("2026-10-04T20:00:00Z", 1, now), null);
  assertEquals(handoverNoteFor("2026-10-01T20:00:00Z", 3, now), null);
  assertEquals(handoverNoteFor(null, 3, now), null);
});

Deno.test("the tool: a read, one per turn, 1–14 days, not for a child's account", async () => {
  assertEquals((await validateHandoverCard({ days: 5 }, {}, freshContext("u"))).ok, true);
  assertEquals((await validateHandoverCard({}, {}, freshContext("u"))).ok, true);
  assertEquals((await validateHandoverCard({ days: 30 }, {}, freshContext("u"))).ok, false);
  const ctx = freshContext("u");
  ctx.counts["handover_card"] = 1;
  assertEquals((await validateHandoverCard({}, {}, ctx)).ok, false);
  assert(!MUTATING_TOOLS.includes("handover_card"));
  assert(CHILD_BLOCKED_TOOLS.includes("handover_card"));
});

Deno.test("leaving the house with someone holding it offers the card; a trip by itself does not", () => {
  for (const m of ["أنا مسافر بكرة ومراتي هتمسك البيت", "جهزلي كارت تسليم", "هغيب أسبوع والأولاد مع ماما"]) {
    assert(intentToolHints(m).includes("handover_card"), m);
  }
  assert(!intentToolHints("مسافر دبي الأسبوع الجاي، الفندق بكام؟").includes("handover_card"));
});
