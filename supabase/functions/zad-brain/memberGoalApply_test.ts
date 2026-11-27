// م٧.٨: apply_goal_adjustment — الموافقة مربوطة بعرض سيرفر: مقفول = رفض، «أيوه» من غير عرض = رفض، goal_id غير مطابق = رفض،
// عرض منتهي/مستهلك/جديد في نفس اللفة = رفض، طفل = رفض. عرض صح + موافقة = goal.set واحد من الباب بميعاد العرض.
import { assert, assertEquals } from "jsr:@std/assert@1";
import { executeTool } from "./index.ts";
import { recordGoalOffers } from "./memberGoalApply.ts";
import { freshContext } from "./validators.ts";

type Row = Record<string, unknown>;
const D = 86_400_000;
const OFFER_DEADLINE = "2027-01-15";

interface Offer { goal: string; deadline: string; state: "ok" | "expired" | "consumed" | "child_member"; used?: boolean }

function fakeDb(progressKind: "amount" | "tasks", offers: Offer[]) {
  const intents: Row[] = [];
  const directWrites: string[] = [];
  const rpcs: string[] = [];
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
    rpcs.push(fn);
    if (fn === "zad_commit_intent") {
      intents.push(args.p_intent as Row);
      return Promise.resolve({ data: { ok: true, duplicate: false, row_id: "g1", payload: { ...((args.p_intent as Row).payload as Row), after: goal } }, error: null });
    }
    if (fn === "zad_goal_offer_consume") {
      const o = offers.find((x) => x.goal === args.p_goal);
      if (!o) return Promise.resolve({ data: { status: "none" }, error: null });
      if (o.used) return Promise.resolve({ data: { status: "consumed" }, error: null });
      if (o.state !== "ok") return Promise.resolve({ data: { status: o.state }, error: null });
      o.used = true;
      return Promise.resolve({ data: { status: "ok", deadline: o.deadline, offer_id: "o1" }, error: null });
    }
    if (fn === "zad_goal_offer_release") {
      const o = offers[0];
      if (o) o.used = false;
      return Promise.resolve({ data: true, error: null });
    }
    if (fn === "zad_goal_offer_record") {
      return Promise.resolve({ data: args.p_goal === "kid" ? { ok: false, reason: "child_member" } : { ok: true, is_new: args.p_goal === "fresh" }, error: null });
    }
    return Promise.resolve({ data: { ok: true }, error: null });
  };
  return { sb: { from, rpc } as any, intents, directWrites, rpcs, offers };
}

interface RunOpts { kind?: "amount" | "tasks"; flag?: boolean; offers?: Offer[]; input?: Row }
async function run(said: string | undefined, o: RunOpts = {}) {
  const { kind = "amount", flag = true, offers = [{ goal: "g1", deadline: OFFER_DEADLINE, state: "ok" }], input = { goal_id: "g1" } } = o;
  if (flag) Deno.env.set("ZAD_MEMBER_GOALS", "1"); else Deno.env.delete("ZAD_MEMBER_GOALS");
  try {
    const db = fakeDb(kind, offers);
    const ctx = freshContext("u1");
    ctx.said = said;
    const out = await executeTool(db.sb, "u1", "apply_goal_adjustment", input, {}, ctx, { source: "app_chat", runId: "r" } as any);
    return { ...db, out };
  } finally {
    Deno.env.delete("ZAD_MEMBER_GOALS");
  }
}
const refused = (r: { out: unknown; intents: Row[] }) => {
  assert(String(r.out).startsWith("مرفوض"), String(r.out));
  assertEquals(r.intents, []);
};

Deno.test("flag closed: refused, no write", async () => refused(await run("أيوه", { flag: false })));

Deno.test("no explicit approval: refused, no write", async () => refused(await run("طب وإيه اللي هيحصل؟")));

Deno.test("bare approval with no offer on record: refused, no write", async () => {
  for (const said of ["أيوه", "تمام"]) refused(await run(said, { offers: [] }));
});

Deno.test("missing goal_id: refused before touching offers", async () => {
  const r = await run("أيوه", { input: {} });
  refused(r);
  assertEquals(r.rpcs.includes("zad_goal_offer_consume"), false);
});

Deno.test("offer for goal A, goal_id B: refused", async () => {
  refused(await run("أيوه", { offers: [{ goal: "gA", deadline: OFFER_DEADLINE, state: "ok" }], input: { goal_id: "g1" } }));
});

Deno.test("expired offer: refused", async () => refused(await run("أيوه", { offers: [{ goal: "g1", deadline: OFFER_DEADLINE, state: "expired" }] })));

Deno.test("child goal offer: refused", async () => refused(await run("أيوه", { offers: [{ goal: "g1", deadline: OFFER_DEADLINE, state: "child_member" }] })));

Deno.test("model-stated deadline that differs from the server offer: refused and offer released", async () => {
  const offers: Offer[] = [{ goal: "g1", deadline: OFFER_DEADLINE, state: "ok" }];
  const r = await run("أيوه", { offers, input: { goal_id: "g1", deadline_date: "2030-01-01" } });
  refused(r);
  assertEquals(offers[0].used, false);
});

Deno.test("offer first recorded this turn (fresh): refused in the same turn, passes the next turn", async () => {
  const db = fakeDb("amount", [{ goal: "fresh", deadline: OFFER_DEADLINE, state: "ok" }]);
  await recordGoalOffers(db.sb, "u1", [{ goalId: "fresh", deadline: OFFER_DEADLINE }]);
  Deno.env.set("ZAD_MEMBER_GOALS", "1");
  try {
    const ctx = freshContext("u1");
    ctx.said = "أيوه";
    const out = await executeTool(db.sb, "u1", "apply_goal_adjustment", { goal_id: "fresh" }, {}, ctx, { source: "app_chat", runId: "r" } as any);
    assert(String(out).startsWith("مرفوض") && String(out).includes("لسه جديد"), String(out));
    assertEquals(db.intents, []);
    // اللفة الجاية: اللقطة بتعيد تسجيل نفس العرض (مش جديد)، فالرفض بتاع «نفس اللفة» بيختفي
    await recordGoalOffers(db.sb, "u1", [{ goalId: "g1", deadline: OFFER_DEADLINE }]);
    const out2 = await executeTool(db.sb, "u1", "apply_goal_adjustment", { goal_id: "fresh" }, {}, freshContext("u1"), { source: "app_chat", runId: "r" } as any);
    assert(!String(out2).includes("لسه جديد"), String(out2));
  } finally {
    Deno.env.delete("ZAD_MEMBER_GOALS");
  }
});

Deno.test("recordGoalOffers: child/refused goals are not offered", async () => {
  const db = fakeDb("amount", []);
  const ok = await recordGoalOffers(db.sb, "u2", [{ goalId: "kid", deadline: OFFER_DEADLINE }, { goalId: "g1", deadline: OFFER_DEADLINE }]);
  assertEquals([...ok], ["g1"]);
});

Deno.test("approved with a matching offer: one goal.set through the door at the offer deadline, then the offer can't be reused", async () => {
  for (const kind of ["amount", "tasks"] as const) {
    const offers: Offer[] = [{ goal: "g1", deadline: OFFER_DEADLINE, state: "ok" }];
    const r = await run("أيوه", { kind, offers, input: { goal_id: "g1", deadline_date: OFFER_DEADLINE } });
    assertEquals(r.intents.length, 1, String(r.out));
    assertEquals(r.intents[0].kind, "goal.set");
    const p = r.intents[0].payload as Row;
    assertEquals([p.title, p.target_value, p.unit, p.deadline_date], ["توفير للعيد", 1000, kind === "amount" ? "money" : "count", OFFER_DEADLINE]);
    assertEquals(r.directWrites.filter((w) => /^agent_goals\./.test(w)), []);
    // نفس العرض تاني (consumed) = رفض
    refused(await run("أيوه", { kind, offers }));
  }
});
