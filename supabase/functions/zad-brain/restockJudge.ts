// restockJudge.ts — بيجيب أيام شرا البيت مرة واحدة ويرجّع «الصنف ده ناقص فعلاً؟» (`_shared/restockCycle.ts`).
// الحلم الليلي (قايمة الشرا) وتنبيه «أنت جنب ماركت» بيسألوا نفس السؤال، فبقى ليهم جواب واحد.

import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { PURCHASE_SOURCES, purchaseDaysByItem, restockKey, type RestockVerdict, restockVerdict } from "../_shared/restockCycle.ts";

export interface JudgedRow {
  item_name: string | null;
  quantity: number | string | null;
  low_stock_threshold?: number | string | null;
  category?: string | null;
  restock_mode?: string | null;
  restock_cycle_days?: number | null;
  created_at?: string | null;
}

/** أعضاء البيت (العميل + عيلته) — المشاهدات متسجلة باسم اللي سجّلها. */
export async function householdUserIds(sb: SupabaseClient, userId: string, familyId: string | null): Promise<string[]> {
  if (!familyId) return [userId];
  const { data } = await sb.from("family_members").select("user_id").eq("family_id", familyId);
  const ids = ((data ?? []) as Array<{ user_id: string | null }>).map((r) => r.user_id).filter((x): x is string => !!x);
  return [...new Set([userId, ...ids])];
}

/**
 * الحكم لكل صف مخزن. أيام الشرا = مشاهدات الشرا (فاتورة/شات/شرا) آخر ٢٤٠ يوم + يوم ما الصف اتضاف. فشل القراية =
 * من غير تاريخ = الحد القديم (restockVerdict بيرجعله لوحده).
 */
export async function loadRestockJudge(
  sb: SupabaseClient,
  userId: string,
  familyId: string | null,
  now = Date.now(),
): Promise<(row: JudgedRow) => boolean> {
  const verdict = await loadRestockVerdicts(sb, userId, familyId, now);
  return (row) => verdict(row).due;
}

/** الحكم كامل (الدورة، الأيام من آخر شرا، السبب) — لـ«هيخلص قريب» في لقطة العقل. */
export async function loadRestockVerdicts(
  sb: SupabaseClient,
  userId: string,
  familyId: string | null,
  now = Date.now(),
): Promise<(row: JudgedRow) => RestockVerdict> {
  let days = new Map<string, string[]>();
  try {
    const users = await householdUserIds(sb, userId, familyId);
    const { data, error } = await sb.from("zad_inventory_observations").select("item_name,observed_at")
      .in("user_id", users).in("source", [...PURCHASE_SOURCES])
      .gte("observed_at", new Date(now - 240 * 86_400_000).toISOString()).limit(2000);
    if (error) console.error("[restock] observations read failed:", error.message);
    days = purchaseDaysByItem((data ?? []) as Array<{ item_name: string | null; observed_at: string | null }>);
  } catch (e) {
    console.error("[restock] observations read threw:", (e as Error)?.message ?? e);
  }
  return (row) => {
    const name = String(row.item_name ?? "");
    const bought = [...(days.get(restockKey(name)) ?? []), ...(row.created_at ? [row.created_at] : [])];
    return restockVerdict({
      name, category: row.category, quantity: row.quantity, threshold: row.low_stock_threshold,
      restockMode: row.restock_mode, purchaseDays: bought, cycleOverride: row.restock_cycle_days,
    }, now);
  };
}
