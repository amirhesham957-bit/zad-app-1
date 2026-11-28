// P1.7: trace_id الطلب بيدخل نية zad_commit_intent (وبيتكتب في zad_events.trace_id من الباب).
import { assertEquals } from "jsr:@std/assert@1";
import { withTrace } from "../_shared/trace.ts";
import { commitIntent } from "./commitIntent.ts";

function fakeSb() {
  const calls: Array<{ fn: string; args: any }> = [];
  const sb = {
    rpc: (fn: string, args: unknown) => {
      calls.push({ fn, args });
      return Promise.resolve({ data: { ok: true, duplicate: false, row_id: "r1", payload: {} }, error: null });
    },
  };
  return { sb: sb as any, calls };
}
const scope = { source: "chat", runId: "run1" } as any;

Deno.test("commitIntent puts the request trace_id into the rpc intent", async () => {
  const { sb, calls } = fakeSb();
  const r = await withTrace("abcd1234efgh", () =>
    commitIntent(sb, "u1", scope, "add_inventory_item", { n: 1 }, "inventory.add" as any, { item_name: "x" }));
  assertEquals(r.ok, true);
  assertEquals(calls.length, 1);
  assertEquals(calls[0].fn, "zad_commit_intent");
  assertEquals(calls[0].args.p_intent.trace_id, "abcd1234efgh");
});

Deno.test("commitIntent without a request trace sends no trace_id key", async () => {
  const { sb, calls } = fakeSb();
  await commitIntent(sb, "u1", scope, "add_inventory_item", { n: 1 }, "inventory.add" as any, { item_name: "x" });
  assertEquals("trace_id" in calls[0].args.p_intent, false);
});
