// أنهي صف في المخزون تقصده أداة زي update_inventory_qty / delete_inventory_item.
//
// الكود القديم كان بيسأل بـ.eq(item_name).maybeSingle() على family_id لو العميل في عيلة،
// وإلا user_id. ده كان بيفشل في حالتين، والاتنين بيوصلوا للعميل «مرفوض: الصنف مش موجود»
// (زرار «خلص / لسه موجود» في تليجرام، ٢٠٢٦-٠٩-٢٩: «Sorry, I couldn't save your answer»):
// - اسم ليه أكتر من صف (فاتورة وإضافة يدوي، أو كل عضو في العيلة ضاف «لبن») = maybeSingle
//   بيرجّع خطأ و data=null — نفس الفخ اللي في lowStock.ts.
// - صف العميل نفسه اللي family_id بتاعه فاضي (اتضاف قبل ما يدخل العيلة) مابيتلاقاش لما
//   المطابقة بالعيلة بس.
// الاختيار هنا نقي: صف العميل نفسه الأول (الأحدث)، وبعده صف العيلة (الأحدث).

export interface InventoryCandidate {
  id: string;
  user_id?: string | null;
  family_id?: string | null;
  created_at?: string | null;
}

export function pickInventoryRow<T extends InventoryCandidate>(
  rows: T[] | null | undefined,
  userId: string,
  familyId: string | null,
): T | null {
  const newestFirst = [...(rows ?? [])].sort((a, b) =>
    String(b.created_at ?? "").localeCompare(String(a.created_at ?? ""))
  );
  return newestFirst.find((r) => r.user_id === userId) ??
    (familyId ? newestFirst.find((r) => r.family_id === familyId) : undefined) ??
    null;
}

/** فلتر PostgREST للصفوف اللي العميل يقدر يعدّلها: بتاعته، أو بتاعة عيلته. */
export function inventoryOwnerFilter(userId: string, familyId: string | null): string {
  return familyId ? `user_id.eq.${userId},family_id.eq.${familyId}` : `user_id.eq.${userId}`;
}
