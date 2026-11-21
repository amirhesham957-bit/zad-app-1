import { assertEquals } from "jsr:@std/assert@1";
import { dailySpendSeries, paydayOdds, type SpendRow } from "./paydayOdds.ts";

const TODAY = "2026-11-22";
const CAIRO = "Africa/Cairo";
const at = (day: string, hourUtc = 10) => `${day}T${String(hourUtc).padStart(2, "0")}:00:00Z`;
const exp = (day: string, amount: number, extra: Partial<SpendRow> = {}): SpendRow =>
  ({ amount, txn_kind: "expense", created_at: at(day), ...extra });
/** n consecutive spending days ending yesterday, `amount` each. */
const daily = (n: number, amount: number): SpendRow[] =>
  Array.from({ length: n }, (_, i) => exp(new Date(Date.UTC(2026, 10, 21 - i)).toISOString().slice(0, 10), amount));

Deno.test("series runs from the first spending day to yesterday; quiet days inside count as zero", () => {
  const { series, spendDays } = dailySpendSeries([exp("2026-11-18", 50), exp("2026-11-20", 30), exp("2026-11-20", 20)], TODAY, CAIRO);
  assertEquals(series, [50, 0, 50, 0]);
  assertEquals(spendDays, 2);
});

Deno.test("today, income, transfers, obligation payments and anything older than 28 days stay out", () => {
  const rows: SpendRow[] = [
    exp("2026-11-21", 10),
    exp(TODAY, 999),
    { amount: 500, txn_kind: "income", created_at: at("2026-11-21") },
    { amount: 300, txn_kind: "transfer", created_at: at("2026-11-21") },
    exp("2026-11-21", 2000, { linked_obligation_id: "00000000-0000-0000-0000-000000000001" }),
    exp("2026-10-20", 77),
  ];
  assertEquals(dailySpendSeries(rows, TODAY, CAIRO), { series: [10], spendDays: 1 });
});

Deno.test("days are the account's civil days, not UTC", () => {
  // 22:30Z on the 20th is already the 21st in Cairo (UTC+2).
  const { series } = dailySpendSeries([{ amount: 40, txn_kind: "expense", created_at: "2026-11-20T22:30:00Z" }], TODAY, CAIRO);
  assertEquals(series, [40]);
  assertEquals(dailySpendSeries([{ amount: 40, txn_kind: "expense", created_at: "2026-11-20T22:30:00Z" }], TODAY, "UTC").series, [40, 0]);
});

Deno.test("under 14 spending days: approximate, no probability — even with a long quiet span", () => {
  const rows = [exp("2026-10-26", 100), ...daily(12, 20)]; // 13 spending days spread over 27 calendar days
  assertEquals(paydayOdds(1000, 10, rows, TODAY, CAIRO), { approximate: true, reach_probability: null, spend_days: 13 });
});

Deno.test("14 spending days: a real probability, high when the money covers the run rate, low when it does not", () => {
  const rows = daily(14, 50); // 50 a day
  assertEquals(paydayOdds(1000, 10, rows, TODAY, CAIRO), { approximate: false, reach_probability: 1, spend_days: 14 });
  assertEquals(paydayOdds(400, 10, rows, TODAY, CAIRO), { approximate: false, reach_probability: 0, spend_days: 14 });
});

Deno.test("nothing left (zero or negative available) is 0, never a path of quiet days that 'makes it'", () => {
  const rows = daily(14, 50);
  // Every other day: 14 spending days with quiet (zero) days between them, so a one-day path can draw a 0.
  const gappy = Array.from({ length: 14 }, (_, i) => exp(new Date(Date.UTC(2026, 10, 21 - 2 * i)).toISOString().slice(0, 10), 50));
  assertEquals(paydayOdds(0, 1, gappy, TODAY, CAIRO)?.reach_probability, 0);
  assertEquals(paydayOdds(-300, 5, rows, TODAY, CAIRO)?.reach_probability, 0);
});

Deno.test("no ceiling set (available null) gives nothing to judge", () => {
  assertEquals(paydayOdds(null, 10, daily(20, 50), TODAY, CAIRO), null);
});

Deno.test("legacy rows without txn_kind fall back to is_expense", () => {
  assertEquals(dailySpendSeries([{ amount: 15, is_expense: true, created_at: at("2026-11-21") }], TODAY, CAIRO).series, [15]);
});
