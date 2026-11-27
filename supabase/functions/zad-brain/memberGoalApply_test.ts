// م٧.٨: apply_goal_adjustment — مقفول = رفض، من غير موافقة صريحة = رفض، بموافقة = goal.set من الباب بميعاد السيرفر.
import { assert, assertEquals } from "jsr:@std/assert@1";
import { executeTool } from "./index.ts";
import { freshContext } from "./validators.ts";

type Row = Record<string, unknown>;
const D = 86_400_000;

function fakeDb(progressKind: "amount" | "tasks") {
  const intents: Row[] = [];
  const directWrites: string[] = [];
  const created = new Date(Date.now() - 15 * D).toISOString();
  const goal = { id: "g1", title: "توفير للعيد", metric: null, target_value: 1000, deadline_date: new Date(Date.now() + 40 * D).toISOString().slice(0, 10), created_at: created, progress_kind: progressKind };
  const from = (table: string) => {
    let single = false;
    const b: any = {
      select: () => b, eq: () => b, order: () => b, limit: () => b, gte: () => b, in: () => b,
      maybeSingle: () => ((single = true), b), single: () => ((single = true), b),
      insert: () => (directWrites.push(`${table}.insert`), b), update: () => (directWrites.push(`${table}.update`), b),
      delete: () => (directWrites.push(`${table}.delete`), b), upsert: () => (directWrites.push(`${table}.upsert`), b),
      then: (ok: (v: unknown) => unknown) => {
        const rows = table === "agent_goals" ? [goal]
          : table === "zad_events" ? [{ occurred_at: new Date(Date.now() - 14 * D).toISOString(), payload: { row_id: "g1", amount: 5 } }]
          : table === "agent_tasks" ? [{ goal_id: "g1", updated_at: new Date(Date.now() - 14 * D).toISOString() }]
          : [];
        return Promise.resolve({ data: single ? rows[0] ?? null : rows, error: null }).then(ok);
      },
    };
    return b;
  };
  const rpc = (fn: string, args: Row) => {
    if (fn === "zad_commit_intent") {
      intents.push(args.p_intent as Row);
      return Promise.resolve({ data: { ok: true, duplicate: false, row_id: "g1", payload: { ...((args.p_intent as Row).payload as Row), after: goal } }, error: null });
    }
    return Promise.resolve({ data: { ok: true }, error: null });
  };
  return { sb: { from, rpc } as any, intents, directWrites };
}

async function run(said: string | undefined, kind: "amount" | "tasks", flag: boolean) {
  if (flag) Deno.env.set("ZAD_MEMBER_GOALS", "1"); else Deno.env.delete("ZAD_MEMBER_GOALS");
  try {
    const db = fakeDb(kind);
    const ctx = freshContext("u1");
    ctx.said = said;
    const out = await executeTool(db.sb, "u1", "apply_goal_adjustment", { goal_title: "توفير للعيد" }, {}, ctx, { source: "app_chat", runId: "r" } as any);
    return { ...db, out };
  } finally {
    Deno.env.delete("ZAD_MEMBER_GOALS");
  }
}

Deno.test("flag closed: refused, no write", async () => {
  const r = await run("أيوه", "amount", false);
  assert(String(r.out).startsWith("مرفوض"));
  assertEquals(r.intents, []);
});

Deno.test("no explicit approval: refused, no write", async () => {
  const r = await run("طب وإيه اللي هيحصل؟", "amount", true);
  assert(String(r.out).startsWith("مرفوض"));
  assertEquals(r.intents, []);
});

Deno.test("approved: one goal.set through the door, target unchanged, deadline from server, no direct write", async () => {
  for (const kind of ["amount", "tasks"] as const) {
    const r = await run("أيوه", kind, true);
    assertEquals(r.intents.length, 1, String(r.out));
    assertEquals(r.intents[0].kind, "goal.set");
    const p = r.intents[0].payload as Row;
    assertEquals([p.title, p.target_value, p.unit], ["توفير للعيد", 1000, kind === "amount" ? "money" : "count"]);
    assert(String(p.deadline_date) > new Date(Date.now() + 40 * D).toISOString().slice(0, 10));
    assertEquals(r.directWrites.filter((w) => /^agent_goals\./.test(w)), []);
  }
});
