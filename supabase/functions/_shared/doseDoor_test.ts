// باب الجرعة والكتم (ZAD_PLAN ٣.٤): نفس سلوك البوت القديم، من مكان واحد.
import { assert, assertEquals } from "jsr:@std/assert@1";
import { DOSE_SNOOZE_MINUTES, isDoseAction, muteCheckin, settleDoseReminder } from "./doseDoor.ts";

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

Deno.test("snooze holds every medicine of the reminder in its own slot", async () => {
  const { sb, calls } = fakeSb({ moment });
  // deno-lint-ignore no-explicit-any
  const reply = await settleDoseReminder(sb as any, "u1", MOMENT, "snooze");
  assert(reply.includes(String(DOSE_SNOOZE_MINUTES)));
  const up = calls.find((c) => c.table === "zad_dose_snoozes" && c.op === "upsert");
  assertEquals((up!.payload as Array<{ item_id: string; scheduled_at: string }>).map((r) => [r.item_id, r.scheduled_at]), [[ITEM_A, SLOT], [ITEM_B, SLOT]]);
});

Deno.test("«I skipped it» is an answer, and answering twice is not a failure", async () => {
  const { sb, calls } = fakeSb({ moment, insertCode: "23505" });
  // deno-lint-ignore no-explicit-any
  const reply = await settleDoseReminder(sb as any, "u1", MOMENT, "skipped");
  assert(reply.includes("مخدتش جرعة"), reply);
  const inserts = calls.filter((c) => c.table === "zad_pharmacy_doses");
  assertEquals(inserts.length, 2);
  assertEquals((inserts[0].payload as { status: string; units: number }).status, "skipped");
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
