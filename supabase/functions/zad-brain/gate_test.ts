import { assertEquals } from "jsr:@std/assert@1";
import { type ChatCharge, chatBodyEmpty, openChatCharge, withChargeSettlement } from "./gate.ts";

// دفتر وهمي بنفس ضمانات SQL: الاستهلاك ذرّي، والرجوع open -> refunded مرة واحدة.
function fakeDb(balance: number, opts: { consumeError?: boolean; openError?: boolean } = {}) {
  const ledger = new Map<string, string>();
  const calls: string[] = [];
  let n = 0;
  const sb = {
    rpc(fn: string, args: Record<string, unknown>) {
      calls.push(fn);
      switch (fn) {
        case "zad_entitlement_consume":
          if (opts.consumeError) return Promise.resolve({ data: null, error: { message: "boom" } });
          if (balance <= 0) return Promise.resolve({ data: { allowed: false, reason: "no_quota" }, error: null });
          balance--;
          return Promise.resolve({ data: { allowed: true, reason: "quota" }, error: null });
        case "zad_energy_open": {
          if (opts.openError) return Promise.resolve({ data: null, error: { message: "ledger down" } });
          const id = `c${++n}`;
          ledger.set(id, "open");
          return Promise.resolve({ data: id, error: null });
        }
        case "zad_energy_done":
          if (ledger.get(args.p_id as string) === "open") ledger.set(args.p_id as string, "done");
          return Promise.resolve({ data: true, error: null });
        case "zad_energy_refund":
          if (ledger.get(args.p_id as string) === "open") {
            ledger.set(args.p_id as string, "refunded");
            balance++;
          }
          return Promise.resolve({ data: true, error: null });
        case "zad_entitlement_refund":
          balance++;
          return Promise.resolve({ data: true, error: null });
      }
      return Promise.resolve({ data: null, error: null });
    },
  };
  return { sb, ledger, calls, balance: () => balance };
}

const ok = () => new Response(JSON.stringify({ ok: true, reply: "أهلاً", executed: [], proposals: [] }));
const turn = (db: ReturnType<typeof fakeDb>, run: () => Promise<Response>) =>
  (async () => {
    const charge: ChatCharge = {};
    const d = await openChatCharge(db.sb, "u1", "chat", "UTC", charge);
    if (!d.allowed) return d;
    return await withChargeSettlement(db.sb, "u1", charge, run);
  })();

Deno.test("success: charges once and closes done", async () => {
  const db = fakeDb(3);
  await turn(db, () => Promise.resolve(ok()));
  assertEquals(db.balance(), 2);
  assertEquals([...db.ledger.values()], ["done"]);
});

Deno.test("model throws: refunded exactly once, error rethrown", async () => {
  const db = fakeDb(3);
  let thrown = false;
  try {
    await turn(db, () => Promise.reject(new Error("model down")));
  } catch {
    thrown = true;
  }
  assertEquals(thrown, true);
  assertEquals(db.balance(), 3);
  assertEquals([...db.ledger.values()], ["refunded"]);
  assertEquals(db.calls.filter((c) => c === "zad_energy_refund").length, 1);
});

Deno.test("empty reply and model_unavailable are refunded", async () => {
  for (
    const body of [
      { ok: true, reply: "  ", executed: [], proposals: [] },
      { ok: false, error: "model_unavailable", reply: "" },
    ]
  ) {
    const db = fakeDb(2);
    await turn(db, () => Promise.resolve(new Response(JSON.stringify(body))));
    assertEquals(db.balance(), 2);
    assertEquals([...db.ledger.values()], ["refunded"]);
  }
});

Deno.test("empty text but a write happened keeps the charge", async () => {
  const db = fakeDb(2);
  await turn(db, () => Promise.resolve(new Response(JSON.stringify({ ok: true, reply: "", executed: [{ tool: "x" }] }))));
  assertEquals(db.balance(), 1);
  assertEquals([...db.ledger.values()], ["done"]);
});

Deno.test("two parallel turns on the last attempt: one runs, one is locked, balance never double-counted", async () => {
  const db = fakeDb(1);
  const [a, b] = await Promise.all([turn(db, () => Promise.resolve(ok())), turn(db, () => Promise.resolve(ok()))]);
  const locked = [a, b].filter((r) => !(r instanceof Response));
  assertEquals(locked.length, 1);
  assertEquals(db.balance(), 0);
  assertEquals([...db.ledger.values()], ["done"]);
});

Deno.test("settling twice refunds once", async () => {
  const db = fakeDb(1);
  const charge: ChatCharge = {};
  await openChatCharge(db.sb, "u1", "chat", "UTC", charge);
  const { settleChatCharge } = await import("./gate.ts");
  await Promise.all([
    settleChatCharge(db.sb, charge, "refund", "u1"),
    settleChatCharge(db.sb, charge, "refund", "u1"),
  ]);
  assertEquals(db.balance(), 1);
  assertEquals(db.calls.filter((c) => c === "zad_energy_refund").length, 1);
});

Deno.test("fail-open: consume RPC error lets the turn through, nothing to settle", async () => {
  const db = fakeDb(0, { consumeError: true });
  const charge: ChatCharge = {};
  const d = await openChatCharge(db.sb, "u1", "chat", "UTC", charge);
  assertEquals(d.allowed, true);
  assertEquals(d.reason, "gate_unavailable");
  await withChargeSettlement(db.sb, "u1", charge, () => Promise.reject(new Error("x"))).catch(() => {});
  assertEquals(db.calls, ["zad_entitlement_consume"]);
});

Deno.test("ledger open failure: old behaviour, refund by user and kind", async () => {
  const db = fakeDb(2, { openError: true });
  await turn(db, () => Promise.resolve(new Response(JSON.stringify({ ok: false, error: "model_unavailable" }))));
  assertEquals(db.calls.includes("zad_entitlement_refund"), true);
  assertEquals(db.balance(), 2);
});

Deno.test("locked request is not charged or settled", async () => {
  const db = fakeDb(0);
  await turn(db, () => Promise.resolve(ok()));
  assertEquals(db.calls, ["zad_entitlement_consume"]);
});

Deno.test("index.ts wires the gate: opens inside the lane, settles around both lane calls, no bare consume", async () => {
  const src = await Deno.readTextFile(new URL("./index.ts", import.meta.url));
  assertEquals(src.includes("openChatCharge(sb, userId, entitlementKind"), true);
  assertEquals(src.match(/withChargeSettlement\(sb, userId, charge, \(\) => inLane\(/g)?.length, 2);
  assertEquals(src.includes("consumeEntitlement("), false, "a bare consume would charge with no refund");
});

Deno.test("chatBodyEmpty", () => {
  assertEquals(chatBodyEmpty(200, { ok: true, reply: "hi" }), false);
  assertEquals(chatBodyEmpty(500, null), true);
  assertEquals(chatBodyEmpty(200, "x"), false);
});
