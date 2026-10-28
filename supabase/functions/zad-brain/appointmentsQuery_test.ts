import { assertEquals } from "jsr:@std/assert@1";
import { appointmentAgenda, matchesAppointmentQuery, searchAppointments } from "./appointmentsQuery.ts";
import { freshContext, validateDeleteAppointment, validateFindAppointments, validateUpdateAppointment } from "./validators.ts";
import { intentToolHints, scopeToolsForSpecialist } from "./specialists.ts";

const TZ = "Africa/Cairo";
const ID = "00000000-0000-4000-8000-000000000001";
const row = (over: Record<string, unknown>) => ({ id: ID, title: "x", starts_at: "", status: "upcoming", ...over }) as never;

Deno.test("the agenda puts each once-only appointment on its local day, not its UTC day", () => {
  // 23:30 القاهرة يوم ٢٩ = 20:30Z — ويوم ١ نوفمبر 00:30 القاهرة = ٣١ أكتوبر بـUTC.
  const rows = [
    row({ id: "a", title: "البنك", starts_at: "2026-10-29T20:30:00Z" }),
    row({ id: "b", title: "دكتور", starts_at: "2026-10-31T22:30:00Z" }),
  ];
  assertEquals(appointmentAgenda(rows, "2026-10-29", "2026-10-29", TZ).map((a) => [a.title, a.time]), [["البنك", "23:30"]]);
  assertEquals(appointmentAgenda(rows, "2026-10-31", "2026-10-31", TZ).length, 0);
  assertEquals(appointmentAgenda(rows, "2026-11-01", "2026-11-01", TZ).map((a) => a.title), ["دكتور"]);
});

Deno.test("a recurring row lands on every day it falls on from its start, never before", () => {
  const rows = [
    row({ id: "d", title: "مية", starts_at: "2026-10-29T07:00:00Z", recurrence: "daily" }),
    row({ id: "w", title: "اجتماع", starts_at: "2026-10-29T08:00:00Z", recurrence: "weekly" }), // خميس
    row({ id: "m", title: "إيجار", starts_at: "2026-10-30T09:00:00Z", recurrence: "monthly" }), // يوم ٣٠
  ];
  const week = appointmentAgenda(rows, "2026-10-28", "2026-11-06", TZ);
  assertEquals(week.filter((a) => a.id === "d").map((a) => a.date)[0], "2026-10-29", "not on the day before it starts");
  assertEquals(week.filter((a) => a.id === "d").length, 9);
  assertEquals(week.filter((a) => a.id === "w").map((a) => a.date), ["2026-10-29", "2026-11-05"]);
  assertEquals(week.filter((a) => a.id === "m").map((a) => a.date), ["2026-10-30"]);
  assertEquals(appointmentAgenda(rows, "2026-11-30", "2026-11-30", TZ).map((a) => a.id).sort(), ["d", "m"]);
});

Deno.test("a cancelled recurring row stays off the agenda; a done one-off still shows on its day", () => {
  const rows = [
    row({ id: "c", title: "نادي", starts_at: "2026-10-29T08:00:00Z", recurrence: "daily", status: "cancelled" }),
    row({ id: "o", title: "مشوار", starts_at: "2026-10-29T08:00:00Z", status: "done" }),
  ];
  assertEquals(appointmentAgenda(rows, "2026-10-29", "2026-10-30", TZ).map((a) => [a.id, a.status]), [["o", "done"]]);
});

Deno.test("search matches every word across title, place and person, ignoring ال and hamza", () => {
  assertEquals(matchesAppointmentQuery("دكتور الأسنان", null, null, "الدكتور"), true);
  assertEquals(matchesAppointmentQuery("كشف القلب", "مستشفى السلام", "بابا", "كشف بابا"), true);
  assertEquals(matchesAppointmentQuery("دكتور الأسنان", null, null, "دكتور بابا"), false);
  assertEquals(matchesAppointmentQuery("البنك", null, null, " "), false);
});

Deno.test("search answers «إمتى» with the recurring row's next occurrence, not its first one", () => {
  const now = Date.parse("2026-10-28T12:00:00Z"); // 15:00 القاهرة، أربع
  const rows = [row({ title: "تمرين", starts_at: "2026-10-01T06:00:00Z", recurrence: "weekly" })]; // خميس ٩ الصبح
  assertEquals(searchAppointments(rows, "تمرين", TZ, now).map((a) => [a.date, a.time]), [["2026-10-29", "09:00"]]);
});

Deno.test("find_appointments needs a day range or a word, and caps the range", async () => {
  const ctx = freshContext("u");
  assertEquals((await validateFindAppointments({ query: "دكتور" }, null, ctx)), { ok: true });
  assertEquals((await validateFindAppointments({ from: "2026-10-29" }, null, ctx)), { ok: true });
  assertEquals((await validateFindAppointments({}, null, ctx)).ok, false);
  assertEquals((await validateFindAppointments({ from: "29/10" }, null, ctx)).ok, false);
  assertEquals((await validateFindAppointments({ from: "2026-10-29", to: "2026-10-28" }, null, ctx)).ok, false);
  assertEquals((await validateFindAppointments({ from: "2026-10-01", to: "2027-01-01" }, null, ctx)).ok, false);
});

Deno.test("update_appointment accepts place, recurrence and reminder — and checks them", async () => {
  const ctx = freshContext("u");
  assertEquals((await validateUpdateAppointment({ appointment_id: ID, recurrence: "weekly" }, null, ctx)), { ok: true });
  assertEquals((await validateUpdateAppointment({ appointment_id: ID, place_label: null }, null, ctx)), { ok: true });
  assertEquals((await validateUpdateAppointment({ appointment_id: ID, remind_minutes_before: 60 }, null, ctx)), { ok: true });
  assertEquals((await validateUpdateAppointment({ appointment_id: ID, recurrence: "every_10_min" }, null, ctx)).ok, false);
  assertEquals((await validateUpdateAppointment({ appointment_id: ID, remind_minutes_before: -5 }, null, ctx)).ok, false);
  assertEquals((await validateUpdateAppointment({ appointment_id: ID }, null, ctx)).ok, false);
});

Deno.test("delete_appointment needs a real id", async () => {
  const ctx = freshContext("u");
  assertEquals((await validateDeleteAppointment({ appointment_id: ID }, null, ctx)), { ok: true });
  assertEquals((await validateDeleteAppointment({ appointment_id: "دكتور" }, null, ctx)).ok, false);
});

Deno.test("schedule questions bring the query tool; delete wording brings delete — through any specialist", () => {
  assertEquals(intentToolHints("عندي إيه بكرة؟").includes("find_appointments"), true);
  assertEquals(intentToolHints("ورايا ايه الخميس").includes("find_appointments"), true);
  assertEquals(intentToolHints("إمتى الدكتور؟").includes("find_appointments"), true);
  assertEquals(intentToolHints("امسح ميعاد البنك خالص").includes("delete_appointment"), true);
  assertEquals(intentToolHints("عندي إيه في التلاجة").includes("find_appointments"), false);
  // بالنية بتوصل لأي وكيل، مش لنطاقه بس.
  const tools = ["find_appointments", "delete_appointment"].map((name) => ({ name }));
  assertEquals(scopeToolsForSpecialist(tools, "pharmacy", null, intentToolHints("عندي إيه بكرة؟")).map((t) => t.name), ["find_appointments", "delete_appointment"]);
});
