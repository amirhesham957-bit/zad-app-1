import { assertEquals } from "jsr:@std/assert@1";
import {
  askedFollowUpIds,
  type FollowUpAppointment,
  followUpCandidate,
  followUpQuestion,
  isVisit,
  loadAppointmentFollowUp,
} from "./appointmentFollowUp.ts";
import { askedThisMorning } from "./curiosity.ts";

// نص ليل ٢ نوفمبر بتوقيت القاهرة (UTC+2) = ٢٢:٠٠ UTC يوم ١.
const TODAY = Date.parse("2026-11-01T22:00:00Z");

const appt = (over: Partial<FollowUpAppointment>): FollowUpAppointment => ({
  id: "a1",
  title: "دكتور الأسنان",
  kind: "medical",
  starts_at: "2026-11-01T09:00:00Z", // ١١ الصبح القاهرة امبارح
  recurrence: "once",
  status: "done",
  ...over,
});

Deno.test("a doctor's visit yesterday is asked about the next morning", () => {
  const got = followUpCandidate([appt({})], TODAY, new Set());
  assertEquals(got, {
    id: "a1",
    title: "دكتور الأسنان",
    kind: "medical",
    on: "2026-11-01",
    question: "روحت دكتور الأسنان امبارح؟ قالك إيه؟",
  });
});

Deno.test("still upcoming counts — the cron closes it two hours later, the greeting may come first", () => {
  assertEquals(followUpCandidate([appt({ status: "upcoming" })], TODAY, new Set())?.id, "a1");
});

Deno.test("cancelled, repeating, today's, the day before yesterday's: none of them", () => {
  const rows = [
    appt({ id: "c", status: "cancelled" }),
    appt({ id: "r", recurrence: "weekly" }),
    appt({ id: "t", starts_at: "2026-11-02T07:00:00Z" }),
    appt({ id: "o", starts_at: "2026-10-31T21:59:00Z" }),
  ];
  assertEquals(followUpCandidate(rows, TODAY, new Set()), null);
});

Deno.test("the window is yesterday on the account's clock, edges included at the start", () => {
  assertEquals(followUpCandidate([appt({ starts_at: "2026-10-31T22:00:00Z" })], TODAY, new Set())?.id, "a1");
  assertEquals(followUpCandidate([appt({ starts_at: "2026-11-01T21:59:00Z" })], TODAY, new Set())?.id, "a1");
});

Deno.test("asked once is asked once", () => {
  assertEquals(followUpCandidate([appt({})], TODAY, new Set(["a1"])), null);
});

Deno.test("two visits yesterday ⇒ the later one", () => {
  const rows = [appt({ id: "early", starts_at: "2026-11-01T06:00:00Z" }), appt({ id: "late", starts_at: "2026-11-01T15:00:00Z" })];
  assertEquals(followUpCandidate(rows, TODAY, new Set())?.id, "late");
});

Deno.test("a visit is medical or reads like one; alarms and pills are not", () => {
  assertEquals(isVisit({ title: "دكتور العيون", kind: "medical" }), true);
  assertEquals(isVisit({ title: "مقابلة شغل", kind: "work" }), true);
  assertEquals(isVisit({ title: "الجوازات", kind: "errand" }), true);
  assertEquals(isVisit({ title: "صحيني", kind: "personal" }), false);
  assertEquals(isVisit({ title: "اشرب مياه", kind: "personal" }), false);
  assertEquals(isVisit({ title: "دوا الضغط", kind: "medical" }), false);
  assertEquals(isVisit({ title: "منبه الفجر", kind: "medical" }), false);
  assertEquals(isVisit({ title: "شوبنج", kind: "personal" }), false);
});

Deno.test("the question fits the visit", () => {
  assertEquals(followUpQuestion({ title: "مقابلة شغل", kind: "work" }), "مقابلة شغل امبارح عدّى إزاي؟");
  assertEquals(followUpQuestion({ title: "عيادة الجلدية", kind: "other" }), "روحت عيادة الجلدية امبارح؟ قالك إيه؟");
});

Deno.test("asked ids come from the greetings' facts", () => {
  const ids = askedFollowUpIds([
    { facts: { appointment_follow_up: { id: "x" } } },
    { facts: { curiosity: { key: "k" } } },
    { facts: null },
  ]);
  assertEquals([...ids], ["x"]);
});

Deno.test("the chat learns which appointment the answer is about", () => {
  const sentAt = new Date(TODAY + 8 * 3_600_000).toISOString();
  assertEquals(
    askedThisMorning({
      sent_at: sentAt,
      facts: {
        daily_question: "روحت دكتور الأسنان امبارح؟ قالك إيه؟",
        daily_question_kind: "appointment_follow_up",
        appointment_follow_up: { id: "a1", title: "دكتور الأسنان", kind: "medical", on: "2026-11-01" },
      },
    }, TODAY + 9 * 3_600_000),
    {
      question: "روحت دكتور الأسنان امبارح؟ قالك إيه؟",
      kind: "appointment_follow_up",
      for: "دكتور الأسنان",
      appointment_id: "a1",
      on: "2026-11-01",
      sent_at: sentAt,
    },
  );
});

// A fake client that answers each table from a fixture and records the filters.
function fakeSb(tables: Record<string, { data?: unknown; error?: unknown }>) {
  const calls: Array<{ table: string; ops: string[] }> = [];
  return {
    calls,
    from(table: string) {
      const entry = { table, ops: [] as string[] };
      calls.push(entry);
      const q: Record<string, unknown> = {};
      for (const op of ["select", "eq", "neq", "gte", "lt", "order", "limit"]) {
        q[op] = (...args: unknown[]) => {
          entry.ops.push(`${op}:${args.map((a) => typeof a === "object" ? JSON.stringify(a) : String(a)).join(",")}`);
          return q;
        };
      }
      q.then = (res: (v: unknown) => unknown) => res(tables[table] ?? { data: [] });
      return q;
    },
  };
}

Deno.test("load reads yesterday's one-offs and skips what was asked", async () => {
  const sb = fakeSb({
    zad_appointments: { data: [appt({ id: "a1" }), appt({ id: "a2", starts_at: "2026-11-01T12:00:00Z" })] },
    zad_voice_moments: { data: [{ facts: { appointment_follow_up: { id: "a2" } } }] },
  });
  const got = await loadAppointmentFollowUp(sb, "u1", "2026-11-01T22:00:00.000Z");
  assertEquals(got?.id, "a1");
  const appts = sb.calls.find((c) => c.table === "zad_appointments")!;
  assertEquals(appts.ops.includes("gte:starts_at,2026-10-31T22:00:00.000Z"), true);
  assertEquals(appts.ops.includes("lt:starts_at,2026-11-01T22:00:00.000Z"), true);
  assertEquals(appts.ops.includes("eq:recurrence,once"), true);
});

Deno.test("a failed read asks nothing", async () => {
  const sb = fakeSb({ zad_appointments: { data: [appt({})] }, zad_voice_moments: { error: { message: "boom" } } });
  assertEquals(await loadAppointmentFollowUp(sb, "u1", "2026-11-01T22:00:00.000Z"), null);
});
