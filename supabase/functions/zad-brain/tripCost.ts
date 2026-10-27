// tripCost.ts — المشوار ولا التوصيل (ZAD_PLAN ٤.١٠).
//
// عرض في محل بعيد ممكن المشوار ياكل توفيره. هنا تكلفة المشوار بالعربية: المسافة رايح جاي (الخط المستقيم × ١٫٣
// لأن الطريق مش مستقيم) × ٨ لتر لكل ١٠٠ كم × سعر لتر البنزين في بلده من zad_fuel_prices. لو المشوار بياكل التوفير
// كله العرض مايتقالش، وإلا بيتقال التوفير الصافي. رسوم التوصيل لسه مالهاش مصدر (مفيش تطبيق توصيل شريك)، فالمقارنة
// بيها مستنية؛ ومش عارفين البيت عنده عربية ولا لأ، فالسطر بيقول «بالعربية».

/** الطريق الفعلي قصاد الخط المستقيم في المدن. */
export const ROAD_FACTOR = 1.3;
/** لتر لكل كيلو — عربية عادية في المدينة. */
export const LITRES_PER_KM = 0.08;
/** أبعد من كده مش مشوار بقالة؛ مانحسبش ومانقولش. */
export const MAX_ONE_WAY_KM = 30;
/** سعر بنزين أقدم من كده ممكن يكون اتغيّر. */
export const FUEL_MAX_AGE_DAYS = 45;

export interface Fuel {
  price: number;
  currency: string;
  found_at: string;
}

export interface Trip {
  /** رايح جاي بالطريق، كيلو بكسر واحد. */
  km: number;
  /** بنزين المشوار بعملة البلد. */
  cost: number;
}

/** المسافة بالخط المستقيم بالكيلو. */
export function haversineKm(a: { lat: number; lon: number }, b: { lat: number; lon: number }): number {
  const rad = (d: number) => (d * Math.PI) / 180;
  const dLat = rad(b.lat - a.lat);
  const dLon = rad(b.lon - a.lon);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.sin(dLon / 2) ** 2;
  return 2 * 6371 * Math.asin(Math.sqrt(h));
}

/** سعر البنزين لو حديث وبنفس عملة العرض، وإلا null. */
export function usableFuel(row: Partial<Fuel> | null | undefined, currency: string | null | undefined, nowMs: number): Fuel | null {
  const price = Number(row?.price);
  const at = Date.parse(String(row?.found_at ?? ""));
  if (!row || !(price > 0) || !Number.isFinite(at) || nowMs - at > FUEL_MAX_AGE_DAYS * 86_400_000) return null;
  if (currency && row.currency && row.currency.toUpperCase() !== currency.toUpperCase()) return null;
  return { price, currency: String(row.currency ?? ""), found_at: String(row.found_at) };
}

/** المشوار من [home] للمحل في [store]، أو null (مفيش إحداثيات، أو بعيد قوي، أو مفيش سعر بنزين). */
export function tripCost(
  home: { lat: number; lon: number } | null,
  store: { lat?: number | string | null; lng?: number | string | null } | null | undefined,
  fuel: Fuel | null,
): Trip | null {
  const lat = Number(store?.lat);
  const lon = Number(store?.lng);
  if (!home || !fuel || store?.lat == null || store?.lng == null || !Number.isFinite(lat) || !Number.isFinite(lon)) return null;
  const oneWay = haversineKm(home, { lat, lon });
  if (oneWay > MAX_ONE_WAY_KM) return null;
  const km = Math.round(oneWay * 2 * ROAD_FACTOR * 10) / 10;
  return { km, cost: Math.round(km * LITRES_PER_KM * fuel.price * 10) / 10 };
}

/** المشوار بياكل التوفير؟ من غير توفير معروف (سعر بس) مابنحكمش. */
export function tripEatsSaving(trip: Trip | null, saving: number | null | undefined): boolean {
  return !!trip && Number(saving) > 0 && trip.cost >= Number(saving);
}
