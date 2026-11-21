// الاشتراكات والديون والالتزامات من الباب الوحيد (ZAD_OR_PLAN م٢.٥، ٢٢/١١): كل أداة بتبعت نية بالنوع الصح، المطابقة بالاسم
// فاضلة هنا والباب بياخد id، ومفيش كتابة مباشرة على الجداول التلاتة.
import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { executeTool } from "./index.ts";
import { freshContext } from "./validators.ts";

type Row = Record<string, unknown>;
const RUN = { source: "app_chat", runId: "run-1" } as const;

const TABLES: Record<string, Row[]> = {
  zad_subscriptions: [{ id: "s1", title: "نتفلكس", amount: 200, renewal_date: "2026-12-01", due_day: 1, billing_cycle: "MONTHLY", category: null, type: "subscription", is_active: true }],
  zad_debts: [{ id: "d1", name: "سلفة أحمد", remaining_balance: 1500, minimum_payment: 100, is_active: true }],
  zad_obligations: [{ id: "o1", title: "إيجار", amount: 3000, due_day: 1, active: true }],
};

function fakeDb(door: (intent: Row) => Row) {
  const intents: Row[] = [];
  const directWrites: string[] = [];
  const from = (table: string) => {
    let single = false;
    const b: any = {
      select: () => b, eq: () => b, order: () => b, limit: () => b, gte: () => b, or: () => b,
      maybeSingle: () => ((single = true), b), single: () => ((single = true), b),
      insert: () => (directWrites.push(`${table}.insert`), b),
      update: () => (directWrites.push(`${table}.update`), b),
      delete: () => (directWrites.push(`${table}.delete`), b),
      then: (ok: (v: unknown) => unknown) => {
        const rows = TABLES[table] ?? [];
        return Promise.resolve({ data: single ? rows[0] ?? null : rows, error: null }).then(ok);
      },
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

const okDoor = (i: Row): Row => ({ ok: true, duplicate: false, row_id: "x1", payload: { ...(i.payload as Row), after: { id: "x1" } } });
const guarded = (w: string[]) => w.filter((x) => /^zad_(subscriptions|debts|obligations)\./.test(x));

Deno.test("subscription tools: add, update and delete send their intent with the matched id, and write nothing themselves", async () => {
  const { sb, intents, directWrites } = fakeDb(okDoor);
  const ctx = () => freshContext("u1");
  const a = await executeTool(sb, "u1", "add_subscription", { title: "سبوتيفاي", amount: 99.999, renewal_date: "2026-12-15" }, {}, ctx(), RUN);
  const u = await executeTool(sb, "u1", "update_subscription", { title: "نتفلكس", new_amount: 250 }, {}, ctx(), RUN);
  const d = await executeTool(sb, "u1", "delete_subscription", { title: "نتفلكس" }, {}, ctx(), RUN);
  assertEquals(intents.map((i) => i.kind), ["subscription.added", "subscription.updated", "subscription.deleted"]);
  assertEquals(intents[0].payload, { title: "سبوتيفاي", amount: 100, renewal_date: "2026-12-15", category: null, billing_cycle: "MONTHLY" });
  assertEquals(intents[1].payload, { item_id: "s1", patch: { amount: 250 } });
  assertEquals(intents[2].payload, { item_id: "s1" });
  assertStringIncludes(a, "اتضاف اشتراك");
  assertStringIncludes(u, "اتعدل اشتراك");
  assertStringIncludes(d, "اتحذف اشتراك");
  assertEquals(guarded(directWrites), []);
});

Deno.test("mark_subscription_paid: the payment goes through the money door and the renewal through the subscription door", async () => {
  const { sb, intents, directWrites } = fakeDb(okDoor);
  const out = await executeTool(sb, "u1", "mark_subscription_paid", { title: "نتفلكس" }, { now_local: { date: "2026-12-01", utc_offset: "+00:00" } }, freshContext("u1"), RUN);
  assertEquals(intents.map((i) => i.kind), ["money.logged", "subscription.updated"]);
  const p = intents[1].payload as Row;
  assertEquals(p.item_id, "s1");
  assert(typeof (p.patch as Row).renewal_date === "string", JSON.stringify(p));
  assertStringIncludes(out, "اتسجلت دفعة");
  assertEquals(guarded(directWrites), []);
});

Deno.test("debt tools: add, update (zero closes it) and delete go through the door", async () => {
  const { sb, intents, directWrites } = fakeDb(okDoor);
  const ctx = () => freshContext("u1");
  await executeTool(sb, "u1", "add_debt", { name: "قرض", remaining_balance: 900 }, {}, ctx(), RUN);
  const closed = await executeTool(sb, "u1", "update_debt", { name: "سلفة", new_remaining_balance: 0 }, {}, ctx(), RUN);
  await executeTool(sb, "u1", "delete_debt", { name: "سلفة أحمد" }, {}, ctx(), RUN);
  assertEquals(intents.map((i) => i.kind), ["debt.added", "debt.updated", "debt.deleted"]);
  assertEquals(intents[0].payload, { name: "قرض", remaining_balance: 900, minimum_payment: 0, interest_rate: 0, due_day: null });
  assertEquals(intents[1].payload, { item_id: "d1", patch: { remaining_balance: 0, is_active: false } });
  assertStringIncludes(closed, "خلص وقُفل");
  assertEquals(guarded(directWrites), []);
});

Deno.test("obligation tools: add, update, soft delete and confirm all go through the door", async () => {
  const { sb, intents, directWrites } = fakeDb(okDoor);
  const ctx = () => freshContext("u1");
  await executeTool(sb, "u1", "add_obligation", { title: "قسط تابي", amount: 250, kind: "installment", provider: "تابي", total_installments: 6 }, {}, ctx(), RUN);
  await executeTool(sb, "u1", "update_obligation", { title: "إيجار", new_amount: 3500, new_due_day: 5 }, {}, ctx(), RUN);
  await executeTool(sb, "u1", "delete_obligation", { title: "إيجار" }, {}, ctx(), RUN);
  await executeTool(sb, "u1", "confirm_obligation", { kind: "rent" }, { obligation_detection: { title: "إيجار الشقة", amount: 4000, due_day: 3, provider: null } }, ctx(), RUN);
  assertEquals(intents.map((i) => i.kind), ["obligation.added", "obligation.updated", "obligation.deactivated", "obligation.added"]);
  assertEquals((intents[0].payload as Row).total_installments, 6);
  assertEquals(intents[1].payload, { item_id: "o1", patch: { amount: 3500, due_day: 5 } });
  assertEquals(intents[2].payload, { item_id: "o1" });
  assertEquals(intents[3].payload, {
    title: "إيجار الشقة", amount: 4000, kind: "rent", due_day: 3, recurrence: "monthly", auto_detected: true, confirmed: true,
    provider: null, total_installments: null,
  });
  assertEquals(guarded(directWrites), []);
});

Deno.test("subscription, debt and obligation tools: a door refusal reaches the model with its reason and counts for nothing", async () => {
  const { sb } = fakeDb(() => ({ ok: false, reason: "renewal_date_invalid" }));
  const ctx = freshContext("u1");
  const out = await executeTool(sb, "u1", "add_subscription", { title: "سبوتيفاي", amount: 99, renewal_date: "2026-02-30" }, {}, ctx, RUN);
  assert(out.startsWith("مرفوض") && out.includes("renewal_date_invalid"), out);
  assertEquals(ctx.mutationCount, 0);
  const dup = fakeDb(() => ({ ok: true, duplicate: true, row_id: "x1", payload: {} }));
  const again = await executeTool(dup.sb, "u1", "add_debt", { name: "قرض", remaining_balance: 900 }, {}, freshContext("u1"), RUN);
  assertStringIncludes(again, "اتنفذ قبل كده");
});
