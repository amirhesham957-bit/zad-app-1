import { assertEquals } from "jsr:@std/assert@1";
import { tripReport, type TripSpend } from "./tripReport.ts";

const spends: TripSpend[] = [
  { category: "أكل", amount: 100 },
  { category: "مواصلات", amount: 50 },
  { category: "أكل", amount: 25.5 },
  { category: "سكن", amount: 200 },
  { category: "هدايا", amount: 10 },
];

Deno.test("بيجمّع المصاريف حسب الفئة والإجمالي صح", () => {
  const r = tripReport(spends, 10);
  assertEquals(r.total, 385.5);
  assertEquals(r.byCategory.map((c) => [c.category, c.amount]), [
    ["سكن", 200],
    ["أكل", 125.5],
    ["مواصلات", 50],
    ["هدايا", 10],
  ]);
});

Deno.test("التساوي في المبلغ بيترتّب بالاسم تصاعدي", () => {
  const r = tripReport(
    [
      { category: "ج", amount: 20 },
      { category: "أ", amount: 20 },
      { category: "ب", amount: 20 },
    ],
    10,
  );
  assertEquals(r.byCategory.map((c) => c.category), ["أ", "ب", "ج"]);
});

Deno.test("topN بيقص الناتج لكن الإجمالي بيفضل على كل الفئات", () => {
  const r = tripReport(spends, 2);
  assertEquals(r.total, 385.5);
  assertEquals(r.byCategory.map((c) => c.category), ["سكن", "أكل"]);
  // النسبة من الإجمالي الكامل: 200 / 385.5 = 0.519، و125.5 / 385.5 = 0.326
  assertEquals(r.byCategory[0].share, 0.519);
  assertEquals(r.byCategory[1].share, 0.326);
});

Deno.test("مصاريف فاضية: إجمالي صفر والنسب صفر", () => {
  assertEquals(tripReport([]), { total: 0, byCategory: [] });
  const r = tripReport([{ category: "أكل", amount: 0 }]);
  assertEquals(r, { total: 0, byCategory: [{ category: "أكل", amount: 0, share: 0 }] });
});

Deno.test("المبالغ السالبة بتتجاهل", () => {
  const r = tripReport([
    { category: "أكل", amount: 40 },
    { category: "أكل", amount: -15 },
    { category: "استرداد", amount: -100 },
  ]);
  assertEquals(r.total, 40);
  assertEquals(r.byCategory, [{ category: "أكل", amount: 40, share: 1 }]);
});
