// كشف الحساب بالصورة/PDF: الموديل بينقل، والرصيد بيراجع الأرقام — صف مش متطابق مايبانش متطابق.
import { assertEquals } from "jsr:@std/assert@1";
import { MAX_STATEMENT_ROWS, money, normalizeStatement, statementDate, statementMimeOk } from "./statementScan.ts";

const NOW = new Date("2026-10-19T12:00:00Z");

Deno.test("money: Arabic digits, separators, currency and brackets are read", () => {
  assertEquals(money("١٬٢٣٤٫٥٠"), 1234.5);
  assertEquals(money("1,250.00 EGP"), 1250);
  assertEquals(money("(300.00)"), -300);
  assertEquals(money("-45"), -45);
  assertEquals(money(12.3), 12.3);
  assertEquals(money("غير مقروء"), null);
  assertEquals(money(""), null);
  assertEquals(money(NaN), null);
});

Deno.test("statementDate: real dates within two years, never the future", () => {
  assertEquals(statementDate("2026-10-05", NOW), "2026-10-05");
  assertEquals(statementDate("2026-02-30", NOW), null, "rolls over — not a real day");
  assertEquals(statementDate("2026-11-30", NOW), null, "future");
  assertEquals(statementDate("2024-01-01", NOW), null, "older than two years");
  assertEquals(statementDate("05/10/2026", NOW), null, "the prompt asks for ISO; anything else is a misread");
});

Deno.test("mime: images and PDF only", () => {
  assertEquals(statementMimeOk("application/pdf"), true);
  assertEquals(statementMimeOk("image/jpeg"), true);
  assertEquals(statementMimeOk("text/csv"), false);
  assertEquals(statementMimeOk(undefined), false);
});

Deno.test("running balance oldest-first: every row checked against the one before", () => {
  const s = normalizeStatement({
    bank: "CIB", currency: "egp", opening_balance: "1,000.00", closing_balance: null,
    rows: [
      { date: "2026-10-01", description: "CARREFOUR MAADI", amount: "250.00", direction: "debit", balance: "750.00" },
      { date: "2026-10-02", description: "راتب أكتوبر", amount: 5000, direction: "credit", balance: 5750 },
      { date: "2026-10-03", description: "ATM", amount: 500, direction: "debit", balance: 5250 },
    ],
  }, NOW);
  assertEquals(s.currency, "EGP");
  assertEquals(s.rows.map((r) => r.balance_ok), [true, true, true]);
  assertEquals(s.check, "balanced");
  assertEquals(s.dropped, 0);
});

Deno.test("a misread amount breaks its own row, and the statement is a mismatch", () => {
  const s = normalizeStatement({
    rows: [
      { date: "2026-10-01", description: "A", amount: 100, direction: "debit", balance: 900 },
      { date: "2026-10-02", description: "B", amount: 80, direction: "debit", balance: 830 }, // read 80, paper says 70
      { date: "2026-10-03", description: "C", amount: 30, direction: "debit", balance: 800 },
    ],
  }, NOW);
  assertEquals(s.rows.map((r) => r.balance_ok), [null, false, true]);
  assertEquals(s.check, "mismatch");
});

Deno.test("newest-first statements are checked in reverse", () => {
  const s = normalizeStatement({
    rows: [
      { date: "2026-10-03", description: "C", amount: 30, direction: "debit", balance: 800 },
      { date: "2026-10-02", description: "B", amount: 70, direction: "debit", balance: 830 },
      { date: "2026-10-01", description: "A", amount: 100, direction: "credit", balance: 900 },
    ],
  }, NOW);
  assertEquals(s.rows.map((r) => r.balance_ok), [true, true, null]);
  assertEquals(s.check, "balanced");
});

Deno.test("opening + credits − debits must equal closing", () => {
  const rows = [
    { date: "2026-10-01", description: "A", amount: 200, direction: "debit", balance: null },
    { date: "2026-10-02", description: "B", amount: 50, direction: "credit", balance: null },
  ];
  assertEquals(normalizeStatement({ opening_balance: 1000, closing_balance: 850, rows }, NOW).check, "balanced");
  assertEquals(normalizeStatement({ opening_balance: 1000, closing_balance: 800, rows }, NOW).check, "mismatch");
  assertEquals(normalizeStatement({ rows }, NOW).check, "unknown", "no balances: nothing to check against");
});

Deno.test("rows with no date, no amount or no direction are dropped and counted — never balanced", () => {
  const s = normalizeStatement({
    opening_balance: 1000, closing_balance: 900,
    rows: [
      { date: "2026-10-01", description: "A", amount: 100, direction: "debit" },
      { date: "", description: "B", amount: 20, direction: "debit" },
      { date: "2026-10-02", description: "C", amount: "؟", direction: "debit" },
      { date: "2026-10-02", description: "D", amount: 0, direction: "debit" },
      { date: "2026-10-02", description: "E", amount: 10, direction: "sideways" },
    ],
  }, NOW);
  assertEquals(s.rows.length, 1);
  assertEquals(s.dropped, 4);
  assertEquals(s.check, "mismatch", "a dropped row means the balance cannot vouch for the rest");
});

Deno.test("a signed amount with no direction is money out; descriptions are cleaned", () => {
  const s = normalizeStatement({
    rows: [{ date: "2026-10-01", description: "  POS\n  TALABAT  ", amount: "-125.5", balance: null }],
  }, NOW);
  assertEquals(s.rows[0].direction, "debit");
  assertEquals(s.rows[0].amount, 125.5);
  assertEquals(s.rows[0].description, "POS TALABAT");
});

Deno.test("garbage in: empty statement, nothing thrown", () => {
  for (const raw of [null, "x", 3, {}, { rows: "no" }]) {
    const s = normalizeStatement(raw, NOW);
    assertEquals(s.rows, []);
    assertEquals(s.check, "unknown");
  }
});

Deno.test("rows past the cap are counted as dropped", () => {
  const rows = Array.from({ length: MAX_STATEMENT_ROWS + 5 }, (_, i) => ({
    date: "2026-10-01", description: `R${i}`, amount: 1, direction: "debit", balance: null,
  }));
  const s = normalizeStatement({ rows }, NOW);
  assertEquals(s.rows.length, MAX_STATEMENT_ROWS);
  assertEquals(s.dropped, 5);
});
