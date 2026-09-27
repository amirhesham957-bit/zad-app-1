import { assert, assertEquals, assertStringIncludes } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { CHILD_BLOCKED_TOOLS, freshContext, isChildSnapshot, validateTool } from "./validators.ts";

const child = { family: { mine: { role: "child", alias: "سارة", balance: 40, savings_goal: 100 } } };
const parent = { family: { mine: { role: "admin", alias: "بابا", balance: 0, savings_goal: 0 } } };

Deno.test("a child's snapshot is recognised, and only a child's", () => {
  assert(isChildSnapshot(child));
  assert(!isChildSnapshot(parent));
  assert(!isChildSnapshot({}), "no family: an ordinary adult account");
});

Deno.test("every money tool is refused for a child, before its own validator runs", async () => {
  for (const tool of CHILD_BLOCKED_TOOLS) {
    const ctx = freshContext("kid");
    const v = await validateTool(tool, {}, child, ctx);
    assertEquals(v.ok, false, tool);
    if (!v.ok) assertStringIncludes(v.reason, "حساب طفل");
    assert(ctx.abortedTools.has(tool), `${tool}: retrying cannot change the role`);
  }
});

Deno.test("the ledger and the budget are among them", () => {
  for (const tool of ["log_transaction", "update_transaction", "delete_transaction", "set_monthly_limit", "add_debt", "add_subscription"]) {
    assert(CHILD_BLOCKED_TOOLS.includes(tool), tool);
  }
});

Deno.test("a child keeps the pantry, reminders and a savings challenge", async () => {
  for (const tool of ["add_shopping_item", "add_appointment", "start_savings_challenge", "remember"]) {
    const v = await validateTool(tool, {}, child, freshContext("kid"));
    if (!v.ok) assert(!v.reason.includes("حساب طفل"), `${tool} was refused as a child's: ${v.reason}`);
  }
});

Deno.test("a parent is not stopped by the child rule", async () => {
  const v = await validateTool("set_monthly_limit", {}, parent, freshContext("dad"));
  if (!v.ok) assert(!v.reason.includes("حساب طفل"), v.reason);
});
