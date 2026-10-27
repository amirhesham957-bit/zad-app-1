import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { eventAhead, eventAheadQuestion } from "./eventAhead.ts";
import { askedThisMorning } from "./curiosity.ts";

const base = {
  timeZone: "Africa/Cairo",
  country: "EG",
  kidsCount: 0,
  seasonWindows: [] as Array<{ slug: string; start_date: string }>,
  appointments: [] as Array<Record<string, string | null>>,
};

Deno.test("Ramadan 1448 starts 2027-02-08: asked on 2027-01-25 only", () => {
  assertEquals(eventAhead({ ...base, localDate: "2027-01-25" }), {
    kind: "ramadan", title: "رمضان 1448", on: "2027-02-08", in_days: 14,
  });
  assertEquals(eventAhead({ ...base, localDate: "2027-01-24" }), null);
  assertEquals(eventAhead({ ...base, localDate: "2027-01-26" }), null);
});

Deno.test("Dhul Hijjah 1448 starts 2027-05-07: asked 14 days before, about the Eid", () => {
  const e = eventAhead({ ...base, localDate: "2027-04-23" })!;
  assertEquals(e.kind, "dhul_hijjah");
  assertEquals(e.title, "عيد الأضحى 1448");
  assertStringIncludes(eventAheadQuestion(e), "هتضحّوا");
});

Deno.test("schools: a Gulf house with kids, 14 days before the window — not Egypt, not without kids", () => {
  const windows = [{ slug: "back_to_school", start_date: "2027-08-15" }];
  const gulf = { ...base, timeZone: "Asia/Riyadh", country: "SA", kidsCount: 2, seasonWindows: windows, localDate: "2027-08-01" };
  assertEquals(eventAhead(gulf), { kind: "back_to_school", title: "مصاريف المدارس 2027", on: "2027-08-15", in_days: 14 });
  assertEquals(eventAhead({ ...gulf, kidsCount: 0 }), null);
  assertEquals(eventAhead({ ...gulf, country: "EG", timeZone: "Africa/Cairo" }), null);
  assertEquals(eventAhead({ ...gulf, localDate: "2027-08-02" }), null);
});

Deno.test("travel: a one-off trip three local days out; an errand, a recurring trip or a cancelled one is not", () => {
  const trip = { title: "سفر إسكندرية", starts_at: "2026-11-02T06:00:00+02:00", recurrence: "once", status: "upcoming" };
  const day = { ...base, localDate: "2026-10-30" };
  assertEquals(eventAhead({ ...day, appointments: [trip] }), { kind: "travel", title: "سفر إسكندرية", on: "2026-11-02", in_days: 3 });
  assertEquals(eventAhead({ ...day, appointments: [{ ...trip, title: "البنك" }] }), null);
  assertEquals(eventAhead({ ...day, appointments: [{ ...trip, recurrence: "weekly" }] }), null);
  assertEquals(eventAhead({ ...day, appointments: [{ ...trip, status: "cancelled" }] }), null);
  // 00:30 Cairo on the 3rd is still the 2nd in UTC, but the day that counts is the market's.
  assertEquals(eventAhead({ ...day, appointments: [{ ...trip, starts_at: "2026-11-03T00:30:00+02:00" }] }), null);
});

Deno.test("travel comes before a season on the same morning", () => {
  const trip = { title: "رحلة العمرة", starts_at: "2027-01-28T09:00:00+02:00" };
  assertEquals(eventAhead({ ...base, localDate: "2027-01-25", appointments: [trip] })!.kind, "travel");
});

Deno.test("the question names the event and suggests no number", () => {
  const q = eventAheadQuestion({ kind: "ramadan", title: "رمضان 1448", on: "2027-02-08", in_days: 14 });
  assertStringIncludes(q, "رمضان بعد 14 يوم");
  assertEquals(/\d{3,}/.test(q), false);
});

Deno.test("the chat reads the morning's event question back with its goal title and day", () => {
  const sent = new Date().toISOString();
  const asked = askedThisMorning({
    sent_at: sent,
    facts: {
      daily_question: "رمضان بعد 14 يوم…",
      daily_question_kind: "event_reserve",
      event_reserve: { kind: "ramadan", title: "رمضان 1448", on: "2027-02-08", in_days: 14 },
    },
  });
  assertEquals(asked, { question: "رمضان بعد 14 يوم…", kind: "event_reserve", for: "رمضان 1448", deadline: "2027-02-08", sent_at: sent });
});
