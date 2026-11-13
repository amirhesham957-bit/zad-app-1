import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { CSE_DAILY_CAP_DEFAULT, cseCaps, purposeCap, takeCse } from "./cseBudget.ts";

const env = (vars: Record<string, string>) => (n: string) => vars[n];

Deno.test("defaults: 100 a day, deals get 70", () => {
  assertEquals(cseCaps(env({})), { total: CSE_DAILY_CAP_DEFAULT, deals: 70 });
});

Deno.test("secrets override the cap and the share; bad values fall back", () => {
  assertEquals(cseCaps(env({ ZAD_CSE_DAILY_CAP: "200", ZAD_CSE_DEALS_SHARE: "0.5" })), { total: 200, deals: 100 });
  assertEquals(cseCaps(env({ ZAD_CSE_DAILY_CAP: "-3", ZAD_CSE_DEALS_SHARE: "7" })), { total: 100, deals: 70 });
  assertEquals(cseCaps(env({ ZAD_CSE_DEALS_SHARE: "0" })), { total: 100, deals: 0 });
});

Deno.test("only deals carry their own cap — recipes and chat take from the rest", () => {
  const caps = { total: 100, deals: 70 };
  assertEquals(purposeCap("deals", caps), 70);
  assertEquals(purposeCap("recipes", caps), null);
  assertEquals(purposeCap("other", caps), null);
});

Deno.test("takeCse sends the deal share to the database and obeys a refusal", async () => {
  const sent: Record<string, unknown>[] = [];
  const refuse = (_fn: string, args: Record<string, unknown>) => { sent.push(args); return Promise.resolve({ data: false, error: null }); };
  assertEquals(await takeCse(refuse, "deals", { total: 100, deals: 70 }), { ok: false, note: "budget deals" });
  assertEquals(sent[0], { p_purpose: "deals", p_purpose_cap: 70, p_total_cap: 100 });
  const allow = () => Promise.resolve({ data: true, error: null });
  assertEquals(await takeCse(allow, "recipes", { total: 100, deals: 70 }), { ok: true });
});

Deno.test("an unreadable budget never stops the search", async () => {
  const broken = () => Promise.resolve({ data: null, error: { message: "function zad_cse_take does not exist" } });
  assertEquals((await takeCse(broken, "deals", { total: 100, deals: 70 })).ok, true);
  const threw = () => Promise.reject(new Error("network"));
  assertEquals((await takeCse(threw, "deals", { total: 100, deals: 70 })).ok, true);
});
