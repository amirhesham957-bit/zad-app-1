// كتابة ذاكرة «نسخة واحدة» (ZAD_OR_PLAN م١، ٢٠٢٦-١١-٢٠): بتعدي على zad_memory_replace_single في transaction
// واحدة، ومن غير ما تمسح الأول. الطريقة القديمة (مسح ثم إدراج) بتشتغل بس لو الدالة لسه مش على الداتابيز.
import { assertEquals } from "jsr:@std/assert@1";
import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { isMissingFunction, writeSingleCopyMemory } from "./index.ts";

type Call = { op: string; args?: unknown };

function fakeClient(rpcError: { code: string; message: string } | null) {
  const calls: Call[] = [];
  const chain = (op: string) => {
    const q: Record<string, unknown> = {};
    const self = new Proxy(q, {
      get(_t, prop) {
        if (prop === "then") return (ok: (v: unknown) => unknown) => ok({ data: null, error: null });
        return (...args: unknown[]) => {
          if (prop === "delete" || prop === "insert") calls.push({ op: `${op}.${String(prop)}`, args: args[0] });
          return self;
        };
      },
    });
    return self;
  };
  const sb = {
    rpc: (name: string, args: unknown) => {
      calls.push({ op: `rpc:${name}`, args });
      if (name === "zad_memory_replace_single") {
        return Promise.resolve(rpcError ? { data: null, error: rpcError } : { data: "note-1", error: null });
      }
      return Promise.resolve({ data: null, error: null });
    },
    from: (table: string) => chain(table),
  };
  return { sb: sb as unknown as SupabaseClient, calls };
}

Deno.test("single-copy memory: one atomic call, nothing deleted from the client", async () => {
  const { sb, calls } = fakeClient(null);
  const res = await writeSingleCopyMemory(sb, "u1", "persona", "بيحب القهوة", 0.8);
  assertEquals(res.error, null);
  assertEquals(calls[0], {
    op: "rpc:zad_memory_replace_single",
    args: { p_user: "u1", p_scope: "persona", p_note: "بيحب القهوة", p_confidence: 0.8 },
  });
  assertEquals(calls.filter((c) => c.op.endsWith(".delete")).length, 0);
});

Deno.test("single-copy memory: falls back to delete-then-insert only while the function is not deployed", async () => {
  const { sb, calls } = fakeClient({ code: "PGRST202", message: "not found" });
  const res = await writeSingleCopyMemory(sb, "u1", "persona", "x", 0.5);
  assertEquals(res.error, null);
  assertEquals(calls.map((c) => c.op).filter((o) => o.startsWith("zad_memory.")), ["zad_memory.delete", "zad_memory.insert"]);
});

Deno.test("single-copy memory: any other error is returned and nothing is deleted", async () => {
  const { sb, calls } = fakeClient({ code: "57014", message: "timeout" });
  const res = await writeSingleCopyMemory(sb, "u1", "persona", "x", 0.5);
  assertEquals((res.error as { code: string }).code, "57014");
  assertEquals(calls.filter((c) => c.op.endsWith(".delete")).length, 0);
});

Deno.test("isMissingFunction knows PostgREST's and Postgres's codes only", () => {
  assertEquals(isMissingFunction({ code: "PGRST202" }), true);
  assertEquals(isMissingFunction({ code: "42883" }), true);
  assertEquals(isMissingFunction({ code: "42501" }), false);
  assertEquals(isMissingFunction(null), false);
});
