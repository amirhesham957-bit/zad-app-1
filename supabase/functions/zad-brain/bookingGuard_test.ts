// ٨ج.٥: add_appointment وupdate_appointment بيراجعوا قبل ما يكتبوا — تعارض ⇒ سؤال ومفيش كتابة؛ confirm_conflict ⇒ يتكتب.
// وbooking_check (صفحة المواعيد) بيقرا نفس المصادر ويرجّع نفس الأسباب.
import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { bookingCheck, runTool } from "./index.ts";
import { freshContext } from "./validators.ts";

/** عميل وهمي: كل نداء بيرجّع نفس الـbuilder، والـawait بيرجّع الصفوف بتاعة الجدول. بيسجّل الـinserts. */
function fakeSb(rows: Record<string, unknown[]>) {
  const inserts: Array<{ table: string; row: unknown }> = [];
  const updates: Array<{ table: string; patch: unknown }> = [];
  const rpcs: string[] = [];
  const builder = (table: string, inserted?: unknown) => {
    const b: Record<string, unknown> = {};
    let single = false;
    for (const m of ["select", "eq", "or", "limit", "gte", "lte", "order", "upsert", "in", "is"]) {
      b[m] = () => b;
    }
    b.maybeSingle = () => {
      single = true;
      return b;
    };
    b.insert = (row: unknown) => {
      inserts.push({ table, row });
      return builder(table, { id: "00000000-0000-0000-0000-0000000000aa", ...(row as object) });
    };
    b.update = (patch: unknown) => {
      updates.push({ table, patch });
      return builder(table, { ...((rows[table] ?? [])[0] as object), ...(patch as object) });
    };
    b.then = (ok: (v: unknown) => unknown) => {
      const all = inserted ? [inserted] : rows[table] ?? [];
      return ok({ data: single ? all[0] ?? null : all, error: null });
    };
    return b;
  };
  const sb = {
    from: (table: string) => builder(table),
    rpc: (name: string) => {
      rpcs.push(name);
      return Promise.resolve({ data: name === "zad_memory_recall_entities" ? [{ note: "الدكتور قال هات الأشعة" }] : null, error: null });
    },
  };
  return { sb, inserts, updates, rpcs };
}

const TZ = "UTC"; // ساعات الحالات بتتقري على الساعة المحلية — UTC عشان تبقى زي soon(h)
const soon = (h: number) => {
  const d = new Date(Date.now() + 3 * 86_400_000);
  d.setUTCHours(h, 0, 0, 0);
  return d.toISOString().replace(/\.\d+Z$/, "Z");
};
const snap = { now_local: { time_zone: TZ, utc_offset: "+00:00" } };

Deno.test("a clash refuses the booking before anything is written, and asks one question", async () => {
  const { sb, inserts } = fakeSb({ zad_appointments: [{ id: "x", title: "البنك", starts_at: soon(9), status: "upcoming", recurrence: "once" }] });
  // deno-lint-ignore no-explicit-any
  const r = await runTool(sb as any, "u", "add_appointment", { title: "دكتور الأسنان", starts_at: soon(9) }, snap, freshContext("u"), { source: "app_chat", runId: null });
  assertStringIncludes(r, "مرفوض: لسه ماسجّلتش");
  assertStringIncludes(r, "«البنك»");
  assertEquals(inserts.length, 0);
});

Deno.test("confirm_conflict books it anyway, and the result carries what memory holds about it", async () => {
  const { sb, inserts, rpcs } = fakeSb({ zad_appointments: [{ id: "x", title: "البنك", starts_at: soon(9), status: "upcoming", recurrence: "once" }] });
  const r = await runTool(
    // deno-lint-ignore no-explicit-any
    sb as any, "u", "add_appointment", { title: "دكتور الأسنان", starts_at: soon(9), confirm_conflict: true },
    snap, freshContext("u"), { source: "app_chat", runId: null },
  );
  assert(r.startsWith("تم تسجيل الميعاد"), r);
  assertEquals(inserts.filter((i) => i.table === "zad_appointments").length, 1);
  assert(rpcs.includes("zad_memory_recall_entities"));
  assertStringIncludes(r, "«الدكتور قال هات الأشعة»");
});

Deno.test("work hours from the profile and the pharmacy's own dose stop a booking too", async () => {
  const { sb, inserts } = fakeSb({});
  const working = { ...snap, customer: { work_schedule: "من ٨ الصبح لـ١١ بالليل" } };
  // deno-lint-ignore no-explicit-any
  const r = await runTool(sb as any, "u", "add_appointment", { title: "الكوافير", starts_at: soon(12), kind: "errand" }, working, freshContext("u"), { source: "app_chat", runId: null });
  assertStringIncludes(r, "مواعيد شغله");
  const dosed = { ...snap, medicines: [{ name: "كونكور", for: null, times: "12:00" }] };
  // deno-lint-ignore no-explicit-any
  const r2 = await runTool(sb as any, "u", "add_appointment", { title: "دوا الضغط", starts_at: soon(12) }, dosed, freshContext("u"), { source: "app_chat", runId: null });
  assertStringIncludes(r2, "«كونكور»");
  assertEquals(inserts.length, 0);
});

const ID = "00000000-0000-0000-0000-0000000000bb";

Deno.test("moving an appointment onto another one asks before the update is written", async () => {
  // الأول = الميعاد اللي بيتعدّل (maybeSingle بيرجّعه)، التاني = اللي في الساعة الجديدة.
  const rows = {
    zad_appointments: [
      { id: ID, title: "دكتور الأسنان", starts_at: soon(15), status: "upcoming", recurrence: "once" },
      { id: "x", title: "البنك", starts_at: soon(9), status: "upcoming", recurrence: "once" },
    ],
  };
  const { sb, updates } = fakeSb(rows);
  // deno-lint-ignore no-explicit-any
  const r = await runTool(sb as any, "u", "update_appointment", { appointment_id: ID, starts_at: soon(9) }, snap, freshContext("u"), { source: "app_chat", runId: null });
  assertStringIncludes(r, "مرفوض: لسه ماعدّلتش");
  assertStringIncludes(r, "«البنك»");
  assertStringIncludes(r, "update_appointment");
  assertEquals(updates.length, 0);

  const { sb: sb2, updates: u2 } = fakeSb(rows);
  const ok = await runTool(
    // deno-lint-ignore no-explicit-any
    sb2 as any, "u", "update_appointment", { appointment_id: ID, starts_at: soon(9), confirm_conflict: true },
    snap, freshContext("u"), { source: "app_chat", runId: null },
  );
  assert(ok.startsWith("تم تعديل الميعاد"), ok);
  assertEquals(u2.length, 1);
});

Deno.test("an appointment never clashes with itself, and done/cancelled is never questioned", async () => {
  const rows = { zad_appointments: [{ id: ID, title: "البنك", starts_at: soon(9), status: "upcoming", recurrence: "once" }] };
  const { sb, updates } = fakeSb(rows);
  // deno-lint-ignore no-explicit-any
  const r = await runTool(sb as any, "u", "update_appointment", { appointment_id: ID, starts_at: soon(9), title: "البنك الأهلي" }, snap, freshContext("u"), { source: "app_chat", runId: null });
  assert(r.startsWith("تم تعديل الميعاد"), r);
  const working = { ...snap, customer: { work_schedule: "من ٨ الصبح لـ١١ بالليل" } };
  // deno-lint-ignore no-explicit-any
  const done = await runTool(sb as any, "u", "update_appointment", { appointment_id: ID, status: "done" }, working, freshContext("u"), { source: "app_chat", runId: null });
  assert(done.startsWith("تم تعديل الميعاد"), done);
  assertEquals(updates.length, 2);
});

Deno.test("booking_check reads the profile, sleep and pharmacy itself and speaks to the customer", async () => {
  const { sb } = fakeSb({
    zad_users: [{ country: "EG", sleep_bed: "23:00:00", sleep_wake: "07:00:00" }],
    zad_customer_profile: [{ work_schedule: "من ٨ الصبح لـ١١ بالليل" }],
    zad_pharmacy_items: [{ name: "كونكور", for_person: null, dose_times: "12:00" }],
    zad_appointments: [{ id: "x", title: "البنك", starts_at: soon(12), status: "upcoming", recurrence: "once" }],
  });
  // deno-lint-ignore no-explicit-any
  const errand = await bookingCheck(sb as any, "u", { title: "الكوافير", starts_at: soon(12), kind: "errand" });
  assertEquals(errand?.map((c) => c.kind), ["clash", "work"]);
  assertStringIncludes(errand![1].say, "شغلك");
  // deno-lint-ignore no-explicit-any
  const dose = await bookingCheck(sb as any, "u", { title: "دوا الضغط", starts_at: soon(12) });
  assert(dose?.some((c) => c.kind === "dose" && c.say.includes("بتفكّرك")), JSON.stringify(dose));
  // deno-lint-ignore no-explicit-any
  const night = await bookingCheck(sb as any, "u", { title: "دوا الضغط", starts_at: soon(2) });
  assert(night?.some((c) => c.kind === "sleep"), JSON.stringify(night));
  // deno-lint-ignore no-explicit-any
  const self = await bookingCheck(sb as any, "u", { title: "البنك", starts_at: soon(12), kind: "work", appointment_id: "x" });
  assertEquals(self, []);
  // deno-lint-ignore no-explicit-any
  assertEquals(await bookingCheck(sb as any, "u", { title: "x", starts_at: "bad" }), null);
});
