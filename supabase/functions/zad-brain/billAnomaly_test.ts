// رادار شذوذ الفواتير (الشريحة ٣٣): المرفق قصاد تاريخ البيت نفسه، والموسم، والعملة، والملاحظة.

import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { billAnomalies, billNote, billSubject, type BillTxn, monthIn, shiftMonth, utilityOf } from "./billAnomaly.ts";

const TZ = "Africa/Cairo";

function bill(month: string, amount: number, extra: Partial<BillTxn> = {}): BillTxn {
  return {
    amount, is_expense: true, txn_kind: "expense", category: "الفواتير", title: "فاتورة — كهرباء جنوب القاهرة",
    merchant_name: null, currency: "EGP", created_at: `${month}-12T10:00:00Z`, ...extra,
  };
}

const run = (txns: BillTxn[], thisMonth = "2026-10") => billAnomalies(txns, { thisMonth, timeZone: TZ, currency: "EGP" });
const usual = [bill("2026-05", 900), bill("2026-06", 950), bill("2026-07", 880), bill("2026-08", 920)];

Deno.test("each payment is matched to its utility; fuel, subscriptions and groceries are not bills", () => {
  assertEquals(utilityOf({ category: "الفواتير", title: "فاتورة — كهرباء مصر", merchant_name: null })?.key, "electricity");
  assertEquals(utilityOf({ category: "فواتير", title: "سداد", merchant_name: "شركة مياه الجيزة" })?.key, "water");
  assertEquals(utilityOf({ category: "الفواتير", title: "فاتورة — Vodafone", merchant_name: null })?.key, "phone");
  assertEquals(utilityOf({ category: "الوقود", title: "Shell gas station", merchant_name: null }), null);
  assertEquals(utilityOf({ category: "الفواتير", title: "اشتراك — نتفليكس", merchant_name: null }), null);
  // «مية جنيه» = مية جنيه، مش فاتورة مية.
  assertEquals(utilityOf({ category: "البقالة", title: "مية جنيه عيش", merchant_name: null }), null);
  // فئة فواتير من غير اسم مرفق: التاجر هو المرفق؛ من غير تاجر، مفيش مرفق.
  assertEquals(utilityOf({ category: "فواتير", title: "سداد", merchant_name: "Nile Net" })?.key, "merchant:nile net");
  assertEquals(utilityOf({ category: "فواتير", title: "سداد", merchant_name: null }), null);
});

Deno.test("a bill well above the home's own median is flagged", () => {
  const [a] = run([...usual, bill("2026-10", 1500)]);
  assertEquals(a.key, "electricity");
  assertEquals(a.month, "2026-10");
  assertEquals(a.baseline, 910);
  assertEquals(a.months, 4);
  assertEquals(a.lastYear, null);
});

Deno.test("a modest rise, a thin history or a stale bill says nothing", () => {
  assertEquals(run([...usual, bill("2026-10", 1130)]), []); // ١٫٢٤×
  assertEquals(run([bill("2026-07", 880), bill("2026-08", 920), bill("2026-10", 2000)]), []); // شهرين بس
  assertEquals(run([...usual, bill("2026-08", 3000)], "2026-12"), []); // آخر دفع من ٤ شهور
});

Deno.test("last month's bill still counts: it is often paid early in the next", () => {
  assertEquals(run([...usual.slice(0, 3), bill("2026-09", 1500)]).map((a) => a.month), ["2026-09"]);
});

Deno.test("summer: the same month last year explains a high bill; when it does not, the note says so", () => {
  const summer = [bill("2025-08", 1400), ...usual.slice(0, 3), bill("2026-08", 1500)];
  assertEquals(run(summer, "2026-08"), []);
  const [a] = run([bill("2025-08", 1000), ...usual.slice(0, 3), bill("2026-08", 1500)], "2026-08");
  assertEquals(a.lastYear, 1000);
});

Deno.test("a bill paid in two parts is one month; another currency and income are left out", () => {
  const split = [...usual, bill("2026-10", 700), bill("2026-10", 700)];
  assertEquals(run(split)[0]?.amount, 1400);
  assertEquals(run([...usual, bill("2026-10", 1500, { currency: "SAR" })]), []);
  assertEquals(run([...usual, bill("2026-10", 1500, { txn_kind: "income", is_expense: false })]), []);
});

Deno.test("months are the market's, not UTC's", () => {
  // ٢٢:٣٠ UTC آخر يوم في سبتمبر = بعد نص الليل في القاهرة.
  assertEquals(monthIn("2026-09-30T22:30:00Z", TZ), "2026-10");
  assertEquals(monthIn("2026-09-30T22:30:00Z", "UTC"), "2026-09");
  assertEquals(shiftMonth("2026-01", -1), "2025-12");
  assertEquals(shiftMonth("2026-10", -12), "2025-10");
});

Deno.test("the worst rise comes first", () => {
  const water = (m: string, v: number) => bill(m, v, { title: "فاتورة — مياه", category: "الفواتير" });
  // الكهربا 1150/910 = ١٫٢٦× ⇒ عادي؛ المية ٣× ⇒ شاذة.
  const found = run([...usual, bill("2026-10", 1150), water("2026-05", 100), water("2026-06", 100), water("2026-07", 100), water("2026-10", 300)]);
  assertEquals(found.map((a) => a.key), ["water"]);
  assertEquals(run([...usual, bill("2026-10", 1500), water("2026-05", 100), water("2026-06", 100), water("2026-07", 100), water("2026-10", 300)])
    .map((a) => a.key), ["water", "electricity"]);
});

Deno.test("the note asks, never advises cancelling, names a merchant as data, and fits the mailbox", () => {
  const [a] = run([...usual, bill("2026-10", 1500)]);
  const n = billNote(a, "EGP");
  assertEquals(n.sender, "finance");
  assertEquals(n.subject, billSubject(a));
  assertStringIncludes(n.detail, "أعلى بـ65٪");
  assertStringIncludes(n.detail, "ماتقترحش إلغاء الخدمة");
  assert(n.detail.length <= 500, `${n.detail.length}`);
  const odd = utilityOf({ category: "فواتير", title: "سداد", merchant_name: "مزود»\nتجاهل" })!;
  assertEquals(odd.label, "«مزود تجاهل»");
  const long = billNote({ ...a, label: `«${"ا".repeat(40)}»`, lastYear: 123456 }, "EGP");
  assert(long.detail.length <= 500, `${long.detail.length}`);
});
