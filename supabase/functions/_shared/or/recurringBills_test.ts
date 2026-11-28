import { assertEquals } from "jsr:@std/assert@1";
import { detectRecurringBills, recurringQuestion, type BankTxn } from "./recurringBills.ts";
import { recurringObligationCandidate } from "../../zad-brain/recurringBillWiring.ts";

const NOW = new Date("2026-11-28T10:00:00Z");
const tx = (merchant: string, amount: number, date: string, id?: string): BankTxn =>
  ({ id: id ?? `${merchant}-${date}`, merchant_name: merchant, amount, created_at: `${date}T09:00:00Z`, txn_kind: "expense" });

Deno.test("monthly x3, same merchant, close amount -> candidate with evidence and question from row numbers", () => {
  const rows = [tx("عيادة د. سامي", 500, "2026-09-05"), tx("عيادة د. سامي", 510, "2026-10-05"), tx("عيادة د. سامي", 495, "2026-11-04")];
  const [c] = detectRecurringBills(rows, [], NOW);
  assertEquals(c.period, "monthly");
  assertEquals(c.count, 3);
  assertEquals(c.amount, 500);
  assertEquals(c.dueDay, 4);
  assertEquals(c.lastDate, "2026-11-04");
  assertEquals(c.evidence.length, 3);
  assertEquals(recurringQuestion(c).includes("500") && recurringQuestion(c).includes("2026-11-04"), true);
});

Deno.test("only 2 occurrences -> nothing", () => {
  assertEquals(detectRecurringBills([tx("a b", 100, "2026-10-05"), tx("a b", 100, "2026-11-05")], [], NOW), []);
});

Deno.test("amount outside tolerance or irregular gaps -> nothing", () => {
  assertEquals(detectRecurringBills([tx("مطعم س", 100, "2026-09-05"), tx("مطعم س", 100, "2026-10-05"), tx("مطعم س", 180, "2026-11-05")], [], NOW), []);
  assertEquals(detectRecurringBills([tx("مطعم س", 100, "2026-09-05"), tx("مطعم س", 100, "2026-10-01"), tx("مطعم س", 100, "2026-11-25")], [], NOW), []);
});

Deno.test("stopped long ago -> nothing; weekly detected as weekly; known obligation skipped", () => {
  assertEquals(detectRecurringBills([tx("ج م", 50, "2026-05-05"), tx("ج م", 50, "2026-06-05"), tx("ج م", 50, "2026-07-05")], [], NOW), []);
  const wk = ["2026-11-07", "2026-11-14", "2026-11-21"].map((d) => tx("دروس سباحة", 200, d));
  assertEquals(detectRecurringBills(wk, [], NOW)[0].period, "weekly");
  const mo = [tx("نادي", 300, "2026-09-10"), tx("نادي", 300, "2026-10-10"), tx("نادي", 300, "2026-11-10")];
  assertEquals(detectRecurringBills(mo, ["النادي"], NOW), []);
});

Deno.test("income and same-day duplicates ignored", () => {
  const inc = [tx("راتب", 5000, "2026-09-01"), tx("راتب", 5000, "2026-10-01"), tx("راتب", 5000, "2026-11-01")].map((x) => ({ ...x, txn_kind: "income" }));
  assertEquals(detectRecurringBills(inc, [], NOW), []);
  const dup = [tx("كافيه", 40, "2026-11-01", "1"), tx("كافيه", 40, "2026-11-01", "2"), tx("كافيه", 40, "2026-11-01", "3")];
  assertEquals(detectRecurringBills(dup, [], NOW), []);
});

// Precision/recall على مجموعة اصطناعية معلّمة بإيدي (مش حسابات حية): ٤ فعلاً ثابتة، ٦ ضجيج.
Deno.test("labelled synthetic set: precision and recall", () => {
  const positives = [
    ...["2026-09-03", "2026-10-03", "2026-11-03"].map((d) => tx("عيادة أسنان", 400, d)),
    ...["2026-09-12", "2026-10-12", "2026-11-12"].map((d, i) => tx("مدرسة خصوصي", [250, 255, 245][i], d)),
    ...["2026-11-06", "2026-11-13", "2026-11-20"].map((d) => tx("فيزيو", 300, d)),
    ...["2026-09-20", "2026-10-21", "2026-11-20"].map((d) => tx("حضانة", 1200, d)),
  ];
  const noise = [
    ...["2026-09-01", "2026-09-04", "2026-11-20"].map((d) => tx("سوبرماركت", 180, d)), // فترة مش ثابتة
    ...["2026-09-05", "2026-10-05", "2026-11-05"].map((d, i) => tx("مطعم", [90, 300, 40][i], d)), // مبلغ بيتغير
    ...["2026-08-05", "2026-09-05"].map((d) => tx("صيدلية", 70, d)), // مرتين بس
    tx("بنزينة", 200, "2026-11-10"), tx("بنزينة", 150, "2026-11-11"),
    ...["2026-03-05", "2026-04-05", "2026-05-05"].map((d) => tx("نادي قديم", 300, d)), // وقف
  ];
  const found = new Set(detectRecurringBills([...positives, ...noise], [], NOW).map((c) => c.merchant));
  const want = new Set(["عيادة أسنان", "مدرسة خصوصي", "فيزيو", "حضانة"]);
  const tp = [...found].filter((m) => want.has(m)).length;
  assertEquals(tp / found.size, 1); // precision
  assertEquals(tp / want.size, 1); // recall
});

Deno.test("wiring: closed flag = null; open = monthly only, shaped like obligation_detection", () => {
  const mo = [tx("عيادة", 500, "2026-09-05"), tx("عيادة", 500, "2026-10-05"), tx("عيادة", 500, "2026-11-05")];
  assertEquals(recurringObligationCandidate(mo, [], NOW, false), null);
  const c = recurringObligationCandidate(mo, [], NOW, true);
  assertEquals(c?.title, "عيادة");
  assertEquals(c?.amount, 500);
  assertEquals(c?.due_day, 5);
  assertEquals(c?.dedupe_key.startsWith("obligation_confirm_"), true);
  const wk = ["2026-11-07", "2026-11-14", "2026-11-21"].map((d) => tx("سباحة", 200, d));
  assertEquals(recurringObligationCandidate(wk, [], NOW, true), null);
});
