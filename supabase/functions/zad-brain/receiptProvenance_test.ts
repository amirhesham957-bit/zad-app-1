// log_transaction writes where the money came from (provenance.ts) and the shop's name:
// a Telegram receipt confirmed by its button lands as source_type «receipt» with the shop
// in merchant_name, like a receipt scanned in the app.
import { assert, assertEquals } from "jsr:@std/assert@1";
import { executeTool } from "./index.ts";
import { freshContext } from "./validators.ts";

function fakeDb() {
  const inserts: Array<{ table: string; row: Record<string, unknown> }> = [];
  const from = (table: string) => {
    let row: Record<string, unknown> | null = null;
    const b: any = {
      select: () => b, eq: () => b, gte: () => b,
      insert: (r: Record<string, unknown>) => ((row = r), inserts.push({ table, row: r }), b),
      then: (resolve: (v: unknown) => unknown) =>
        Promise.resolve({ data: row ? [{ id: "t1", ...row }] : [], error: null }).then(resolve),
    };
    return b;
  };
  return { sb: { from, rpc: () => Promise.resolve({ data: null, error: null }) } as any, inserts };
}

const BASE = { amount: 480, title: "كارفور", category: "البقالة", txn_kind: "expense" };

Deno.test("a confirmed Telegram receipt is written as a receipt, with its shop", async () => {
  const { sb, inserts } = fakeDb();
  const out = await executeTool(sb, "u1", "log_transaction",
    { ...BASE, source_type: "receipt", merchant_name: " كارفور المعادي " },
    {}, freshContext("u1"), { source: "telegram" } as any);
  assert(!out.startsWith("مرفوض"), out);
  const tx = inserts.find((i) => i.table === "zad_transactions")!.row;
  assertEquals([tx.source_type, tx.merchant_name], ["receipt", "كارفور المعادي"]);
});

Deno.test("anything else is its channel, with no shop", async () => {
  const { sb, inserts } = fakeDb();
  await executeTool(sb, "u1", "log_transaction", { ...BASE, source_type: "bank" }, {}, freshContext("u1"), { source: "app_chat" } as any);
  const tx = inserts.find((i) => i.table === "zad_transactions")!.row;
  assertEquals([tx.source_type, tx.merchant_name], ["chat", null]);
});
