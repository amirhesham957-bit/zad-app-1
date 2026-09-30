import { assertEquals } from "jsr:@std/assert@1";
import { executeTool } from "./index.ts";
import { scopeToolsForSpecialist } from "./specialists.ts";
import { freshContext } from "./validators.ts";

// ترندات المنطقة (20260930010000): الحد ٥ بيوت جوه SQL — الأداة بتبعت العميل نفسه والأيام بس.
function fakeSb(answer: unknown) {
  const calls: Array<{ fn: string; args: Record<string, unknown> }> = [];
  // deno-lint-ignore no-explicit-any
  const sb: any = {
    rpc: (fn: string, args: Record<string, unknown>) => {
      calls.push({ fn, args });
      return Promise.resolve({ data: answer, error: null });
    },
  };
  return { sb, calls };
}

Deno.test("area_trends asks SQL for this customer only, days clamped to 7–60, no threshold from the model", async () => {
  const empty = { country: "EG", days: 14, min_households: 5, items: [] };
  const { sb, calls } = fakeSb(empty);
  // deno-lint-ignore no-explicit-any
  const out = await executeTool(sb, "me", "area_trends", { days: 999, p_min: 1 }, {}, freshContext("me"), {} as any);
  assertEquals(calls, [{ fn: "zad_area_trends", args: { p_user: "me", p_days: 60 } }]);
  assertEquals(JSON.parse(out), empty);

  // deno-lint-ignore no-explicit-any
  await executeTool(sb, "me", "area_trends", { days: 2 }, {}, freshContext("me"), {} as any);
  assertEquals(calls[1].args.p_days, 7);
});

Deno.test("the pantry specialist is offered area_trends", () => {
  const tools = [{ name: "area_trends" }, { name: "log_transaction" }, { name: "add_shopping_item" }];
  const names = scopeToolsForSpecialist(tools, "pantry").map((t) => t.name);
  assertEquals(names.includes("area_trends"), true);
});
