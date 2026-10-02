// سؤال عام واحد خد ٧٤ ألف توكن والموديل بيعيد البحث (٢٠٢٦-١٠-٠٢): مرتين في الرسالة بالكتير.
import { assert, assertStringIncludes } from "jsr:@std/assert@1";
import { executeTool, MAX_SEARCHES_PER_TURN } from "./index.ts";
import { freshContext } from "./validators.ts";

Deno.test("a third search in one message is told to answer instead", async () => {
  const ctx = freshContext("u");
  ctx.counts["web_search"] = MAX_SEARCHES_PER_TURN + 1;
  // No network and no database: the cap answers before either is touched.
  const out = await executeTool(null as never, "u", "web_search", { query: "مين كسب" }, {}, ctx, { source: "app_chat" } as never);
  assertStringIncludes(out, "بحثت مرتين");
  assert(!out.includes("http"));
});
