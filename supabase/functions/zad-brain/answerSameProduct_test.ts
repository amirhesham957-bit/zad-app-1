// answer_same_product: «أيوه نفس الحاجة» merges for the home through zad_product_merge_for;
// «لأ» records the difference; nothing is merged that the customer did not say.
import { assert, assertEquals } from "jsr:@std/assert@1";
import { executeTool } from "./index.ts";
import { freshContext, validateTool } from "./validators.ts";

function fakeDb() {
  const calls: Array<{ fn: string; args: Record<string, unknown> }> = [];
  const sb = {
    from: () => { throw new Error("no table reads expected"); },
    rpc: (fn: string, args: Record<string, unknown>) => {
      calls.push({ fn, args });
      return Promise.resolve({ data: { ok: true, pantry_rows_merged: 1, list_lines_merged: 0 }, error: null });
    },
  } as any;
  return { sb, calls };
}

Deno.test("«نفس الحاجة» merges the other name into the one kept, for the home", async () => {
  const { sb, calls } = fakeDb();
  const out = await executeTool(sb, "mom", "answer_same_product", { a: "لبن", b: "حليب", same: true }, {}, freshContext("mom"), {} as any);
  assert(out.includes("«لبن»"), out);
  assertEquals(calls, [{ fn: "zad_product_merge_for", args: { p_user: "mom", p_keep: "لبن", p_other: "حليب" } }]);
});

Deno.test("a new name chosen for both merges both into it", async () => {
  const { sb, calls } = fakeDb();
  await executeTool(sb, "mom", "answer_same_product", { a: "عبوة مياه", b: "إزازة ماء", same: true, keep: "مياه" }, {}, freshContext("mom"), {} as any);
  assertEquals(calls.map((c) => c.args.p_other), ["عبوة مياه", "إزازة ماء"]);
  assertEquals(calls.every((c) => c.args.p_keep === "مياه"), true);
});

Deno.test("«مختلفين» is remembered, nothing merged", async () => {
  const { sb, calls } = fakeDb();
  const out = await executeTool(sb, "mom", "answer_same_product", { a: "لبن", b: "لبن رايب", same: false }, {}, freshContext("mom"), {} as any);
  assert(out.includes("مختلفين"), out);
  assertEquals(calls.map((c) => c.fn), ["zad_product_not_same_for"]);
});

Deno.test("the answer must be the customer's: same is required and a boolean", async () => {
  // A fresh run each time: three refusals in one run stop the tool for that run.
  const check = async (input: Record<string, unknown>) => (await validateTool("answer_same_product", input, {}, freshContext("mom"))).ok;
  assertEquals(await check({ a: "لبن", b: "حليب" }), false);
  assertEquals(await check({ a: "لبن", b: "حليب", same: "yes" }), false);
  assertEquals(await check({ a: "ل", b: "حليب", same: true }), false);
  assertEquals(await check({ a: "لبن", b: "حليب", same: true }), true);
});
