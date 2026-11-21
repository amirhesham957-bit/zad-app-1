// المعاملات من الباب الوحيد (ZAD_OR_PLAN م٢.٥، ٢٢/١١): كل أداة فلوس بتبعت نية لـzad_commit_intent بالنوع الصح، والرد
// على رفض باب الشرا (مصروف بنفس المبلغ) فاضل زي ما كان لأن تفاصيله بترجع مع الرفض.
import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { executeTool } from "./index.ts";
import { freshContext } from "./validators.ts";

type Row = Record<string, unknown>;
const RUN = { source: "app_chat", runId: "run-1" } as const;

/** قراية بترجّع صف المعاملة المعروفة، والكتابة كلها نوايا متسجلة. */
function fakeDb(door: (intent: Row) => Row) {
  const intents: Row[] = [];
  const directWrites: string[] = [];
  const tx = { id: "t1", user_id: "u1", amount: 120, title: "بقالة", category: "أخرى", txn_kind: "income", counts_toward_budget: true };
  const from = (table: string) => {
    let single = false;
    let window = false; // نافذة التكرار (آخر ١٠ دقايق): فاضية هنا.
    const b: any = {
      select: () => b, eq: () => b, order: () => b, limit: () => b,
      gte: () => ((window = true), b),
      maybeSingle: () => ((single = true), b), single: () => ((single = true), b),
      insert: () => (directWrites.push(`${table}.insert`), b),
      update: () => (directWrites.push(`${table}.update`), b),
      delete: () => (directWrites.push(`${table}.delete`), b),
      then: (ok: (v: unknown) => unknown) => {
        const rows = table === "zad_transactions" && !window ? [tx] : [];
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
    if (fn === "zad_cash_balance") return Promise.resolve({ data: 100, error: null });
    return Promise.resolve({ data: null, error: null });
  };
  return { sb: { from, rpc } as any, intents, directWrites };
}

const okDoor = (i: Row): Row => ({ ok: true, duplicate: false, row_id: "t1", payload: { ...(i.payload as Row), after: { id: "t1" } } });

Deno.test("money tools: each one sends its intent, and none writes zad_transactions itself", async () => {
  const { sb, intents, directWrites } = fakeDb(okDoor);
  const ctx = () => freshContext("u1");
  await executeTool(sb, "u1", "log_transaction", { amount: 50, title: "قهوة", txn_kind: "expense", wallet: "cash" }, {}, ctx(), RUN);
  await executeTool(sb, "u1", "update_transaction", { transaction_id: "t1", amount: 60, txn_kind: "expense" }, {}, ctx(), RUN);
  await executeTool(sb, "u1", "set_transaction_category", { transaction_id: "t1", category: "مطاعم" }, {}, ctx(), RUN);
  await executeTool(sb, "u1", "allocate_income", { transaction_id: "t1", counts: false }, {}, ctx(), RUN);
  await executeTool(sb, "u1", "merge_duplicate_expense", { drop_id: "t1", keep_id: "t0" }, {}, ctx(), RUN);
  await executeTool(sb, "u1", "delete_transaction", { transaction_id: "t1" }, {}, ctx(), RUN);
  await executeTool(sb, "u1", "reconcile_cash_balance", { reported_amount: 300 }, {}, ctx(), RUN);
  assertEquals(intents.map((i) => i.kind), [
    "money.logged", "money.updated", "money.updated", "money.updated", "money.deleted", "money.deleted", "money.logged",
  ]);
  assertEquals(directWrites.filter((w) => w.startsWith("zad_transactions")), []);
  // is_expense مابيتبعتش: الباب بيحسبه من النوع.
  assertEquals((intents[1].payload as Row).patch, { amount: 60, txn_kind: "expense" });
  // تسوية لفوق = تحويل للكاش، بالفرق.
  const settle = intents[6].payload as Row;
  assertEquals([settle.txn_kind, settle.transfer_to, settle.amount], ["transfer", "cash", 200]);
});

Deno.test("money tools: a purchase refused by the purchase door keeps its old reply, from the refusal's detail", async () => {
  const { sb } = fakeDb(() => ({
    ok: false, reason: "purchase_duplicate_suspected",
    detail: { ok: false, status: "duplicate_suspected", twin: { title: "خضار", created_at: new Date(Date.now() - 3 * 60000).toISOString() } },
  }));
  const out = await executeTool(sb, "u1", "log_transaction", {
    amount: 75, title: "خضار تاني", txn_kind: "expense", lines: [{ name: "خيار", qty: 1, unit: "كيلو", price: 75 }],
  }, {}, freshContext("u1"), RUN);
  assertStringIncludes(out, "بنفس المبلغ (75)");
  assertStringIncludes(out, "\"خضار\"");
  assertStringIncludes(out, "allow_duplicate=true");
});

Deno.test("money tools: a door refusal reaches the model with its reason, and nothing is counted as done", async () => {
  const { sb } = fakeDb(() => ({ ok: false, reason: "title_guessed" }));
  const ctx = freshContext("u1");
  const out = await executeTool(sb, "u1", "log_transaction", { amount: 100, title: "صدقة", txn_kind: "expense" }, {}, ctx, RUN);
  assert(out.startsWith("مرفوض") && out.includes("title_guessed"), out);
  assertEquals(ctx.mutationCount, 0);
});
