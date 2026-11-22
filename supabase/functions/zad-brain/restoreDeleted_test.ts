// ZAD_OR_PLAN م١.٦: «رجّع اللي اتمسح» — حاجة العميل بس، مرة واحدة، جوه الـ٣٠ يوم.
import { assert, assertEquals } from "jsr:@std/assert@1";
import { RESTORE_INTENT, restorableRow, trashLabel, trashList, type TrashRow } from "./restoreDeleted.ts";
import { intentToolHints } from "./specialists.ts";
import { MUTATING_TOOLS } from "./validators.ts";

const ME = "11111111-1111-1111-1111-111111111111";
const NOW = Date.parse("2026-11-21T12:00:00Z");
const row = (o: Partial<TrashRow> = {}): TrashRow => ({
  id: 7, table_name: "zad_subscriptions", row_id: "r1", user_id: ME,
  row_data: { name: "نتفلكس", amount: 200 }, deleted_at: "2026-11-20T10:00:00Z", restored_at: null, ...o,
});

Deno.test("only the customer's own, unrestored, recent row is restorable", () => {
  assertEquals(restorableRow(row(), ME, NOW), null);
  // العقل شغال بـservice_role: صف حد تاني لازم يترفض هنا، الدالة مش هتفحصه.
  assert(restorableRow(row({ user_id: "22222222-2222-2222-2222-222222222222" }), ME, NOW));
  assert(restorableRow(null, ME, NOW));
  assert(restorableRow(row({ restored_at: "2026-11-20T11:00:00Z" }), ME, NOW));
  assert(restorableRow(row({ deleted_at: "2026-10-01T10:00:00Z" }), ME, NOW));
  assert(restorableRow(row({ table_name: "zad_users" }), ME, NOW));
});

Deno.test("the list names each thing in words, with the id the model needs", () => {
  assertEquals(trashLabel(row()), "اشتراك «نتفلكس» 200");
  assertEquals(trashLabel(row({ table_name: "zad_memory", row_data: { note: "بيحب القهوة" } })), "ملاحظة من الذاكرة «بيحب القهوة»");
  const list = trashList([row()]);
  assert(list.includes("trash_id=7"));
  assert(list.includes("2026-11-20"));
  assert(trashList([]).startsWith("status=empty"));
});

Deno.test("«رجّع اللي اتمسح» routes the tool, and the tool is a write", () => {
  for (const m of ["رجّعلي اللي اتمسح", "استرجع الاشتراك اللي مسحته", "الميعاد اتمسح بالغلط", "رجعه، انا مسحته غلط"]) {
    assert(intentToolHints(m).includes("restore_deleted"), m);
  }
  for (const m of ["رجعت من الشغل", "امسح آخر مصروف", "سجل 50 قهوة"]) {
    assertEquals(intentToolHints(m).includes("restore_deleted"), false, m);
  }
  assert(MUTATING_TOOLS.includes("restore_deleted"));
  assert(RESTORE_INTENT instanceof RegExp);
});
