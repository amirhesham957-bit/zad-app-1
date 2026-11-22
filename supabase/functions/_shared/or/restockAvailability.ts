// م٦.٢: احتمال توافر صنف في محل، من توزيع Beta(α,β) بيقل وزن الملاحظات القديمة فيه.
// نقي: من غير DB ولا شبكة. الملاحظة = {موجود/مش موجود، عمرها بالأيام}.
// خصوصية: المخرجات احتمال بس، ومفيهاش أي معلومة عن مين اشترى أو أبلغ.

export interface Observation {
  inStock: boolean;
  ageDays: number;
}

export const DEFAULT_HALF_LIFE_DAYS = 7;

export function weight(ageDays: number, halfLife = DEFAULT_HALF_LIFE_DAYS): number {
  if (!(halfLife > 0)) throw new Error("halfLife must be > 0");
  const a = Math.max(0, Number.isFinite(ageDays) ? ageDays : 0);
  return Math.exp(-Math.LN2 * a / halfLife);
}

/** متوسط Beta(1+Σw_in, 1+Σw_out). من غير ملاحظات = ٠.٥. */
export function prob(obs: Observation[], halfLife = DEFAULT_HALF_LIFE_DAYS): number {
  let alpha = 1;
  let beta = 1;
  for (const o of obs) {
    const w = weight(o.ageDays, halfLife);
    if (o.inStock) alpha += w;
    else beta += w;
  }
  return alpha / (alpha + beta);
}

export interface Candidate {
  storeId: string;
  item: string;
  obs: Observation[];
  distanceKm: number;
}

export interface Ranked {
  storeId: string;
  item: string;
  prob: number;
  distanceKm: number;
}

/** ترتيب بالاحتمال تنازلي، وعند التساوي الأقرب. */
export function rankNearby(candidates: Candidate[], halfLife = DEFAULT_HALF_LIFE_DAYS): Ranked[] {
  return candidates
    .map((c) => ({
      storeId: c.storeId,
      item: c.item,
      prob: prob(c.obs, halfLife),
      distanceKm: c.distanceKm,
    }))
    .sort((a, b) =>
      b.prob - a.prob || a.distanceKm - b.distanceKm ||
      a.storeId.localeCompare(b.storeId)
    );
}
