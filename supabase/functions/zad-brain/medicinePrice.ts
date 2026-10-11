// medicinePrice.ts — سعر دوا في بلد العميل (الموجة ٤ من «خطة سد الفجوات»).
//
// قرار المالك (٢٠٢٦-١٠-١٠): **بحث حي موجّه + حفظ النتيجة**؛ مفيش سحب من مواقع الأدوية (DrugEye، DwaPrices…) لحد ما
// شروطها تتراجع. البحث نفسه هو `estimate_price` في zad-core-intelligence (DuckDuckGo، والموديل بيستخرج الأرقام من
// المقاطع بس ومعاها روابطها، والأسعار بعملة تانية بتتشال). هنا: بلد العميل وعملته بيتبعتوا معاه (أداة
// check_price_online القديمة ماكانتش بتبعتهم)، والنتيجة اللي فيها سعر بتتحفظ في `zad_medicine_prices` — سعر عام
// مش بيانات عميل، فعميل تاني بيسأل عن نفس الدوا في نفس البلد مابيبحثش تاني ٣٠ يوم.
//
// زاد مش دكتور: الأداة سعر بس، مش بديل ولا جرعة.

import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { countryNameAr, normalizeMedicineName } from "./shared.ts";

export const MEDICINE_PRICE_TTL_DAYS = 30;

export interface MedicinePrice {
  name: string;
  low: number;
  high: number;
  currency: string;
  sources: Array<{ title: string; url: string }>;
  found_at: string;
  from: "cache" | "search";
}

/** مفتاح الدوا: الاسم متطبّع (همزات، تشكيل، مسافات) — «أوجمنتين ١جم» و«اوجمنتين 1جم» واحد. */
export function medicineKey(name: string): string {
  return normalizeMedicineName(name).toLowerCase().replace(/\s+/g, " ").trim().slice(0, 80);
}

/** رد estimate_price ⇒ سعر محفوظ، أو null لو مفيش رقم بمصدر. */
export function priceFromEstimate(name: string, res: unknown, currency: string | null, now: number): MedicinePrice | null {
  const r = res as {
    status?: string; low_price?: number | null; high_price?: number | null; currency?: string | null;
    sources?: Array<{ title?: string; url?: string }>;
  } | null;
  if (!r || r.status !== "ok") return null;
  const low = Number(r.low_price);
  const high = Number(r.high_price);
  if (!Number.isFinite(low) || low <= 0 || !Number.isFinite(high) || high < low) return null;
  const sources = (r.sources ?? [])
    .filter((s) => typeof s?.url === "string" && /^https?:\/\//.test(s.url))
    .slice(0, 3)
    .map((s) => ({ title: String(s.title ?? "").slice(0, 120), url: String(s.url).slice(0, 500) }));
  // سعر من غير مصدر مايتحفظش — ده كل الفرق بين بحث وتخمين.
  if (sources.length === 0) return null;
  return {
    name: name.trim().slice(0, 80),
    low: Math.round(low * 100) / 100,
    high: Math.round(high * 100) / 100,
    currency: currency || String(r.currency ?? "").slice(0, 8),
    sources,
    found_at: new Date(now).toISOString(),
    from: "search",
  };
}

type Search = (payload: Record<string, unknown>) => Promise<unknown>;

/**
 * السعر: من الكاش لو أحدث من ٣٠ يوم، وإلا بحث موجّه ويتحفظ لو لقى سعر بمصدر. null = مالقيناش سعر موثوق.
 * [search] = نداء estimate_price (callCoreIntel).
 */
export async function medicinePrice(
  sb: SupabaseClient,
  input: { name: string; country: string | null; currency: string | null; now?: number; search: Search },
): Promise<MedicinePrice | null> {
  const country = String(input.country ?? "").toUpperCase();
  const key = medicineKey(input.name);
  if (key.length < 2 || !/^[A-Z]{2}$/.test(country)) return null;
  const now = input.now ?? Date.now();
  const { data: cached } = await sb.from("zad_medicine_prices")
    .select("name,price_low,price_high,currency,sources,found_at")
    .eq("country", country).eq("name_key", key).maybeSingle();
  const c = cached as { name: string; price_low: number; price_high: number; currency: string; sources: MedicinePrice["sources"]; found_at: string } | null;
  if (c && now - Date.parse(c.found_at) < MEDICINE_PRICE_TTL_DAYS * 86_400_000) {
    return { name: c.name, low: Number(c.price_low), high: Number(c.price_high), currency: c.currency, sources: c.sources ?? [], found_at: c.found_at, from: "cache" };
  }
  const res = await input.search({
    item_name: `دواء ${input.name.trim().slice(0, 80)}`,
    store: "صيدلية",
    location: countryNameAr(country),
    currency: input.currency ?? "",
  }).catch(() => null);
  const found = priceFromEstimate(input.name, res, input.currency, now);
  if (!found) return null;
  await sb.from("zad_medicine_prices").upsert({
    country, name_key: key, name: found.name, price_low: found.low, price_high: found.high,
    currency: found.currency, sources: found.sources, found_at: found.found_at,
  }, { onConflict: "country,name_key" });
  return found;
}

/**
 * طلب estimate_price لأي سعر (check_price_online): بلد العميل باسمه وعملته — من غيرهم البحث كان من غير سوق،
 * وفلتر العملة في core-intelligence ماكانش بيشتغل (طلب المالك ٢٠٢٦-١٠-١١).
 */
export function pricePayload(item: unknown, store: unknown, country: string | null | undefined, currency: string | null | undefined) {
  const code = String(country ?? "").toUpperCase();
  return {
    item_name: String(item ?? "").trim().slice(0, 80),
    store: String(store ?? "").trim().slice(0, 60),
    location: /^[A-Z]{2}$/.test(code) ? countryNameAr(code) : "",
    currency: String(currency ?? "").trim().slice(0, 8),
  };
}

/** اللي بيرجع للموديل: الرقم ومصدره وتاريخه، وتذكير إنه سعر مش نصيحة. */
export function medicinePriceReply(p: MedicinePrice | null, name: string): string {
  if (!p) {
    return `مالقيتش سعر موثوق لـ«${name.slice(0, 80)}» في بحث النت دلوقتي — قوله كده، وماتقولش رقم من عندك. ` +
      "ممكن يسأل الصيدلي أو يبص على العلبة.";
  }
  return JSON.stringify({
    medicine: p.name,
    price: p.low === p.high ? p.low : `${p.low}–${p.high}`,
    currency: p.currency,
    found_on: p.found_at.slice(0, 10),
    from: p.from === "cache" ? "بحث محفوظ" : "بحث دلوقتي",
    sources: p.sources,
    note: "سعر من نتايج بحث، ممكن يختلف من صيدلية لصيدلية — قول المصدر والتاريخ، ومن غير أي نصيحة طبية أو بديل.",
  });
}
