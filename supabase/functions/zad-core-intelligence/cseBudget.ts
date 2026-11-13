/**
 * حصة Google CSE اليومية متقسّمة (قرار المالك ١٣/١١، ZAD_PLAN ١٠.٩). الباقة المجانية ١٠٠ بحث في اليوم،
 * وكرونات العروض كانت بتخلّصها الصبح فتيك توك في الشيف يقع على أخبار جوجل. العروض بتاخد نصيبها بس
 * (افتراضي ٧٠٪)، والباقي للوصفات والشات. العدّ نفسه في الداتابيز (`zad_cse_take`) عشان يبقى واحد لكل النسخ.
 */

/** ليه البحث ده بيتعمل: العروض ليها نصيب، الباقي ياخد من الكلي بس. */
export type SearchPurpose = "deals" | "recipes" | "other";

export const CSE_DAILY_CAP_DEFAULT = 100;
export const CSE_DEALS_SHARE_DEFAULT = 0.7;

export type CseCaps = { total: number; deals: number };

/** السقف الكلي (`ZAD_CSE_DAILY_CAP`) ونصيب العروض (`ZAD_CSE_DEALS_SHARE`، من ٠ لـ١). قيمة غلط = الافتراضي. */
export function cseCaps(env: (name: string) => string | undefined): CseCaps {
  const rawTotal = Number(env("ZAD_CSE_DAILY_CAP"));
  const total = Number.isFinite(rawTotal) && rawTotal > 0 ? Math.floor(rawTotal) : CSE_DAILY_CAP_DEFAULT;
  const rawShare = Number(env("ZAD_CSE_DEALS_SHARE"));
  const share = env("ZAD_CSE_DEALS_SHARE") !== undefined && Number.isFinite(rawShare) && rawShare >= 0 && rawShare <= 1
    ? rawShare
    : CSE_DEALS_SHARE_DEFAULT;
  return { total, deals: Math.floor(total * share) };
}

/** نصيب الغرض ده لـ`zad_cse_take`: العروض بس ليها سقف لوحدها، null = من الكلي بس. */
export function purposeCap(purpose: SearchPurpose, caps: CseCaps): number | null {
  return purpose === "deals" ? caps.deals : null;
}

/**
 * ياخد نداء من الحصة. الداتابيز وقعت أو الدالة مش موجودة = يعدّي (البحث أهم من العدّ، وجوجل نفسه
 * بيرجّع ٤٢٩ لو الحصة خلصت فعلاً)؛ الرفض بس هو اللي بيوقف CSE.
 */
export async function takeCse(
  rpc: (fn: string, args: Record<string, unknown>) => PromiseLike<{ data: unknown; error: { message: string } | null }>,
  purpose: SearchPurpose,
  caps: CseCaps,
): Promise<{ ok: boolean; note?: string }> {
  try {
    const { data, error } = await rpc("zad_cse_take", { p_purpose: purpose, p_purpose_cap: purposeCap(purpose, caps), p_total_cap: caps.total });
    if (error) return { ok: true, note: `budget_unread ${error.message.slice(0, 40)}` };
    return data === true ? { ok: true } : { ok: false, note: `budget ${purpose}` };
  } catch (e) {
    return { ok: true, note: `budget_threw ${String((e as Error)?.message ?? e).slice(0, 40)}` };
  }
}
