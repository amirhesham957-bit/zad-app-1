import { assert, assertEquals, assertNotEquals } from "jsr:@std/assert@1";
import { currentTraceId, TRACE_HEADER, traceIdOf, withTrace, withTraceHeaders } from "./trace.ts";

const req = (h?: string) => new Request("http://x", { headers: h === undefined ? {} : { [TRACE_HEADER]: h } });

Deno.test("traceIdOf keeps a valid header", () => {
  assertEquals(traceIdOf(req("abcd1234-EFGH_5678")), "abcd1234-EFGH_5678");
});
Deno.test("traceIdOf replaces a missing or malformed header with a fresh dashless uuid", () => {
  for (const bad of [undefined, "short", "has space in it!!", "x".repeat(65), "bad/chars/here"]) {
    const id = traceIdOf(req(bad));
    assert(/^[0-9a-f]{32}$/.test(id), `${bad} -> ${id}`);
  }
  assertNotEquals(traceIdOf(req()), traceIdOf(req()));
});
Deno.test("withTraceHeaders adds the header and keeps the rest", () => {
  const h = withTraceHeaders({ Authorization: "Bearer t" }, "abcd1234");
  assertEquals(h.get(TRACE_HEADER), "abcd1234");
  assertEquals(h.get("authorization"), "Bearer t");
  assertEquals(withTraceHeaders(undefined, "abcd1234").get(TRACE_HEADER), "abcd1234");
});
Deno.test("withTrace carries the id across awaits and is empty outside", async () => {
  assertEquals(currentTraceId(), null);
  await withTrace("abcd1234", async () => {
    await new Promise((r) => setTimeout(r, 1));
    assertEquals(currentTraceId(), "abcd1234");
  });
  assertEquals(currentTraceId(), null);
});
