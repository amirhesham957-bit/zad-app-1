// household.ts — «البيت» كوحدة واحدة: صفوف العميل + صفوف عيلته.
//
// قرار المالك (٢٠٢٦-١٠-١١): العقل يتعامل مع البيت كوحدة استهلاك واحدة. المخزن مشترك من زمان،
// وقايمة التسوق بقت مشتركة (20261011140000) — الاتنين بـfamily_id اللي التريجر بيحطه من
// عضوية صاحب الصف. العقل كان بيقرا الاتنين بـuser_id بس، فلو الأم ضافت لبن كان ممكن يقول
// للأب «اللبن خلص».
//
// الفلتر ده للقراية والمطابقة (PostgREST `.or(...)`) على أي جدول فيه user_id وfamily_id. الكتابة
// الجديدة بتفضل باسم العميل نفسه (user_id)، والتريجر بيحط family_id.

import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";

/** فلتر PostgREST لصفوف البيت: بتاعة العميل، أو بتاعة عيلته لو في عيلة. */
export function householdFilter(userId: string, familyId: string | null): string {
  return familyId ? `user_id.eq.${userId},family_id.eq.${familyId}` : `user_id.eq.${userId}`;
}

/** عيلة العميل (عضوية واحدة)، أو null. خطأ القراية = null: العميل بيشوف بتاعه بس، مش لا شيء. */
export async function householdFamilyId(sb: SupabaseClient, userId: string): Promise<string | null> {
  const { data, error } = await sb.from("family_members").select("family_id")
    .eq("user_id", userId).limit(1).maybeSingle();
  if (error) {
    console.error("[household] family lookup failed:", error.message);
    return null;
  }
  return (data as { family_id: string | null } | null)?.family_id ?? null;
}
