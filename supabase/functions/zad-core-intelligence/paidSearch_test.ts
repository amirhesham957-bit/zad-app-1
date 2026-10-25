import { assertEquals } from "jsr:@std/assert@1";
import {
  budgetUsage,
  encyclopediaFirstForLatest,
  withPaidGroundingFirst,
  dailyCap,
  DEFAULT_DAILY_CAP,
  groundingPlan,
  keyRefused,
  paidQuotaExhausted,
  paidSearchKey,
  tavilyFirstWhileGroundingRests,
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

// 2026-10-24: Tavily's first answer for «آخر مرة» was the 2023 winner; the encyclopedia ranks the newest edition.
Deno.test("«آخر مرة» asks the encyclopedia before the keyed search; other questions keep their order", () => {
  const chain: Array<[string, number]> = [["gemini_google_search", 0], ["search_api", 1], ["wikipedia", 2], ["bing_news", 3]];
  assertEquals(encyclopediaFirstForLatest(chain, true).map(([n]) => n), ["gemini_google_search", "wikipedia", "search_api", "bing_news"]);
  assertEquals(encyclopediaFirstForLatest(chain, false), chain);
  // A chain where the encyclopedia already leads, or is absent (a live question), is left alone.
  const live: Array<[string, number]> = [["bing_news", 0], ["search_api", 1], ["google_news", 2]];
  assertEquals(encyclopediaFirstForLatest(live, true), live);
});

// 2026-10-25: the unbilled paid project answered 429 on all four models; each try took one unit of the cap.
Deno.test("a 429 on the paid key ends grounding for now; on the free pool it is one model's quota", () => {
  assertEquals(paidQuotaExhausted(429, true), true);
  assertEquals(paidQuotaExhausted(429, false), false);
  assertEquals(paidQuotaExhausted(503, true), false);
});

Deno.test("while grounding rests Tavily leads, and «آخر مرة» still asks the encyclopedia before it", () => {
  const chain: Array<[string, number]> = [["search_api", 0], ["tavily", 1], ["gemini_google_search", 2], ["wikipedia", 3], ["bing_news", 4]];
  assertEquals(tavilyFirstWhileGroundingRests(chain, false), chain);
  const resting = tavilyFirstWhileGroundingRests(chain, true);
  assertEquals(resting.map(([n]) => n), ["tavily", "search_api", "gemini_google_search", "wikipedia", "bing_news"]);
  assertEquals(encyclopediaFirstForLatest(resting, true).map(([n]) => n), ["wikipedia", "tavily", "search_api", "gemini_google_search", "bing_news"]);
  // A live question: Tavily ahead of the news.
  const live: Array<[string, number]> = [["bing_news", 0], ["search_api", 1], ["tavily", 2], ["google_news", 3]];
  assertEquals(tavilyFirstWhileGroundingRests(live, true).map(([n]) => n), ["tavily", "bing_news", "search_api", "google_news"]);
});
