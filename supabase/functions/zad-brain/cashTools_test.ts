// P3.12b: أدوات الكاش. كل أداة بتبعت نوعها للباب، والرفض سؤال واحد، والفلاج مايتبعتش من غير رد العميل.
import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { executeTool } from "./index.ts";
import { CONFIRM_REQUIRED_TOOLS, freshContext, validateTool } from "./validators.ts";
import { CHAT_TOOLS } from "./chatTools.ts";
import { intentToolHints, scopeToolsForSpecialist } from "./specialists.ts";

type Row = Record<string, unknown>;
const RUN = { source: "app_chat", runId: "run-1" } as const;

function fakeDb(door: (intent: Row) => Row) {
  const intents: Row[] = [];
  const directWrites: string[] = [];
  const from = (table: string) => {
    const b: any = {
      select: () => b, eq: () => b, order: () => b, limit: () => b, gte: () => b,
      maybeSingle: () => b, single: () => b,
      insert: () => (directWrites.push(`${table}.insert`), b),
      update: () => (directWrites.push(`${table}.update`), b),
      delete: () => (directWrites.push(`${table}.delete`), b),
      then: (ok: (v: unknown) => unknown) => Promise.resolve({ data: null, error: null }).then(ok),
    };
    return b;
  };
  const rpc = (fn: string, args: Row) => {
    if (fn === "zad_commit_intent") {
      intents.push(args.p_intent as Row);
      return Promise.resolve({ data: door(args.p_intent as Row), error: null });
    }
    return Promise.resolve({ data: null, error: null });
  };
  return { sb: { from, rpc } as any, intents, directWrites };
}
const okDoor = (i: Row): Row => ({ ok: true, duplicate: false, row_id: "t1", payload: { ...(i.payload as Row), after: { id: "t1" } } });
const refuse = (reason: string) => (_i: Row): Row => ({ ok: false, reason });

Deno.test("cash tools are registered, not confirm-required and reachable by intent", () => {
  const names = CHAT_TOOLS.map((t) => t.name);
  assert(names.includes("log_cash_withdrawal") && names.includes("log_cash_spend"));
  assert(!CONFIRM_REQUIRED_TOOLS.includes("log_cash_withdrawal") && !CONFIRM_REQUIRED_TOOLS.includes("log_cash_spend"), "no confirm card: the door asks the one question (owner 2026-11-28)");
  assert(intentToolHints("سحبت ١٠٠٠ من الماكينة").includes("log_cash_withdrawal"));
  assert(intentToolHints("دفعت ٥٠ كاش").includes("log_cash_spend"));
  // بره نطاق الفلوس الافتراضي (سقف ٤٠ أداة)، وبتيجي بالنية بس.
  const scoped = (msg: string) => scopeToolsForSpecialist(CHAT_TOOLS, "finance", null, intentToolHints(msg)).map((t) => t.name);
  assert(!scoped("مرحبا").includes("log_cash_spend"));
  assert(scoped("سحبت ١٠٠٠ من الماكينة").includes("log_cash_withdrawal"));
  assert(scoped("دفعت ٥٠ كاش").includes("log_cash_spend"));
});

Deno.test("log_cash_withdrawal sends money.cash_withdrawn with the model source and writes nothing else", async () => {
  const { sb, intents, directWrites } = fakeDb(okDoor);
  const out = await executeTool(sb, "u1", "log_cash_withdrawal", { amount: 1000 }, {}, freshContext("u1"), RUN);
  assertEquals(intents.length, 1);
  assertEquals(intents[0].kind, "money.cash_withdrawn");
  assertEquals(intents[0].source, "model");
  assertEquals((intents[0].payload as Row).amount, 1000);
  assertEquals(directWrites.filter((w) => w.startsWith("zad_transactions")), []);
  assertStringIncludes(out, "سحب كاش");
});

Deno.test("log_cash_spend sends money.cash_spent; a run without runId is source manual", async () => {
  const { sb, intents } = fakeDb(okDoor);
  await executeTool(sb, "u1", "log_cash_spend", { amount: 50, title: "قهوة" }, {}, freshContext("u1"), RUN);
  await executeTool(sb, "u1", "log_cash_spend", { amount: 60, title: "عيش" }, {}, freshContext("u1"), { source: "app_chat" });
  assertEquals(intents.map((i) => i.kind), ["money.cash_spent", "money.cash_spent"]);
  assertEquals(intents.map((i) => i.source), ["model", "manual"]);
});

Deno.test("withdrawal duplicate: one question, no write, no flag in the same round", async () => {
  const { sb, intents } = fakeDb(refuse("cash_withdrawal_duplicate_suspected"));
  const ctx = freshContext("u1");
  const out = await executeTool(sb, "u1", "log_cash_withdrawal", { amount: 1000 }, {}, ctx, RUN);
  assertStringIncludes(out, "ده نفس السحب اللي إشعار البنك جاب؟");
  assertStringIncludes(out, "ولا حاجة اتكتبت");
  const self = await validateTool("log_cash_withdrawal", { amount: 1000, allow_duplicate: true }, {}, ctx);
  assertEquals(self.ok, false);
  const next = await validateTool("log_cash_withdrawal", { amount: 1000, allow_duplicate: true }, {}, freshContext("u1"));
  assertEquals(next.ok, true);
  assertEquals(intents.length, 1);
});

Deno.test("cash spend matching a bank notice: asks cash-or-card, confirm_cash only after the answer", async () => {
  const seen: Row[] = [];
  const { sb } = fakeDb((i) => {
    seen.push(i.payload as Row);
    return (i.payload as Row).confirm_cash === true ? okDoor(i) : { ok: false, reason: "cash_spend_matches_bank_notice" };
  });
  const ctx = freshContext("u1");
  const out = await executeTool(sb, "u1", "log_cash_spend", { amount: 50, title: "قهوة" }, {}, ctx, RUN);
  assertStringIncludes(out, "دفعتها كاش ولا كارت؟");
  assertEquals((await validateTool("log_cash_spend", { amount: 50, title: "قهوة", confirm_cash: true }, {}, ctx)).ok, false);
  const ok = await executeTool(sb, "u1", "log_cash_spend", { amount: 50, title: "قهوة", confirm_cash: true }, {}, freshContext("u1"), RUN);
  assertStringIncludes(ok, "اتسجّل مصروف كاش");
  assertEquals(seen.map((p) => p.confirm_cash === true), [false, true]);
});

Deno.test("cash tools reject bad amounts before the door", async () => {
  assertEquals((await validateTool("log_cash_withdrawal", { amount: -5 }, {}, freshContext("u1"))).ok, false);
  assertEquals((await validateTool("log_cash_spend", { amount: 10, title: " " }, {}, freshContext("u1"))).ok, false);
});
