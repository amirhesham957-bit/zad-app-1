import { assertEquals } from "jsr:@std/assert@1";
import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { decideLifeEvent } from "./lifeEventDecide.ts";

type Op = { table: string; op: string; data?: unknown; eq: Array<[string, unknown]> };

/** A fake client: one life event row (owned by `owner`), and a record of every write. */
function fake(row: Record<string, unknown> | null, owner: string) {
  const ops: Op[] = [];
  const sb = {
    from(table: string) {
      const q: Op = { table, op: "select", eq: [] };
      const chain: Record<string, unknown> = {
        select: () => chain,
        insert: (data: unknown) => { q.op = "insert"; q.data = data; return chain; },
        update: (data: unknown) => { q.op = "update"; q.data = data; ops.push(q); return chain; },
        eq: (k: string, v: unknown) => { q.eq.push([k, v]); return chain; },
        maybeSingle: () => {
          if (q.op === "insert") { ops.push(q); return Promise.resolve({ data: { id: "appt-1" }, error: null }); }
          const mine = q.eq.some(([k, v]) => k === "user_id" && v === owner);
          return Promise.resolve({ data: mine ? row : null, error: null });
        },
        then: (r: (v: unknown) => unknown) => Promise.resolve({ error: null }).then(r),
      };
      return chain;
    },
  } as unknown as SupabaseClient;
  return { sb, ops };
}

const ahead = new Date(Date.now() + 3 * 86_400_000).toISOString();
const base = { id: "e1", kind: "appointment", title: "موعد تحليل دم", event_at: ahead, place: "معمل البرج", action_hint: null, link: null, status: "proposed", appointment_id: null };

Deno.test("life event: «أيوة» makes one reminded appointment, from the row's own facts", async () => {
  const { sb, ops } = fake(base, "u1");
  assertEquals(await decideLifeEvent(sb, "u1", "e1", true), { ok: true, status: "confirmed", appointment_id: "appt-1" });
  const insert = ops.find((o) => o.op === "insert")!;
  assertEquals(insert.table, "zad_appointments");
  const appt = insert.data as Record<string, unknown>;
  assertEquals([appt.user_id, appt.kind, appt.starts_at, appt.remind_minutes_before, appt.source], ["u1", "medical", ahead, 120, "notification"]);
  const upd = ops.find((o) => o.op === "update")!;
  assertEquals((upd.data as { status: string }).status, "confirmed");
});

Deno.test("life event: someone else's event, a «لأ», a past date or an answered card make no appointment", async () => {
  for (const [row, user, yes, status] of [
    [base, "intruder", true, "not_found"],
    [base, "u1", false, "dismissed"],
    [{ ...base, event_at: new Date(Date.now() - 60_000).toISOString() }, "u1", true, "dismissed"],
    [{ ...base, kind: "result_ready" }, "u1", true, "dismissed"],
    [{ ...base, status: "confirmed", appointment_id: "a0" }, "u1", true, "confirmed"],
  ] as const) {
    const { sb, ops } = fake(row, "u1");
    assertEquals((await decideLifeEvent(sb, user, "e1", yes)).status, status);
    assertEquals(ops.filter((o) => o.op === "insert").length, 0);
  }
});
