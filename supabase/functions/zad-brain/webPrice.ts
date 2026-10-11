// webPrice.ts — سعر صنف من بحث النت بمصدره، محفوظ ٧ أيام (الموجة ٨، zad_web_prices).
//
// قرار المالك: قبل ما يبقى فيه جمهور، الأسعار من فواتير الفريق والعيلة + بحث حي موجّه وموثّق المصدر. نفس طريق
// أسعار الأدوية (medicinePrice.ts): estimate_price ببلد العميل وعملته، والنتيجة اللي ليها مصدر بتتحفظ، فعميل
// تاني بيسأل عن نفس الصنف في نفس البلد مابيبحثش تاني ٧ أيام. ومن غير مصدر = مفيش رقم.

import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { medicineKey, type MedicinePrice, pricePayload, priceFromEstimate } from "./medicinePrice.ts";

export const WEB_PRICE_TTL_DAYS = 7;

/** المفتاح: الصنف (ومحل لو اتسأل عن محل بعينه). */
export function webPriceKey(item: string, store: string | null | undefined): string {
  const s = medicineKey(String(store ?? ""));
  return `${medicineKey(item)}${s ? `|${s.slice(0, 60)}` : ""}`;
}

type Search = (payload: Record<string, unknown>) => Promise<unknown>;

export async function webPrice(
  sb: SupabaseClient,
  input: { item: string; store?: string | null; country: string | null; currency: string | null; now?: number; search: Search },
): Promise<(MedicinePrice & { store: string | null }) | null> {
  const country = String(input.country ?? "").toUpperCase();
  const item = String(input.item ?? "").trim().slice(0, 80);
  const store = String(input.store ?? "").trim().slice(0, 60) || null;
  const key = webPriceKey(item, store);
  if (medicineKey(item).length < 2 || !/^[A-Z]{2}$/.test(country)) return null;
  const now = input.now ?? Date.now();
  const { data: cached } = await sb.from("zad_web_prices")
    .select("name,store,price_low,price_high,currency,sources,found_at")
    .eq("country", country).eq("name_key", key).maybeSingle();
  const c = cached as { name: string; store: string | null; price_low: number; price_high: number; currency: string; sources: MedicinePrice["sources"]; found_at: string } | null;
  if (c && now - Date.parse(c.found_at) < WEB_PRICE_TTL_DAYS * 86_400_000) {
    return { name: c.name, store: c.store, low: Number(c.price_low), high: Number(c.price_high), currency: c.currency, sources: c.sources ?? [], found_at: c.found_at, from: "cache" };
  }
  const res = await input.search(pricePayload(item, store ?? "", country, input.currency)).catch(() => null);
  const found = priceFromEstimate(item, res, input.currency, now);
  if (!found) return null;
  await sb.from("zad_web_prices").upsert({
    country, name_key: key, name: found.name, store, price_low: found.low, price_high: found.high,
    currency: found.currency, sources: found.sources, found_at: found.found_at,
  }, { onConflict: "country,name_key" });
  return { ...found, store };
}

/** للموديل: الرقم بمصدره وتاريخه، وإنه من بحث النت مش من فواتير الناس. */
export function webPriceReply(p: (MedicinePrice & { store: string | null }) | null, item: string): string {
  if (!p) return `مالقيتش سعر موثوق لـ«${item.slice(0, 80)}» في بحث النت دلوقتي — قول كده، ومتقولش رقم من عندك.`;
  return JSON.stringify({
    item: p.name,
    ...(p.store ? { store: p.store } : {}),
    price: p.low === p.high ? p.low : `${p.low}–${p.high}`,
    currency: p.currency,
    found_on: p.found_at.slice(0, 10),
    from: p.from === "cache" ? "بحث نت محفوظ" : "بحث نت دلوقتي",
    sources: p.sources,
    note: "من بحث النت مش من فواتير عملاء زاد — قول المصدر والتاريخ، والسعر ممكن يختلف من محل لمحل.",
  });
}
