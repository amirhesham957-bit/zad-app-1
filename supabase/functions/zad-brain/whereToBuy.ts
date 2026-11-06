// whereToBuy.ts — «ألاقي الزيت فين بسعر كويس؟» (طلب المالك ٦/١١: العقل يبقى واعي مع العميل، مش أتمتة).
//
// كان فيه أدوات متفرقة: get_nearby_deals (أرخص بلاغات في *فئة*)، وzad_deals (عروض المحلات)، وfind_nearby_stores
// (الخريطة) — ومفيش أداة بتجاوب عن *صنف واحد*: مين بيبيعه، بكام، وإمتى اتشاف، وفيه عليه عرض؟
//
// خصوصية الجمهور (crowdFloor.ts، قرار المالك): السعر بيتقال بس لو الصنف اتبلّغ من ٣ بيوت مختلفة على الأقل في
// المدينة؛ أقل من كده بيتقال «اتشاف في محل X من كام يوم» من غير سعر ولا مين — نفس سابقة «اتشاف هنا».

import { CROWD_MIN_HOMES, homesIn, medianOf, withoutOutliers } from "./crowdFloor.ts";
import { offerMatchesNeed } from "./productIdentity.ts";
import { itemKey, sameCity, storeKey } from "./shared.ts";

export interface WhereReport {
  item_name: string | null;
  store_name: string | null;
  price: number | null;
  timestamp: string | null;
  user_id?: string | null;
  location?: string | null;
}

export interface WhereDeal {
  store: string;
  item_name: string;
  price: number | string;
  price_before?: number | string | null;
  valid_until?: string | null;
}

export interface WhereToBuy {
  item: string;
  /** وسيط السعر في المدينة — null لو أقل من ٣ بيوت. */
  typical: number | null;
  stores: Array<{ store: string; days: number; price: number | null }>;
  deals: Array<{ store: string; item: string; price: number; before: number | null; until: string | null }>;
}

const DAY_MS = 86_400_000;
export const WHERE_WINDOW_DAYS = 21;

export function whereToBuy(
  item: string,
  reports: readonly WhereReport[],
  deals: readonly WhereDeal[],
  nowMs: number,
  homeOf: ReadonlyMap<string, string> = new Map(),
  city: string | null = null,
): WhereToBuy {
  const key = itemKey(item);
  const matching = key.length < 2 ? [] : reports.filter((r) => {
    if (!r.item_name || !r.store_name || !r.timestamp || !sameCity(r.location, city)) return false;
    const at = Date.parse(r.timestamp);
    const days = (nowMs - at) / DAY_MS;
    if (!Number.isFinite(at) || days < 0 || days > WHERE_WINDOW_DAYS) return false;
    const reported = itemKey(r.item_name);
    return reported.includes(key) || key.includes(reported);
  });
  const priced = withoutOutliers(matching);
  const floorMet = priced.length >= CROWD_MIN_HOMES && homesIn(priced, homeOf) >= CROWD_MIN_HOMES;
  const typical = floorMet ? Math.round(medianOf(priced.map((r) => Number(r.price)))! * 100) / 100 : null;

  // آخر بلاغ لكل محل.
  const byStore = new Map<string, { store: string; at: number; price: number | null }>();
  for (const r of matching) {
    const k = storeKey(r.store_name!);
    if (!k) continue;
    const at = Date.parse(r.timestamp!);
    const prev = byStore.get(k);
    if (!prev || at > prev.at) {
      const price = Number(r.price);
      byStore.set(k, { store: r.store_name!.trim(), at, price: price > 0 ? price : null });
    }
  }
  const stores = [...byStore.values()]
    .map((s) => ({ store: s.store, days: Math.floor((nowMs - s.at) / DAY_MS), price: floorMet ? s.price : null }))
    .sort((a, b) => floorMet && a.price !== null && b.price !== null ? a.price - b.price : a.days - b.days)
    .slice(0, 5);

  const offers = deals
    .filter((d) => d.store && d.item_name && offerMatchesNeed(item, d.item_name) && Number(d.price) > 0)
    .map((d) => {
      const price = Number(d.price);
      const before = Number(d.price_before);
      return {
        store: d.store, item: d.item_name, price,
        before: Number.isFinite(before) && before > price ? before : null,
        until: d.valid_until ? String(d.valid_until).slice(0, 10) : null,
      };
    })
    .sort((a, b) => a.price - b.price)
    .slice(0, 4);

  return { item, typical, stores, deals: offers };
}

/** نتيجة الأداة للموديل: أرقام من الجدول، والموديل بيصيغها بس. */
export function describeWhereToBuy(w: WhereToBuy, currency: string): string {
  const lines: string[] = [];
  if (w.deals.length) {
    lines.push("عروض شغالة (من صفحات المحلات وحساباتها — ممكن تكون خلصت):");
    for (const d of w.deals) {
      lines.push(`- ${d.store}: ${d.item} بـ${d.price} ${currency}${d.before ? ` بدل ${d.before}` : ""}${d.until ? ` لحد ${d.until}` : ""}`);
    }
  }
  if (w.stores.length) {
    lines.push(w.typical !== null
      ? `فواتير عملاء زاد في مدينته (آخر ${WHERE_WINDOW_DAYS} يوم) — السعر المعتاد حوالي ${w.typical} ${currency}:`
      : `اتشاف في فواتير عملاء زاد في مدينته (آخر ${WHERE_WINDOW_DAYS} يوم) — بلاغات قليلة، فمفيش أسعار تتقال:`);
    for (const s of w.stores) {
      const when = s.days === 0 ? "النهارده" : s.days === 1 ? "امبارح" : `من ${s.days} يوم`;
      lines.push(`- ${s.store}${s.price !== null ? ` بـ${s.price} ${currency}` : ""} (${when})`);
    }
  }
  if (lines.length === 0) {
    return `مفيش عروض ولا فواتير لـ«${w.item}» في مدينته آخر ${WHERE_WINDOW_DAYS} يوم. قوله كده، واعرض تدوّر أونلاين ` +
      "(check_price_online) أو أقرب سوبرماركت (find_nearby_stores) — ماتخترعش محل ولا سعر.";
  }
  lines.push("«بنفس الاسم» مش نفس الفرع — مفيش إحداثيات في الفواتير. لو عايز الأقرب ليه، find_nearby_stores.");
  return lines.join("\n");
}
