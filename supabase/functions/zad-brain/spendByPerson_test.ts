import { assertEquals } from "jsr:@std/assert@1";
import { spendByPerson } from "./spendByPerson.ts";

const NOW = Date.parse("2026-10-27T12:00:00Z");
const day = (n: number) => new Date(NOW - n * 86_400_000).toISOString();
const exp = (amount: number, for_person: string | null, category: string | null, ago = 1) =>
  ({ amount, for_person, category, txn_kind: "expense", is_expense: true, created_at: day(ago) });

Deno.test("spendByPerson: كل شخص بمجموعه وأكبر فئتين، الأكبر الأول", () => {
  const out = spendByPerson([
    exp(500, "يوسف", "ملابس"),
    exp(120, "يوسف", "مدرسة"),
    exp(80, "يوسف", "مدرسة", 3),
    exp(60, "يوسف", "حلويات"),
    exp(300, "ماما", "صيدلية"),
    exp(999, null, "بقالة"),
  ], NOW);
  assertEquals(out, [
    { person: "يوسف", total: 760, count: 4, top_categories: ["ملابس", "مدرسة"] },
    { person: "ماما", total: 300, count: 1, top_categories: ["صيدلية"] },
  ]);
});

Deno.test("spendByPerson: الإيداع والتحويل والأقدم من ٣٠ يوم برّه", () => {
  assertEquals(spendByPerson([
    { ...exp(200, "ماما", "تحويل"), txn_kind: "transfer", is_expense: false },
    { ...exp(1000, "ماما", null), txn_kind: "income", is_expense: false },
    exp(400, "ماما", "صيدلية", 31),
    exp(0, "ماما", "صيدلية"),
  ], NOW), []);
  // من غير txn_kind (صف قديم) بيتقرا is_expense، والفئة الفاضية «أخرى».
  assertEquals(spendByPerson([{ ...exp(50, "جدو", null), txn_kind: null }], NOW),
    [{ person: "جدو", total: 50, count: 1, top_categories: ["أخرى"] }]);
});
