import { assert, assertEquals } from "jsr:@std/assert@1";
import { describeSafeSpend } from "./safeSpendTool.ts";
import { guardEngineReply } from "./engineGuard.ts";
import { intentToolHints } from "./specialists.ts";
import type { SpendRow } from "./paydayOdds.ts";

const TODAY = "2026-11-22";
const TZ = "Africa/Cairo";
const daily = (n: number, amount: number): SpendRow[] =>
  Array.from({ length: n }, (_, i) => {
    const d = new Date(Date.UTC(2026, 10, 21 - i, 12));
    return { amount, txn_kind: "expense", created_at: d.toISOString() };
  });

Deno.test("under 14 spend days: «تقريباً», no probability", () => {
  const t = describeSafeSpend({ available: 1000, days_left: 10, currency: "EGP" }, daily(5, 50), TODAY, TZ);
  assert(t.includes("100 EGP في اليوم"));
  assert(t.includes("تقريباً"));
  assert(!t.includes("احتمال يوصل"));
});

Deno.test("14+ spend days: a rounded probability, 1000 paths", () => {
  const t = describeSafeSpend({ available: 1000, days_left: 10, currency: "EGP" }, daily(20, 50), TODAY, TZ);
  assert(t.includes("حوالي 100٪"));
  assert(t.includes("1000 مسار"));
  assert(!t.includes("تقريباً"));
  const low = describeSafeSpend({ available: 400, days_left: 10, currency: "EGP" }, daily(20, 50), TODAY, TZ);
  assert(low.includes("حوالي 0٪"));
});

Deno.test("no ceiling and exhausted budget are honest", () => {
  assert(describeSafeSpend({ available: null }, [], TODAY, TZ).startsWith("مفيش سقف"));
  assert(describeSafeSpend({ available: -20, days_left: 5 }, daily(20, 50), TODAY, TZ).includes("مفيش مصروف آمن"));
});

Deno.test("the number guard replaces an invented figure, keeps the tool's", () => {
  const t = describeSafeSpend({ available: 1000, days_left: 10, currency: "EGP" }, daily(5, 50), TODAY, TZ);
  const out = [{ tool: "safe_daily_spend", content: t }];
  assertEquals(guardEngineReply("تصرف 100 في اليوم تقريباً", "؟", out).replaced, false);
  assertEquals(guardEngineReply("تصرف 175 في اليوم", "؟", out).replaced, true);
});

Deno.test("«اصرف كام النهارده» reaches safe_daily_spend", () => {
  assertEquals(intentToolHints("اصرف كام النهارده").includes("safe_daily_spend"), true);
  assertEquals(intentToolHints("المصروف الآمن كام؟").includes("safe_daily_spend"), true);
  assertEquals(intentToolHints("صباح الخير").includes("safe_daily_spend"), false);
});
