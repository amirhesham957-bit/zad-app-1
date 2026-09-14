// وضع الطوارئ «مفلس باقي الشهر» (20260914009000).
import { assert, assertEquals } from "jsr:@std/assert@1";
import { brokeModePlan, isBrokeModeActive, recipeNeedsNoShopping } from "../_shared/brokeMode.ts";
import { freshContext, validateSetBrokeMode } from "./validators.ts";

const NOW = Date.parse("2026-09-14T10:00:00Z");

Deno.test("what the customer says they have beats the ledger, split evenly over the days left", () => {
  const plan = brokeModePlan({ cashLeft: 300, available: 5000, limitConfirmed: true, daysLeft: 16, cycleEnd: "2026-10-01", nowMs: NOW });
  assertEquals(plan.cash_left, 300);
  assertEquals(plan.daily_cap, 18);
  assertEquals(plan.days_left, 16);
  assertEquals(plan.ends_at, "2026-10-01T00:00:00.000Z");
});

Deno.test("without a stated amount it uses the confirmed available balance, never a negative one", () => {
  assertEquals(brokeModePlan({ cashLeft: null, available: 480, limitConfirmed: true, daysLeft: 8, cycleEnd: null, nowMs: NOW }).daily_cap, 60);
  assertEquals(brokeModePlan({ cashLeft: null, available: -200, limitConfirmed: true, daysLeft: 8, cycleEnd: null, nowMs: NOW }).daily_cap, 0);
});

Deno.test("an unconfirmed balance is not trusted: the mode runs with no daily number until they say one", () => {
  const plan = brokeModePlan({ cashLeft: null, available: 999, limitConfirmed: false, daysLeft: 10, cycleEnd: null, nowMs: NOW });
  assertEquals(plan.daily_cap, null);
  assertEquals(plan.ends_at, new Date(NOW + 10 * 86_400_000).toISOString());
});

Deno.test("a cycle end already past falls back to days left, and zero days still means one day", () => {
  const plan = brokeModePlan({ cashLeft: 50, available: null, limitConfirmed: false, daysLeft: 0, cycleEnd: "2026-09-01", nowMs: NOW });
  assertEquals(plan.days_left, 1);
  assertEquals(plan.daily_cap, 50);
  assert(Date.parse(plan.ends_at) > NOW);
});

Deno.test("the mode is active only until it ends or they leave it", () => {
  assert(isBrokeModeActive({ ends_at: "2026-09-20T00:00:00Z", ended_at: null }, NOW));
  assert(!isBrokeModeActive({ ends_at: "2026-09-10T00:00:00Z", ended_at: null }, NOW));
  assert(!isBrokeModeActive({ ends_at: "2026-09-20T00:00:00Z", ended_at: "2026-09-13T00:00:00Z" }, NOW));
  assert(!isBrokeModeActive(null, NOW));
});

Deno.test("broke-mode recipes may use salt, oil and spices but nothing that has to be bought", () => {
  assert(recipeNeedsNoShopping([]));
  assert(recipeNeedsNoShopping(["ملح", "زيت ذرة", "بهارات"]));
  assert(!recipeNeedsNoShopping(["فراخ"]));
  assert(!recipeNeedsNoShopping(["ملح", "طماطم"]));
});

Deno.test("set_broke_mode needs an explicit on/off and a sane amount", async () => {
  assert((await validateSetBrokeMode({ active: true }, {}, freshContext("u1"))).ok);
  assert((await validateSetBrokeMode({ active: true, cash_left: 200 }, {}, freshContext("u1"))).ok);
  assert(!(await validateSetBrokeMode({ active: "yes" }, {}, freshContext("u1"))).ok);
  assert(!(await validateSetBrokeMode({ active: true, cash_left: -5 }, {}, freshContext("u1"))).ok);
});
