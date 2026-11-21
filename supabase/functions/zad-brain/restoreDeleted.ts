// restoreDeleted.ts — «رجّع اللي اتمسح» (ZAD_OR_PLAN م١.٦، ٢١/١١).
//
// السلة zad_trash بتاخد نسخة من أي صف بيتمسح من الـ١٢ جدول لمدة ٣٠ يوم (20261120200000). الأداة بتعرض للعميل
// اللي اتمسح من حاجته، ولما يختار بترجّعه بـzad_trash_restore. العقل شغال بـservice_role، والدالة دي مابتفحصش
// الملكية لما auth.uid() فاضي — فالفحص هنا (restorableRow) هو الحارس: صف السلة لازم يكون بتاع العميل نفسه.

export const TRASH_DAYS = 30;

export interface TrashRow {
  id: number;
  table_name: string;
  row_id: string;
  user_id: string;
  row_data: Record<string, unknown> | null;
  deleted_at: string;
  restored_at: string | null;
}

export const TRASH_TABLE_LABEL: Record<string, string> = {
  zad_transactions: "حركة فلوس",
  zad_inventory: "صنف من المخزن",
  zad_pharmacy_items: "دوا",
  zad_shopping_list: "صنف من القايمة",
  zad_subscriptions: "اشتراك",
  zad_debts: "دين",
  zad_obligations: "التزام",
  zad_maintenance_items: "صيانة",
  zad_documents: "مستند",
  zad_appointments: "ميعاد",
  zad_memory: "ملاحظة من الذاكرة",
  zad_category_budgets: "ميزانية فئة",
};

/** «رجّعلي اللي اتمسح»، «استرجع الاشتراك اللي مسحته»، «اتمسح بالغلط». النص متطبّع (من غير تشكيل، ة→ه). */
export const RESTORE_INTENT =
  /(^|\s)(رجع|رجعلي|رجعهولي|رجعهالي|رجعها|رجعه|استرجع|استرجعلي)(\s|$).{0,30}(اتمسح|مسحته|مسحتها|مسحتهم|اتشال|اتحذف|حذفته|حذفتها|المحذوف|اللي مسحته)|(اتمسح|اتحذف|مسحته|مسحتها)\s*(غلط|بالغلط|بالغلط)|سله المحذوفات/;

const NAME_KEYS = ["title", "name", "item_name", "note", "label", "merchant_name", "category"] as const;

/** «اشتراك «نتفلكس» ٢٠٠» — من صورة الصف قبل الحذف. */
export function trashLabel(row: Pick<TrashRow, "table_name" | "row_data">): string {
  const kind = TRASH_TABLE_LABEL[row.table_name] ?? "حاجة";
  const data = row.row_data ?? {};
  const name = NAME_KEYS.map((k) => data[k]).find((v) => typeof v === "string" && v.trim() !== "") as string | undefined;
  const amount = typeof data.amount === "number" || typeof data.amount === "string" ? String(data.amount) : "";
  return [kind, name ? `«${name.trim().slice(0, 60)}»` : "", amount].filter(Boolean).join(" ");
}

/** القايمة اللي الموديل بيختار منها — trash_id لكل سطر، والأحدث الأول. */
export function trashList(rows: readonly TrashRow[]): string {
  if (rows.length === 0) return `status=empty — مفيش حاجة اتمسحت من حاجتك في آخر ${TRASH_DAYS} يوم.`;
  const lines = rows.map((r) => `trash_id=${r.id} · ${trashLabel(r)} · اتمسح ${r.deleted_at.slice(0, 10)}`);
  return `اللي اتمسح من حاجتك في آخر ${TRASH_DAYS} يوم (اسأله أنهي واحدة، وبعدها نادي restore_deleted بالـtrash_id):\n${lines.join("\n")}`;
}

/** null = ينفع يترجع. غير كده سبب الرفض بالعربي. */
export function restorableRow(row: TrashRow | null, userId: string, nowMs: number): string | null {
  if (!row || row.user_id !== userId) return "الحاجة دي مش في سلة العميل — مارجعتش.";
  if (row.restored_at) return "الحاجة دي رجعت قبل كده.";
  if (nowMs - Date.parse(row.deleted_at) > TRASH_DAYS * 86_400_000) return `اتمسحت من أكتر من ${TRASH_DAYS} يوم، والسلة بتتفضى.`;
  if (!(row.table_name in TRASH_TABLE_LABEL)) return "النوع ده مابيترجعش من هنا.";
  return null;
}

/** ردود zad_trash_restore بالعربي. */
export function restoreError(code: string | undefined): string {
  switch (code) {
    case "row_exists": return "الحاجة دي موجودة دلوقتي (رجعت أو اتكتبت تاني).";
    case "already_restored": return "الحاجة دي رجعت قبل كده.";
    case "not_found": return "الحاجة دي مش في السلة.";
    default: return "مقدرتش أرجّعها دلوقتي.";
  }
}
