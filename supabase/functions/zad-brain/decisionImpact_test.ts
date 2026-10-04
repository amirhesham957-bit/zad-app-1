// أثر قرار كبير على الشهور الجاية — شهر بشهر من متوسط الدخل والصرف الفعلي.
import { assert, assertEquals } from "jsr:@std/assert@1";
import { monthlyAverages, monthLabel, projectDecision } from "./decisionImpact.ts";

const NOW = new Date("2026-10-04T12:00:00Z");
const base = { opening: 8000, avgMonthlyIncome: 10000, avgMonthlySpend: 8000, historyDays: 90, now: NOW };

Deno.test("decision: a new school at 1500 a month on a 2000 surplus is affordable, slower", () => {
  const d = projectDecision({ ...base, decision: { monthly_cost: 1500 } })!;
  assertEquals(d.monthly_surplus_now, 2000);
  assertEquals(d.monthly_surplus_after, 500);
  assertEquals(d.months[0], { month: "2026-10", without: 10000, with: 8500 });
  assertEquals(d.months.at(-1), { month: "2027-03", without: 20000, with: 11000 });
  assertEquals(d.verdict, "affordable");
  assertEquals(d.daily_cut_needed, null);
});

Deno.test("decision: a car's down payment plus instalment goes negative, with the daily cut to break even", () => {
  const d = projectDecision({ ...base, decision: { one_time_cost: 15000, monthly_cost: 3000 } })!;
  assertEquals(d.first_negative, { month: "2026-10", balance: -8000 });
  assertEquals(d.monthly_surplus_after, -1000);
  assertEquals(d.daily_cut_needed, 34);
  assertEquals(d.payback_months, null, "no surplus to pay it back");
  assertEquals(d.verdict, "not_affordable");
});

Deno.test("decision: a one-time trip later in the year is paid back in months", () => {
  const d = projectDecision({ ...base, opening: 1000, decision: { one_time_cost: 6000, start_offset: 3 }, months: 12 })!;
  assertEquals(d.months.length, 12);
  assertEquals(d.months[2].with, d.months[2].without, "nothing changes before the trip");
  assertEquals(d.months[3], { month: "2027-01", without: 9000, with: 3000 });
  assertEquals(d.payback_months, 3);
  assertEquals(d.verdict, "affordable");
});

Deno.test("decision: barely above zero is tight; short history says so; no cost asks nothing", () => {
  const tight = projectDecision({ ...base, opening: 0, decision: { one_time_cost: 1500 } })!;
  assertEquals(tight.lowest.balance, 500);
  assertEquals(tight.verdict, "tight", "under a quarter of a month's spending");
  assertEquals(projectDecision({ ...base, historyDays: 40, decision: { monthly_cost: 100 } })!.confidence, "low");
  assertEquals(projectDecision({ ...base, decision: {} }), null);
  assertEquals(projectDecision({ ...base, decision: { one_time_cost: -500 } }), null, "a negative cost is not a cost");
});

Deno.test("decision: month labels roll over the year", () => {
  assertEquals(monthLabel(NOW, 0), "2026-10");
  assertEquals(monthLabel(NOW, 3), "2027-01");
});

Deno.test("averages: income and spending per month from the last 90 days; transfers are neither", () => {
  const now = Date.parse("2026-10-04T12:00:00Z");
  const day = (d: number) => new Date(now - d * 86_400_000).toISOString();
  const avg = monthlyAverages([
    // The window's first day: 90 days of history make three months.
    { amount: 1, is_expense: true, txn_kind: "expense", created_at: day(90) },
    { amount: 10000, is_expense: false, txn_kind: "income", created_at: day(80) },
    { amount: 10000, is_expense: false, txn_kind: "income", created_at: day(50) },
    { amount: 10000, is_expense: false, txn_kind: "income", created_at: day(20) },
    { amount: 24000, is_expense: true, txn_kind: "expense", created_at: day(40) },
    { amount: 5000, is_expense: true, txn_kind: "transfer", created_at: day(30) },
    { amount: 99999, is_expense: true, txn_kind: "expense", created_at: day(200) },
  ], now);
  assertEquals(avg, { income: 10000, spend: 8000, historyDays: 90 });
  // A two-week-old account counts as one month, not twice its fortnight.
  const young = monthlyAverages([{ amount: 3000, is_expense: true, txn_kind: "expense", created_at: day(14) }], now);
  assertEquals(young.spend, 3000);
  assert(young.historyDays < 60);
});
