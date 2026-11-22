// باب الجرعة والكتم (ZAD_PLAN ٣.٤): نفس سلوك البوت القديم، من مكان واحد.
import { assert, assertEquals } from "jsr:@std/assert@1";
import { DOSE_SNOOZE_MINUTES, isDoseAction, muteCheckin, settleDoseReminder, snoozeDose } from "./doseDoor.ts";

const ITEM_A = "11111111-1111-4111-8111-111111111111";
const ITEM_B = "22222222-2222-4222-8222-222222222222";
const MOMENT = "33333333-3333-4333-8333-333333333333";
const SLOT = "2026-10-25T08:00:00.000Z";

type Call = { table: string; op: string; payload?: unknown };

// deno-lint-ignore no-explicit-any
function fakeSb(opts: { moment?: any; insertCode?: string; rpc?: any; memory?: { id: string } | null } = {}) {
  const calls: Call[] = [];
  // deno-lint-ignore no-explicit-any
  const query = (table: string): any => {
    // deno-lint-ignore no-explicit-any
    const q: any = {
      select: () => q, eq: () => q, in: () => q, limit: () => q,
      maybeSingle: () => Promise.resolve({
        data: table === "zad_voice_moments" ? opts.moment ?? null : table === "zad_memory" ? opts.memory ?? null : null,
      }),
      then: (ok: (v: unknown) => void) => ok({
        data: table === "zad_pharmacy_items" ? [{ id: ITEM_A, name: "جلوكوفاج" }, { id: ITEM_B, name: "كونكور" }] : [],
        error: null,
      }),
      insert: (payload: unknown) => {
        calls.push({ table, op: "insert", payload });
        return Promise.resolve({ error: opts.insertCode ? { code: opts.insertCode, message: "dup" } : null });
      },
      upsert: (payload: unknown) => {
        calls.push({ table, op: "upsert", payload });
        return Promise.resolve({ error: null });
      },
      update: (payload: unknown) => {
        calls.push({ table, op: "update", payload });
        // deno-lint-ignore no-explicit-any
        const u: any = { eq: () => u, then: (ok: (v: unknown) => void) => ok({ error: null }) };
        return u;
      },
    };
    return q;
  };
  const sb = {
    from: query,
    rpc: (fn: string, args: unknown) => {
      calls.push({ table: fn, op: "rpc", payload: args });
      return Promise.resolve({ data: opts.rpc ?? { ok: true, name: "جلوكوفاج" }, error: null });
    },
  };
  return { sb, calls };
}

const moment = { id: MOMENT, moment: "dose_due", facts: { item_ids: [ITEM_A, ITEM_B], scheduled_at: SLOT } };

Deno.test("only the three button answers are actions", () => {
  assert(isDoseAction("taken") && isDoseAction("skipped") && isDoseAction("snooze"));
  assert(!isDoseAction("delete") && !isDoseAction(null));
});

Deno.test("a reminder that is not there writes nothing and says where to log it", async () => {
  const { sb, calls } = fakeSb();
  // deno-lint-ignore no-explicit-any
  const reply = await settleDoseReminder(sb as any, "u1", MOMENT, "taken");
  assert(reply.includes("صفحة الصيدلية"));
  assertEquals(calls, []);
});

Deno.test("snooze holds every medicine of the reminder in its own slot, through the door", async () => {
  const { sb, calls } = fakeSb({ moment });
  // deno-lint-ignore no-explicit-any
  const reply = await settleDoseReminder(sb as any, "u1", MOMENT, "snooze", { source: "telegram", eventKey: "btn-1" });
  assert(reply.includes(String(DOSE_SNOOZE_MINUTES)));
  assert(!calls.some((c) => c.table === "zad_dose_snoozes"), "the snooze table is written by the door only");
  const intents = calls.filter((c) => c.table === "zad_commit_intent").map((c) => (c.payload as { p_intent: Record<string, unknown> }).p_intent);
  assertEquals(intents.map((i) => [i.kind, (i.payload as { item_id: string; scheduled_at: string; minutes: number })]),
    [ITEM_A, ITEM_B].map((id) => ["pharmacy.dose_snoozed", { item_id: id, scheduled_at: SLOT, minutes: DOSE_SNOOZE_MINUTES }]));
  // مفتاحين مختلفين لنفس الزرار (دوا لكل واحد)، وإلا التاني كان هيتعدّ تكرار.
  assertEquals(new Set(intents.map((i) => i.client_event_id)).size, 2);
  assertEquals(intents.map((i) => i.source), ["manual", "manual"]);
});

Deno.test("a door refusal on the snooze says the reminder stays as it was", async () => {
  const { sb } = fakeSb({ moment, rpc: { ok: false, reason: "snooze_minutes_invalid" } });
  // deno-lint-ignore no-explicit-any
  const reply = await settleDoseReminder(sb as any, "u1", MOMENT, "snooze");
  assert(reply.includes("مقدرتش أأجّل"), reply);
});

Deno.test("snoozeDose sends the minutes and slot and returns the door's snooze_until", async () => {
  const until = "2026-10-25T08:30:00.000Z";
  const { sb, calls } = fakeSb({ rpc: { ok: true, duplicate: false, row_id: ITEM_A, payload: { after: { snooze_until: until } } } });
  // deno-lint-ignore no-explicit-any
  const r = await snoozeDose(sb as any, "u1", ITEM_A, SLOT, 30, { source: "app_chat", runId: crypto.randomUUID() });
  assertEquals(r, { ok: true, until, duplicate: false });
  const i = (calls[0].payload as { p_intent: Record<string, unknown> }).p_intent;
  assertEquals([i.kind, i.source, i.payload], ["pharmacy.dose_snoozed", "model", { item_id: ITEM_A, scheduled_at: SLOT, minutes: 30 }]);
  // الباب بيرفض مفتاح أطول من ١٠٠ حرف (لفة بـuuid + الدوا بـuuid كانت ١١٠)، وزرار بمعرّف طويل.
  assert(String(i.client_event_id).length <= 100, String(i.client_event_id).length.toString());
  const longBtn = fakeSb({ rpc: { ok: true, payload: {} } });
  // deno-lint-ignore no-explicit-any
  await snoozeDose(longBtn.sb as any, "u1", ITEM_A, SLOT, 30, { source: "telegram", eventKey: "x".repeat(200) });
  assert(String((longBtn.calls[0].payload as { p_intent: Record<string, string> }).p_intent.client_event_id).length <= 100);
  const refused = fakeSb({ rpc: { ok: false, reason: "item_not_found" } });
  // deno-lint-ignore no-explicit-any
  const bad = await snoozeDose(refused.sb as any, "u1", ITEM_A, SLOT, 30);
  assert(!bad.ok && bad.reason === "item_not_found" && bad.refusal!.includes("item_not_found"));
});

Deno.test("«I skipped it» is an answer, and answering twice is not a failure", async () => {
  // الباب بيرد «اتجاوبت قبل كده» على التانية — ده إجابة مش فشل.
  const { sb, calls } = fakeSb({ moment, rpc: { ok: false, reason: "dose_already_logged" } });
  // deno-lint-ignore no-explicit-any
  const reply = await settleDoseReminder(sb as any, "u1", MOMENT, "skipped");
  assert(reply.includes("مخدتش جرعة"), reply);
  const door = calls.filter((c) => c.op === "rpc" && c.table === "zad_commit_intent");
  assertEquals(door.length, 2);
  const intent = (door[1].payload as { p_intent: { kind: string; payload: { item_id: string } } }).p_intent;
  assertEquals([intent.kind, intent.payload.item_id], ["pharmacy.dose_skipped", ITEM_B]);
  assert(!calls.some((c) => c.table === "zad_pharmacy_doses"), "skip never writes the dose row by hand (م٢.٥)");
});

Deno.test("a skip the door refuses for a real reason is reported, not thanked", async () => {
  const { sb } = fakeSb({ moment, rpc: { ok: false, reason: "item_not_found" } });
  // deno-lint-ignore no-explicit-any
  assert(!(await settleDoseReminder(sb as any, "u1", MOMENT, "skipped")).includes("مخدتش جرعة"));
});

Deno.test("«I took it» goes through the one atomic dose RPC, slot by slot", async () => {
  const { sb, calls } = fakeSb({ moment });
  // deno-lint-ignore no-explicit-any
  const reply = await settleDoseReminder(sb as any, "u1", MOMENT, "taken");
  assert(reply.includes("✅"));
  const rpcs = calls.filter((c) => c.op === "rpc");
  assertEquals(rpcs.map((c) => c.table), ["zad_log_pharmacy_dose_atomic", "zad_log_pharmacy_dose_atomic"]);
  assertEquals((rpcs[1].payload as { p_item: string; p_scheduled_at: string }).p_item, ITEM_B);
  assert(!calls.some((c) => c.table === "zad_pharmacy_doses"), "taken never inserts the dose row by hand");
});

Deno.test("a dose already logged says so instead of thanking twice", async () => {
  const { sb } = fakeSb({ moment, rpc: { ok: true, duplicate: true, name: "جلوكوفاج" } });
  // deno-lint-ignore no-explicit-any
  assert((await settleDoseReminder(sb as any, "u1", MOMENT, "taken")).includes("متسجلة قبل كده"));
});

Deno.test("muting the night question renews one memory row instead of adding one per tap", async () => {
  const fresh = fakeSb({ memory: null });
  // deno-lint-ignore no-explicit-any
  assert(await muteCheckin(fresh.sb as any, "u1"));
  assertEquals(fresh.calls.map((c) => `${c.table}:${c.op}`), ["zad_memory:insert"]);
  assertEquals((fresh.calls[0].payload as { subject_kind: string; scope: string }).subject_kind, "checkin");

  const again = fakeSb({ memory: { id: "m1" } });
  // deno-lint-ignore no-explicit-any
  assert(await muteCheckin(again.sb as any, "u1"));
  assertEquals(again.calls.map((c) => `${c.table}:${c.op}`), ["zad_memory:update"]);
});
