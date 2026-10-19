import { assertEquals } from "jsr:@std/assert@1";
import {
  budgetUsage,
  withPaidGroundingFirst,
  dailyCap,
  DEFAULT_DAILY_CAP,
  groundingPlan,
  keyRefused,
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

Deno.test("usage: today, the last seven days and the month, from the daily rows", () => {
  const rows = [
    { day: "2026-10-18", used: 4 },
    { day: "2026-10-12", used: 10 },
    { day: "2026-10-11", used: 100 },
    { day: "2026-09-30", used: 1000 },
  ];
  assertEquals(budgetUsage(rows, "2026-10-18", 150), {
    daily_cap: 150,
    today: 4,
    last_7_days: 14,
    month: 114,
    monthly_free: 5000,
  });
  assertEquals(budgetUsage([], "2026-10-01", 150).month, 0);
});

Deno.test("with the paid key, a fresh question asks the grounded search first", () => {
  const chain: Array<[string, number]> = [["search_api", 1], ["gemini_google_search", 2], ["wikipedia", 3]];
  assertEquals(withPaidGroundingFirst(chain, true, true).map(([n]) => n), ["gemini_google_search", "search_api", "wikipedia"]);
});

Deno.test("a settled question, or no paid key, keeps the free sources first", () => {
  const chain: Array<[string, number]> = [["search_api", 1], ["gemini_google_search", 2], ["wikipedia", 3]];
  assertEquals(withPaidGroundingFirst(chain, true, false), chain);
  assertEquals(withPaidGroundingFirst(chain, false, true), chain);
});

Deno.test("a key the project refuses stops the walk; a model's own refusal does not", () => {
  // What every paid call answered on 2026-10-18 from 17:38.
  assertEquals(
    keyRefused(403, '{"error":{"code":403,"message":"Gemini API has not been used in project 1 before or it is disabled."}}'),
    true,
  );
  assertEquals(keyRefused(401, ""), true);
  assertEquals(keyRefused(400, '{"error":{"message":"API key not valid. Please pass a valid API key.","status":"INVALID_ARGUMENT"}}'), true);
  // Quota is per model (CLAUDE.md): the next model may still answer.
  assertEquals(keyRefused(429, "RESOURCE_EXHAUSTED"), false);
  assertEquals(keyRefused(400, '{"error":{"message":"thinkingConfig is not supported"}}'), false);
  assertEquals(keyRefused(503, ""), false);
});
