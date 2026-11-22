// م٦.٢: محوّل رفيع بين دالة القراية zad_restock_availability و restockAvailability.ts (الحساب الصافي).
// قراية بس (service_role). خصوصية: الدالة مابترجّعش مين اشترى أو أبلغ ولا مصدر الملاحظة، والمخرجات احتمال ومسافة تقريبية.
import { type Candidate, type Observation, rankNearby, type Ranked } from "./restockAvailability.ts";

export interface AvailabilityRow {
  store_key: string;
  in_stock: boolean;
  age_days: number | string;
  area_lat: number | string | null;
  area_lng: number | string | null;
}

export interface Rpc {
  rpc(
    fn: string,
    args: Record<string, unknown>,
  ): PromiseLike<{ data: unknown; error: { message: string } | null }>;
}

export interface Home {
  lat: number;
  lng: number;
}

/** مسافة بالكم (haversine). */
export function distanceKm(a: Home, b: Home): number {
  const r = Math.PI / 180;
  const dLat = (b.lat - a.lat) * r;
  const dLng = (b.lng - a.lng) * r;
  const h = Math.sin(dLat / 2) ** 2 +
    Math.cos(a.lat * r) * Math.cos(b.lat * r) * Math.sin(dLng / 2) ** 2;
  return 6371 * 2 * Math.asin(Math.min(1, Math.sqrt(h)));
}

/** موقع البيت يتقرّب لرقمين عشريين (≈ ١ كم) قبل أي حساب، فمفيش موقع دقيق بيعدي هنا. */
export function approxHome(h: Home): Home {
  return { lat: Math.round(h.lat * 100) / 100, lng: Math.round(h.lng * 100) / 100 };
}

const UNKNOWN_DISTANCE_KM = 1e6;

/** صفوف الدالة -> مرشحين لكل محل. محل من غير موقع بياخد مسافة «مجهولة» فبيترتب آخر عند التساوي. */
export function toCandidates(rows: AvailabilityRow[], item: string, home?: Home): Candidate[] {
  const byStore = new Map<string, { obs: Observation[]; lat: number | null; lng: number | null }>();
  for (const r of rows) {
    const age = Number(r.age_days);
    if (!Number.isFinite(age)) continue;
    const g = byStore.get(r.store_key) ?? { obs: [], lat: null, lng: null };
    g.obs.push({ inStock: r.in_stock === true, ageDays: age });
    const lat = r.area_lat == null ? NaN : Number(r.area_lat);
    const lng = r.area_lng == null ? NaN : Number(r.area_lng);
    if (Number.isFinite(lat) && Number.isFinite(lng)) {
      g.lat = lat;
      g.lng = lng;
    }
    byStore.set(r.store_key, g);
  }
  const h = home ? approxHome(home) : undefined;
  return [...byStore].map(([storeId, g]) => ({
    storeId,
    item,
    obs: g.obs,
    distanceKm: h && g.lat != null && g.lng != null
      ? distanceKm(h, { lat: g.lat, lng: g.lng })
      : UNKNOWN_DISTANCE_KM,
  }));
}

/** يقرا الملاحظات ويرتّب المحلات بالاحتمال. فشل القراية يرمي خطأ (مفيش «٠.٥» بيتخمّن). */
export async function rankStoresForItem(
  sb: Rpc,
  args: { country: string; item: string; home?: Home; maxAgeDays?: number; limit?: number },
): Promise<Ranked[]> {
  const { data, error } = await sb.rpc("zad_restock_availability", {
    p_country: args.country,
    p_item_key: args.item,
    p_max_age_days: args.maxAgeDays ?? 90,
  });
  if (error) throw new Error(`zad_restock_availability: ${error.message}`);
  const rows = Array.isArray(data) ? (data as AvailabilityRow[]) : [];
  return rankNearby(toCandidates(rows, args.item, args.home)).slice(0, args.limit ?? 5);
}

export interface ObserveArgs {
  country: string;
  store: string;
  item: string;
  inStock: boolean;
  source: "receipt" | "flyer" | "partner";
  area?: Home;
  observedAt?: Date;
}

/** كتابة ملاحظة توافر (مجهولة: مفيش صاحب). بترجّع false لو اتجاهلت (مكررة في ساعة، أو أقدم من ٩٠ يوم). الفشل بيرمي خطأ. */
export async function observeRestock(sb: Rpc, a: ObserveArgs): Promise<boolean> {
  const { data, error } = await sb.rpc("zad_restock_observe", {
    p_country: a.country,
    p_store_key: a.store,
    p_item_key: a.item,
    p_in_stock: a.inStock,
    p_source_kind: a.source,
    p_lat: a.area?.lat ?? null,
    p_lng: a.area?.lng ?? null,
    p_observed_at: a.observedAt?.toISOString() ?? null,
  });
  if (error) throw new Error(`zad_restock_observe: ${error.message}`);
  return data === true;
}
