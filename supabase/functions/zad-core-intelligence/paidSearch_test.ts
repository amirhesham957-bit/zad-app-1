import { assertEquals } from "jsr:@std/assert@1";
import {
  dailyCap,
  DEFAULT_DAILY_CAP,
  groundingPlan,
  paidSearchKey,
  takeSearchBudget,
} from "./paidSearch.ts";

const env = (vars: Record<string, string>) => (n: string) => vars[n];

Deno.test("the paid key alone runs grounding; the free pool is never asked", () => {
  assertEquals(groundingPlan(env({ ZAD_SEARCH_KEY: " paid " }), ["f1", "f2"]), {
    keys: ["paid"],
    paid: true,
  });
  // Even with the old switch on, the paid key wins.
  assertEquals(
    groundingPlan(env({ ZAD_SEARCH_KEY: "paid", ZAD_GROUNDED_SEARCH: "on" }), [
      "f1",
    ]),
    { keys: ["paid"], paid: true },
  );
});

Deno.test("no paid key: off, unless the explicit switch turns the free pool back on", () => {
  assertEquals(groundingPlan(env({}), ["f1"]), null);
  assertEquals(groundingPlan(env({ ZAD_SEARCH_KEY: "   " }), ["f1"]), null);
  assertEquals(
    groundingPlan(env({ ZAD_GROUNDED_SEARCH: "on" }), ["f1", "f2"]),
    { keys: ["f1", "f2"], paid: false },
  );
  assertEquals(groundingPlan(env({ ZAD_GROUNDED_SEARCH: "on" }), []), null);
  assertEquals(paidSearchKey(env({})), null);
});

Deno.test("the daily cap: a positive whole number, else the default", () => {
  assertEquals(dailyCap(env({})), DEFAULT_DAILY_CAP);
  assertEquals(dailyCap(env({ ZAD_SEARCH_DAILY_CAP: "40" })), 40);
  assertEquals(dailyCap(env({ ZAD_SEARCH_DAILY_CAP: "0" })), DEFAULT_DAILY_CAP);
  assertEquals(
    dailyCap(env({ ZAD_SEARCH_DAILY_CAP: "1.5" })),
    DEFAULT_DAILY_CAP,
  );
  assertEquals(
    dailyCap(env({ ZAD_SEARCH_DAILY_CAP: "lots" })),
    DEFAULT_DAILY_CAP,
  );
});

Deno.test("the budget: granted only on a true from the database, closed on any error", async () => {
  const calls: unknown[] = [];
  const ok = await takeSearchBudget((fn, args) => {
    calls.push([fn, args]);
    return Promise.resolve({ data: true, error: null });
  }, 150);
  assertEquals(ok, true);
  assertEquals(calls, [["zad_search_budget_take", { p_cap: 150 }]]);
  assertEquals(
    await takeSearchBudget(
      () => Promise.resolve({ data: false, error: null }),
      150,
    ),
    false,
  );
  assertEquals(
    await takeSearchBudget(
      () => Promise.resolve({ data: null, error: { message: "down" } }),
      150,
    ),
    false,
  );
  assertEquals(
    await takeSearchBudget(() => Promise.reject(new Error("net")), 150),
    false,
  );
});
