// الباب الوحيد (ZAD_OR_PLAN م٢.٥): أدوات العقل مابتكتبش في المخزن ولا القايمة ولا الصيدلية بإيدها — بتبعت نية لـ
// zad_commit_intent (commitIntent.ts). والمعاملات كمان من ٢٢/١١. التست بيقرا كل ملفات zad-brain وبيفشل لو سلسلة `.from("<الجدول>")` فيها
// insert/upsert/update/delete — نفس قارئ one_writer_test.
//
// الاستثناء الوحيد المسمّى: «الحلم» بالليل بيضيف النواقص للقايمة (كرون، مش أداة موديل) — مكانه بعد م٢.٥.
import { assertEquals } from "jsr:@std/assert@1";
import { writesIn } from "../_schema/one_writer_test.ts";

const THROUGH_THE_DOOR = ["zad_inventory", "zad_shopping_list", "zad_pharmacy_items", "zad_transactions", "zad_category_budgets",
  "zad_subscriptions", "zad_debts", "zad_obligations", "zad_maintenance_items", "zad_documents", "zad_appointments"];
const ALLOWED: Record<string, Record<string, number>> = {
  "index.ts": {
    zad_shopping_list: 1, // الحلم: lowStockToAdd ⇐ zad_shopping_list.insert
    // فحص القبول الحي (acceptance_probe): بيمسح مواعيد حساب الاختبار قبل وبعد اللفات. مش أداة موديل ولا حساب عميل.
    zad_appointments: 2,
  },
};

Deno.test("the brain writes the pantry, the list, the pharmacy and the transactions only through zad_commit_intent", async () => {
  const found: Record<string, Record<string, number>> = {};
  for await (const e of Deno.readDir(new URL("./", import.meta.url))) {
    if (!e.isFile || !e.name.endsWith(".ts") || e.name.endsWith("_test.ts")) continue;
    const text = await Deno.readTextFile(new URL(`./${e.name}`, import.meta.url));
    for (const table of THROUGH_THE_DOOR) {
      const n = writesIn(text, table);
      if (n > 0) (found[e.name] ??= {})[table] = n;
    }
  }
  assertEquals(found, ALLOWED);
});
