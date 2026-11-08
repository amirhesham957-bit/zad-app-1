// tasteDeals.ts — العروض حسب ذوق العميل (الموجة ٤ من «خطة سد الفجوات»).
//
// الخطة: «العرض يتبعت لو طابق ذوقك بس، مرة في اليوم بالكتير»، و«محلاتك المتكررة من الفواتير — العرض اللي فيها ياخد
// أولوية». الأدوات كانت موجودة متفرقة (`fetch_live_deals` بحث حي، `interests` في الملف، أسامي المحلات في الحركات)
// والناقص الربط. هنا: الأصناف = قايمة الشراء المفتوحة الأول (احتياج حقيقي) وبعدها الاهتمامات؛ البحث مرة في تحية الصبح؛
// والعرض بيتقال لو صنفه من الأصناف دي بس، ومحل حقيقي، وسعر أو خصم. ونفس العرض (صنف + محل) مايتقالش تاني أسبوع.
//
// مش وقت عروض: الميزانية في خطر (threat OVER/DANGER)، أو وضع الطوارئ («أنا مفلس») شغال، أو البيت في ظرف — العرض
// تشجيع على صرف.
// المصدر الأول من ٢٦/١٠ (ZAD_PLAN ٤.٨/٤.٩): zad_deals — عروض متخزّنة بمحلها ومصدرها وتاريخها، من غير بحث جديد.
// البحث الحي (zad-core-intelligence) بقى احتياطي لما مفيش عرض متخزّن يطابق. والاحتياج: قايمة الشراء، وبعدها اللي
// هيخلص خلال أسبوع (zad_home_state)، وبعدها الاهتمامات.

import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { countryNameAr, type DealHere, itemKey, sameStore, travelContext } from "./shared.ts";
import { isBrokeModeActive } from "../_shared/brokeMode.ts";
import { householdFamilyId, householdFilter } from "../_shared/household.ts";
import { meaningfulWords, offerMatchesNeed, stapleGroup, stapleHead } from "./productIdentity.ts";
import { MAX_INTENT_ITEMS, openIntents } from "./purchaseIntent.ts";
import { haversineKm, type Trip, tripCost, tripEatsSaving, usableFuel } from "./tripCost.ts";
import { deliveryApp } from "../_shared/deliveryApps.ts";

export const MAX_TASTE_ITEMS = 5;
export const FAVORITE_MIN_VISITS = 3;
export const FAVORITE_WINDOW_DAYS = 60;
export const DEAL_REPEAT_DAYS = 7;
/** «🙅 مش مهتم» في تليجرام (٤.٢٠): الاحتياج ده مايتعرضش عليه عرض المدة دي. */
export const DEAL_DECLINED_DAYS = 30;
/** How much of a sent moment zad_voice_moments.delivery.text keeps (voiceMoments.ts). */
const DELIVERY_TEXT_SAVED = 300;
/** آخر نقطة للعميل أقدم من كده = مش بيته ولا مكانه دلوقتي (ZAD_PLAN ٤.٧). */
export const NEARBY_POINT_MAX_AGE_DAYS = 7;
export const NEARBY_RADIUS_METERS = 3000;

/** البحث (fetch_live_deals). index.ts بيوصّله وقت التشغيل؛ من غيره مفيش عروض — والتستات مابتكلمش النت. */
export const dealSource: { search: (payload: Record<string, unknown>, userId: string) => Promise<unknown> } = {
  search: () => Promise.resolve(null),
};

/** المحلات حوالين نقطة (nearby_pois — جوجل ثم LocationIQ، متخزّن لكل خلية). index.ts بيوصّله. */
export const nearbySource: { search: (payload: Record<string, unknown>, userId: string) => Promise<unknown> } = {
  search: () => Promise.resolve(null),
};

export interface TasteDeal {
  item: string;
  store: string;
  price: number | null;
  discount_percent: number | null;
  /** السعر قبل العرض لما المصدر قاله (zad_deals) — التوفير بيتقال بالفلوس بدل النسبة (٤.٩). */
  price_before?: number | null;
  /** price_before − price، متحسوب هنا عشان الرقم اللي يتقال يبقى في الداتا. */
  saving?: number | null;
  note: string | null;
  /** في محل من محلاته المتكررة. */
  favorite: boolean;
  /** في محل حوالين آخر نقطة ليه (٣ كم). */
  nearby?: boolean;
  /** الماركة اللي البيت بيجيبها للصنف ده (٤.١٥). */
  brand?: string | null;
  /** الفلوس ضيقة (الميزانية في خطر أو «أنا مفلس»): أرخص سعر لحاجة ناقصة، مش عرض. */
  tight?: boolean;
  /** الفلوس مرتاحة والصنف بيتخزّن والبيت بيشتريه، والعرض فيه خصم: فرصة تخزين (٤.٨). */
  stock?: boolean;
  /** المشوار بالعربية للمحل ده من نقطته (٤.١٠) — بس لو المحل ليه إحداثيات وسعر البنزين معروف. */
  trip?: Trip;
  /** العرض في تطبيق توصيل ورسومه المعتادة معروفة من فواتير العملاء (٤.١٠) — بدل المشوار. */
  delivery?: Delivery;
  /** بيت لسه مالوش قايمة ولا مخزن ولا اهتمامات: عرض على حاجة أساسية بيشتريها كل بيت (قرار المالك ٣/١١). */
  staple?: boolean;
  /** «العرض الناري» (٤.٨): خصم كبير أو ١+١ على حاجة البيت بيشتريها ومش في القايمة. */
  fire?: boolean;
  /** العرض ١+١ أو «اشتري اتنين» (deal_kind = multi_buy). */
  multi_buy?: boolean;
  /** الحاجة زي ما العميل قالها في «عايز أشتري …» (ZAD_PLAN ٥.٨ (٣)) — العرض ده على نية مش على احتياج. */
  intent?: string;
  /** صنف + محل — عليه بيتعمل منع التكرار. */
  key: string;
  /** من zad_deals بس: نوع المصدر ورابطه ولحد إمتى. البحث الحي مالوش مصدر متخزّن. */
  source?: { kind: string; url: string | null; until: string | null } | null;
}

// ── ماركة البيت (ZAD_PLAN ٤.١٥) ───────────────────────────────────────────────────────────────────
// من المشتريات نفسها: «شاي اسود 40جم بروك» مرتين = البيت ده بيجيب بروك. المقاس ٢٦/١٠ على المخزن: الشاي بروك ×٢،
// والمية صافي ×٣ قصاد إيلان ×٢ ونستله وداساني وبوفانا — فالماركة بتتحسب لما تبقى نص مرات الصنف على الأقل.

/** أوصاف مش ماركات (بعد المفتاح). */
const DESCRIPTORS = new Set([
  "كامل", "دسم", "قليل", "خالي", "اسود", "اخضر", "ابيض", "احمر", "بلدي", "رفيع", "وسط", "سايب", "سايبه",
  "معدني", "معدنيه", "طبيعي", "طبيعيه", "طازج", "طازه", "مستورد", "شرائح", "قمح", "جالون", "فوري", "صغير",
  "كبير", "عادي", "مصري", "اصلي", "جديد", "بيور", "لايف", "متعدد", "استخدام",
]);
export const BRAND_MIN_TIMES = 2;

/** الأساسيات اللي بتستحمل التخزين — من غير الألبان والعيش والبيض والجبنة واللحوم. */
const STORABLE_GROUPS: ReadonlySet<number> = new Set(
  ["مياه", "رز", "زيت", "سكر", "شاي", "قهوه", "مكرونه", "صابون", "مناديل", "عدس", "فول"]
    .map(stapleGroup).filter((g): g is number => g !== undefined),
);

/** أساسيات بتتخزّن البيت اشتراها قبل كده ([names] = المخزن). عليها بس العرض يبقى «فرصة تخزين». */
export function storableBought(names: readonly string[]): Set<number> {
  const out = new Set<number>();
  for (const name of names) {
    const { group } = brandWords(name);
    if (group !== undefined && STORABLE_GROUPS.has(group)) out.add(group);
  }
  return out;
}

/** كلمات الماركة المرشّحة في اسم صنف: من غير الأساسيات والأوصاف والتغليف والأرقام. */
function brandWords(name: string): { group: number | undefined; words: string[] } {
  const words = meaningfulWords(String(name ?? "").replace(/[()[\]{}،,؛;:.\-/+*«»"'×]/g, " "))
    .filter((w) => !/\d/.test(w));
  const group = words.map(stapleGroup).find((g) => g !== undefined);
  return { group, words: words.filter((w) => stapleGroup(w) === undefined && !DESCRIPTORS.has(w) && w.length >= 3) };
}

/**
 * ماركة البيت لكل عيلة أساسيات: كلمة اتكررت مع الصنف ده [BRAND_MIN_TIMES] مرات أو أكتر، وفي نص مرات الصنف على
 * الأقل. [names] = أسامي اللي اتشرى (المخزن). الناتج: عيلة ⇐ كلمة الماركة (بعد المفتاح).
 */
export function houseBrands(names: readonly string[]): Map<number, string> {
  const perGroup = new Map<number, { rows: number; counts: Map<string, number> }>();
  for (const name of names) {
    const { group, words } = brandWords(name);
    if (group === undefined) continue;
    const g = perGroup.get(group) ?? { rows: 0, counts: new Map() };
    g.rows++;
    for (const w of new Set(words)) g.counts.set(w, (g.counts.get(w) ?? 0) + 1);
    perGroup.set(group, g);
  }
  const out = new Map<number, string>();
  for (const [group, g] of perGroup) {
    const [best] = [...g.counts.entries()].sort((a, b) => b[1] - a[1]);
    if (best && best[1] >= BRAND_MIN_TIMES && best[1] * 2 >= g.rows) out.set(group, best[0]);
  }
  return out;
}

/**
 * الماركة اللي العميل قالها بنفسه («إحنا بنجيب نادك مش المراعي») — ملاحظات remember بسكوب brand_preference،
 * مكتوبة «<الصنف> <الماركة>». اللي بعد «مش/بدل/مو» اترفض فمش ماركته. أول كلمة ماركة بس، وملاحظة مافيهاش صنف
 * أساسي بتتساب.
 */
export const BRAND_PREFERENCE_SCOPE = "brand_preference";
export function statedBrands(notes: readonly string[]): Map<number, string> {
  const out = new Map<number, string>();
  for (const note of notes) {
    const kept = String(note ?? "").split(/(?:^|\s)(?:مش|بدل|مو|ماشي|لا)(?:\s|$)/)[0];
    const { group, words } = brandWords(kept);
    if (group !== undefined && words[0] && !out.has(group)) out.set(group, words[0]);
  }
  return out;
}

/**
 * المحل اللي العميل قال إنه بيشتري منه («إحنا بنجيب من كيو»، ٤.١٥) — ملاحظات remember بسكوب store_preference، الملاحظة
 * اسم المحل بس. اللي بعد «مش/بدل/مو» اترفض. بيتعدّ من محلاته المتكررة وقبلها، لأنه قالها بنفسه.
 */
export const STORE_PREFERENCE_SCOPE = "store_preference";
export function statedStores(notes: readonly string[]): string[] {
  const out: string[] = [];
  for (const note of notes) {
    const kept = String(note ?? "").split(/(?:^|\s)(?:مش|بدل|مو|ماشي|لا)(?:\s|$)/)[0]
      .replace(/^\s*(?:من|محل|سوبر ?ماركت|هايبر)\s+/, "").replace(/\s+/g, " ").trim().slice(0, 60);
    if (kept.length >= 2 && !out.some((s) => itemKey(s) === itemKey(kept))) out.push(kept);
  }
  return out;
}

/** ماركة البيت في اسم العرض ده، أو null. */
export function offerBrand(offered: string, brands: ReadonlyMap<number, string>): string | null {
  if (brands.size === 0) return null;
  const { group, words } = brandWords(offered);
  const brand = group === undefined ? undefined : brands.get(group);
  return brand && words.includes(brand) ? brand : null;
}

/** الأصناف اللي بندوّر لها: قايمة الشراء المفتوحة الأول، وبعدها الاهتمامات. مفيش تكرار، ٥ بالكتير. */
export function tasteItems(shopping: readonly string[], interests: readonly string[], max = MAX_TASTE_ITEMS): string[] {
  const out: string[] = [];
  const seen = new Set<string>();
  for (const raw of [...shopping, ...interests]) {
    const name = String(raw ?? "").replace(/\s+/g, " ").trim().slice(0, 40);
    const key = itemKey(name);
    if (name.length < 2 || seen.has(key)) continue;
    seen.add(key);
    out.push(name);
    if (out.length >= max) break;
  }
  return out;
}

/** محلاته المتكررة: اسم تاجر اتكرر ٣ مرات أو أكتر آخر ٦٠ يوم (اسم باكدج تطبيق مش محل). */
export function favoriteStores(rows: ReadonlyArray<{ merchant_name: string | null }>): string[] {
  const counts = new Map<string, { name: string; n: number }>();
  for (const r of rows) {
    const name = String(r.merchant_name ?? "").trim();
    if (name.length < 2 || /^[a-z0-9_]+(\.[a-z0-9_]+)+$/i.test(name)) continue;
    const key = itemKey(name);
    const c = counts.get(key) ?? { name, n: 0 };
    c.n++;
    counts.set(key, c);
  }
  return [...counts.values()].filter((c) => c.n >= FAVORITE_MIN_VISITS).sort((a, b) => b.n - a.n).map((c) => c.name);
}

const sameName = (a: string, b: string) => {
  const ka = itemKey(a);
  const kb = itemKey(b);
  return ka.length >= 2 && kb.length >= 2 && (ka.includes(kb) || kb.includes(ka));
};

/**
 * العرض اللي يتقال، أو null. لازم: صنفه من أصناف الذوق، محل باسم، وسعر أو خصم موجب. الأولوية: محل من محلاته،
 * بعدها الماركة اللي البيت بيجيبها ([brands]، ٤.١٥)، بعدها محل قريب منه ([nearby] = أسامي محلات حوالين آخر نقطة)،
 * بعدها أكبر خصم. [skip] = مفاتيح اتقالت آخر أسبوع.
 *
 * [tight] (ZAD_PLAN ٤.٨، الفلوس ضيقة): [items] هي النواقص بس بترتيب الأهمية، والسعر شرط. أول ناقص ليه عرض
 * بياخد الخانة، وجواه الأرخص — محله المعتاد مش ميزة لو أغلى — والقريب لو السعر واحد.
 */
export function pickDeal(
  raw: unknown,
  items: readonly string[],
  favorites: readonly string[],
  skip: ReadonlySet<string>,
  nearby: readonly string[] = [],
  tight = false,
  brands: ReadonlyMap<number, string> = new Map(),
  stockable: ReadonlySet<number> = new Set(),
): TasteDeal | null {
  if (!Array.isArray(raw)) return null;
  const found: TasteDeal[] = [];
  for (const d of raw as Array<Record<string, unknown>>) {
    const item = String(d?.item ?? "").trim().slice(0, 60);
    const store = String(d?.store ?? "").trim().slice(0, 60);
    const price = Number(d?.price);
    const discount = Number(d?.discount_percent);
    const hasPrice = Number.isFinite(price) && price > 0;
    const hasDiscount = Number.isFinite(discount) && discount > 0 && discount < 100;
    const before = Number(d?.price_before);
    const hasBefore = hasPrice && Number.isFinite(before) && before > price;
    if (!item || store.length < 2 || (!hasPrice && !hasDiscount) || (tight && !hasPrice)) continue;
    const wanted = items.find((w) => offerMatchesNeed(w, item));
    if (!wanted) continue;
    const key = `deal:${itemKey(wanted)}:${itemKey(store)}`;
    if (skip.has(key) || skip.has(`need:${itemKey(wanted)}`)) continue;
    const src = d?.source as { kind?: unknown; url?: unknown; until?: unknown } | undefined;
    found.push({
      item, store, key,
      ...(src && typeof src.kind === "string"
        ? { source: { kind: src.kind, url: typeof src.url === "string" ? src.url : null, until: typeof src.until === "string" ? src.until.slice(0, 10) : null } }
        : {}),
      price: hasPrice ? Math.round(price * 100) / 100 : null,
      discount_percent: hasDiscount ? Math.round(discount) : null,
      ...(hasBefore ? { price_before: Math.round(before * 100) / 100, saving: Math.round((before - price) * 100) / 100 } : {}),
      note: typeof d?.note === "string" && d.note.trim() ? d.note.trim().slice(0, 120) : null,
      favorite: favorites.some((f) => sameName(f, store)),
      nearby: nearby.some((n) => sameName(n, store)),
      brand: offerBrand(item, brands),
      ...(d?.trip && typeof d.trip === "object" ? { trip: d.trip as Trip } : {}),
      ...(d?.delivery && typeof d.delivery === "object" ? { delivery: d.delivery as Delivery } : {}),
      ...(d?.deal_kind === "multi_buy" ? { multi_buy: true } : {}),
      ...(tight ? { tight: true } : {}),
      ...(!tight && (hasBefore || hasDiscount) && stockable.has(brandWords(item).group ?? -1) ? { stock: true } : {}),
    });
  }
  if (tight) {
    const need = (d: TasteDeal) => items.findIndex((w) => offerMatchesNeed(w, d.item));
    found.sort((a, b) => need(a) - need(b) || (a.price ?? 0) - (b.price ?? 0) || Number(b.nearby) - Number(a.nearby));
    return found[0] ?? null;
  }
  found.sort((a, b) =>
    Number(b.favorite) - Number(a.favorite) || Number(!!b.brand) - Number(!!a.brand) || Number(b.nearby) - Number(a.nearby) ||
    (b.discount_percent ?? 0) - (a.discount_percent ?? 0)
  );
  return found[0] ?? null;
}

export interface StoredDealRow {
  store: string;
  lat?: number | string | null;
  lng?: number | string | null;
  item_name: string;
  price: number | string;
  price_before: number | string | null;
  source_kind: string;
  source_url: string | null;
  valid_until: string | null;
  deal_kind?: string | null;
}

/**
 * صفوف zad_deals بشكل نتيجة البحث اللي [pickDeal] بيقراه: الخصم من السعر قبل العرض، والمصدر معاه. [trip] = المشوار
 * للمحل (٤.١٠): لو بياكل التوفير كله العرض بيتشال هنا، وإلا بيمشي مع العرض عشان يتقال.
 */
export function storedDeals(
  rows: readonly StoredDealRow[] | null | undefined,
  trip: (r: StoredDealRow) => Trip | null = () => null,
  delivery: (r: StoredDealRow) => Delivery | null = () => null,
): Array<Record<string, unknown>> {
  const out: Array<Record<string, unknown>> = [];
  for (const r of rows ?? []) {
    const price = Number(r.price);
    const before = Number(r.price_before);
    const discount = Number.isFinite(before) && before > price && price > 0 ? ((before - price) / before) * 100 : null;
    const saving = Number.isFinite(before) && before > price ? before - price : null;
    // تطبيق توصيل: بيوصل، فمفيش مشوار؛ رسومه هي اللي بتتطرح من التوفير.
    const del = delivery(r);
    const t = del ? null : trip(r);
    if (tripEatsSaving(t, saving)) continue;
    if (del && saving !== null && del.fee >= saving) continue;
    out.push({
      item: r.item_name, store: r.store, price, price_before: Number.isFinite(before) ? before : null, discount_percent: discount, note: null,
      source: { kind: r.source_kind, url: r.source_url, until: r.valid_until },
      ...(r.deal_kind ? { deal_kind: r.deal_kind } : {}),
      ...(t ? { trip: t } : {}),
      ...(del ? { delivery: del } : {}),
    });
  }
  return out;
}

/** رسوم التوصيل المعتادة لتطبيق (٤.١٠): الوسيط من فواتير العملاء. */
export interface Delivery {
  app: string;
  fee: number;
}

/**
 * رسوم العرض لو محله تطبيق توصيل ليه رسوم معروفة بنفس عملة العرض، وإلا null. [typical] = صفوف
 * zad_delivery_fees_typical (الوسيط من قرايتين أو أكتر).
 */
export function deliveryOf(
  typical: ReadonlyArray<{ app_key?: string; app?: string; fee?: number | string; currency?: string }> | null | undefined,
  store: string,
  currency: string | null | undefined,
): Delivery | null {
  const app = deliveryApp(store);
  if (!app) return null;
  const row = (typical ?? []).find((t) => t.app_key === app.key && (!currency || !t.currency || t.currency.toUpperCase() === currency.toUpperCase()));
  const fee = Number(row?.fee);
  return row && fee > 0 ? { app: app.name, fee: Math.round(fee * 100) / 100 } : null;
}

/** «العرض الناري» (٤.٨): خصم ٤٠٪ أو أكتر، أو ١+١. */
export const FIRE_DISCOUNT_PERCENT = 40;

export function isFireDeal(d: Record<string, unknown>): boolean {
  const discount = Number(d?.discount_percent);
  return d?.deal_kind === "multi_buy" || (Number.isFinite(discount) && discount >= FIRE_DISCOUNT_PERCENT && discount < 100);
}

/**
 * فئات اللي اتشرى (٤.٨): عيلة الأساسيات لكل اسم في المخزن، باسم العيلة نفسها («جبنه»، «زيت»). «جبنة بيضا» اتشرت ⇒
 * «جبنه» بتطابق «جبنة رومي» في [offerMatchesNeed]. الأسامي اللي برّه العيلات مالهاش فئة.
 */
export function boughtFamilies(names: readonly string[]): string[] {
  const out: string[] = [];
  for (const name of names) {
    const head = stapleHead(brandWords(name).group ?? -1);
    if (head && !out.includes(head)) out.push(head);
  }
  return out;
}

/**
 * «العرض الناري» (٤.٨): بيعدّي شرط «في القايمة» لو البيت اشترى الصنف أو فئته قبل كده ([bought] = أسامي المخزن) —
 * الصنف نفسه الأول، وبعده الفئة. عمره ما بيتقال
 * والفلوس ضيقة — اللي بينادي مابينادهوش ساعتها، وهنا كمان [tight] = ولا حاجة.
 */
export function pickFireDeal(
  raw: unknown,
  bought: readonly string[],
  favorites: readonly string[],
  skip: ReadonlySet<string>,
  nearby: readonly string[] = [],
  tight = false,
  brands: ReadonlyMap<number, string> = new Map(),
): TasteDeal | null {
  if (tight || !Array.isArray(raw)) return null;
  const fire = (raw as Array<Record<string, unknown>>).filter(isFireDeal);
  if (fire.length === 0) return null;
  const picked = pickDeal(fire, tasteItems([...bought, ...boughtFamilies(bought)], [], 240), favorites, skip, nearby, false, brands);
  return picked ? { ...picked, fire: true } : null;
}

/** أساسيات كل بيت عربي — الاحتياج الافتراضي لبيت لسه زاد مايعرفش عنه حاجة. */
export const EVERYDAY_STAPLES: readonly string[] = [
  "زيت", "رز", "سكر", "شاي", "لبن", "بيض", "مكرونة", "عدس", "فول", "دقيق", "سمن", "قهوة", "مية", "صابون", "مناديل",
];

/**
 * عرض أساسي (قرار المالك ٣/١١: العروض توصل لوحدها): بيت مالوش احتياج معروف بياخد عرض متخزّن على حاجة من
 * [EVERYDAY_STAPLES]، من نفس قواعد الاختيار (محله، القريب، أكبر خصم). عمره ما بيتقال والفلوس ضيقة — الطوارئ = النواقص بس.
 */
export function pickStapleDeal(
  raw: unknown,
  favorites: readonly string[],
  skip: ReadonlySet<string>,
  nearby: readonly string[] = [],
  tight = false,
): TasteDeal | null {
  if (tight) return null;
  const picked = pickDeal(raw, EVERYDAY_STAPLES, favorites, skip, nearby, false);
  return picked ? { ...picked, staple: true } : null;
}

/** صفوف zad_deals من غير المصادر اللي وقفت لوحدها على بلاغات العملاء (zad_deal_paused_sources، ٤.١٩). */
export function withoutPausedSources<T extends { source_kind: string }>(rows: readonly T[] | null | undefined, paused: ReadonlySet<string>): T[] {
  return (rows ?? []).filter((r) => !paused.has(r.source_kind));
}

/** «انت جنب المطعم» (ZAD_PLAN ٤.١٨): أي عرض ساري في المكان ده، الأحدث تاريخاً الأول، ٣ بالكتير، صنف واحد مرة. */
export function dealsAtPlace(rows: readonly StoredDealRow[] | null | undefined, storeName: string): DealHere[] {
  const out: DealHere[] = [];
  const taken = new Set<string>();
  for (const r of rows ?? []) {
    const price = Number(r.price);
    if (!(price > 0) || !sameStore(r.store, storeName) || taken.has(itemKey(r.item_name))) continue;
    taken.add(itemKey(r.item_name));
    const before = Number(r.price_before);
    out.push({
      item: r.item_name, price, price_before: Number.isFinite(before) && before > price ? before : null,
      until: r.valid_until ? r.valid_until.slice(0, 10) : null, source_kind: r.source_kind,
    });
    if (out.length === 3) break;
  }
  return out;
}

/**
 * «انت جنب المحل» (ZAD_PLAN ٤.٩): عروض zad_deals السارية في المحل ده على اللي ناقص ([missing] بترتيب أهميته)،
 * عرض لكل احتياج، ٣ بالكتير. «قبل» بيتقال بس لو أغلى من السعر.
 */
export function dealsHere(rows: readonly StoredDealRow[] | null | undefined, storeName: string, missing: readonly string[]): DealHere[] {
  const out: DealHere[] = [];
  const taken = new Set<string>();
  for (const r of rows ?? []) {
    const price = Number(r.price);
    if (!(price > 0) || !sameStore(r.store, storeName)) continue;
    const need = missing.find((w) => offerMatchesNeed(w, r.item_name));
    if (!need || taken.has(itemKey(need))) continue;
    taken.add(itemKey(need));
    const before = Number(r.price_before);
    out.push({
      item: r.item_name, price, price_before: Number.isFinite(before) && before > price ? before : null,
      until: r.valid_until ? r.valid_until.slice(0, 10) : null, source_kind: r.source_kind,
    });
    if (out.length === 3) break;
  }
  return out;
}

/**
 * النقطة اللي نسأل حواليها: آخر موقع للعميل لو عمره أقل من أسبوع، مقرّبة لخانتين (~١ كم) — نقطة البيت
 * التقريبية مش مكانه بالظبط، والجيران بيشاركوا نفس الكاش. null = مفيش نقطة أو قديمة.
 */
export function nearbyPoint(
  row: { last_lat?: number | null; last_lon?: number | null; last_location_at?: string | null } | null | undefined,
  nowMs: number,
): { lat: number; lon: number } | null {
  const lat = Number(row?.last_lat);
  const lon = Number(row?.last_lon);
  const at = Date.parse(String(row?.last_location_at ?? ""));
  if (!row?.last_lat || !row?.last_lon || !Number.isFinite(lat) || !Number.isFinite(lon) || !Number.isFinite(at)) return null;
  if (nowMs - at > NEARBY_POINT_MAX_AGE_DAYS * 86_400_000) return null;
  return { lat: Math.round(lat * 100) / 100, lon: Math.round(lon * 100) / 100 };
}

/**
 * ٤.٣: عروض مدينته الأول وبعدها البلد كله (''). عرض في مدينة تانية بيتشال، ونفس المحل والصنف في مدينته بيغلب
 * صف البلد. من غير مدينة = الصفوف زي ما هي (زي الأول) — إلا نشرة منطقة (٧/١١): سعر نشرة الرياض مش سعر جدة، فمن غير
 * مدينة معروفة بتوصل نشرات البلد كله بس.
 */
const CITY_SCOPED_SOURCES = new Set(["search", "flyer"]);
export function dealsForCity<T extends { city?: string | null; store?: string | null; item_name?: string | null; source_kind?: string | null }>(
  rows: T[] | null | undefined,
  city: string,
): T[] {
  if (!city) return (rows ?? []).filter((r) => !(r.source_kind === "flyer" && (r.city ?? "") !== ""));
  const key = (r: T) => `${itemKey(r.store ?? "")}|${itemKey(r.item_name ?? "")}`;
  const mine = (rows ?? []).filter((r) => (r.city ?? "") === city);
  const local = new Set(mine.map(key));
  // مدينة الفاتورة كلام حر من الكشف («غير محدد»، «القاهرة»)، والعرض ليه إحداثيات والمشوار بيحكم عليه — فبس صفوف
  // البحث في مدينة تانية هي اللي بتتشال.
  const other = (r: T) => (r.city ?? "") !== "" && (r.city ?? "") !== city;
  return [...mine, ...(rows ?? []).filter((r) => (r.city ?? "") !== city && !(other(r) && CITY_SCOPED_SOURCES.has(r.source_kind ?? "")) && !local.has(key(r)))];
}

/** مدينة العميل (zad_user_city) لو في نفس بلد العرض؛ وإلا ''. فشل = ''. */
export async function customerCity(sb: SupabaseClient, userId: string, country: string): Promise<string> {
  const { data } = await sb.from("zad_user_city").select("country,city").eq("user_id", userId).maybeSingle();
  const row = data as { country?: string | null; city?: string | null } | null;
  return row && String(row.country ?? "").toUpperCase() === country ? String(row.city ?? "") : "";
}

/** أسامي المحلات من رد nearby_pois ({stores: [{name}]}). */
export function nearbyStoreNames(raw: unknown): string[] {
  const stores = (raw as { stores?: unknown } | null)?.stores;
  if (!Array.isArray(stores)) return [];
  return stores.map((s) => String((s as { name?: unknown })?.name ?? "").trim()).filter((n) => n.length >= 2).slice(0, 20);
}

/** المحلات حوالين نقطته بإحداثياتها (٤.٧) — من نفس رد nearby_pois. */
export function nearbyStorePlaces(raw: unknown): Array<{ name: string; lat: number; lon: number }> {
  const stores = (raw as { stores?: unknown } | null)?.stores;
  if (!Array.isArray(stores)) return [];
  const out: Array<{ name: string; lat: number; lon: number }> = [];
  for (const s of stores as Array<{ name?: unknown; lat?: unknown; lon?: unknown }>) {
    const name = String(s?.name ?? "").trim();
    const lat = Number(s?.lat);
    const lon = Number(s?.lon);
    if (name.length >= 2 && Number.isFinite(lat) && Number.isFinite(lon)) out.push({ name, lat, lon });
  }
  return out.slice(0, 20);
}

/**
 * فرع العرض (٤.٧): عرض البحث أو السوشيال مالوش إحداثيات، بس لو المحل ده من المحلات حوالين نقطته، الفرع هو أقرب
 * واحد باسمه منها — فالمشوار (٤.١٠) يتحسب له. العرض اللي ليه إحداثيات (فاتورة) بيفضل زي ما هو.
 */
export function withBranch<T extends { store: string; lat?: number | string | null; lng?: number | string | null }>(
  row: T,
  places: ReadonlyArray<{ name: string; lat: number; lon: number }>,
  home: { lat: number; lon: number } | null,
): T {
  if ((row.lat != null && row.lng != null) || !home) return row;
  const near = places.filter((p) => sameName(p.name, row.store))
    .sort((a, b) => haversineKm(home, a) - haversineKm(home, b))[0];
  return near ? { ...row, lat: near.lat, lng: near.lon } : row;
}

/**
 * «عندك عربية؟» (٤.١٠): ملاحظة remember بسكوب transport. «معندناش عربية» / «بنروح مواصلات» = مفيش سطر مشوار بالعربية
 * ولا المشوار بيشيل العرض. من غير ملاحظة = زي الأول (العربية).
 */
export const TRANSPORT_SCOPE = "transport";
export function saysNoCar(notes: readonly string[]): boolean {
  return notes.some((n) => {
    const t = String(n ?? "");
    return /(?:مش|مفيش|معند|ماعند|من غير|بدون|ما\s*عند|ماعند)\S*\s*(?:\S+\s+)?(?:عربي|عربيه|عربية|سياره|سيارة|سيارات)/.test(t) ||
      (/(?:مواصلات|تاكسي|اوبر|أوبر|كريم|مترو|باص|مشي)/.test(t) && !/عربي|سيار/.test(t));
  });
}

/** اللي هيخلص خلال أسبوع من حالة البيت (pantry.running_out)، الأقرب الأول. */
export function runningOutNames(state: unknown): string[] {
  const list = (state as { pantry?: { running_out?: unknown } } | null)?.pantry?.running_out;
  return Array.isArray(list) ? list.map((r) => String((r as { name?: unknown })?.name ?? "")).filter(Boolean) : [];
}

/** بلد العرض: البلد اللي العميل فيه دلوقتي (travelContext)، وإلا بلد الحساب. «» لو مش معروف. */
export function dealCountry(
  row: { country?: string | null; travel_country?: string | null; travel_since?: string | null } | null | undefined,
  nowMs: number,
): string {
  return travelContext(row, nowMs)?.in ?? String(row?.country ?? "").trim().toUpperCase();
}

/** Case, Arabic letter forms and digits folded, so the model's spelling of a store still matches. */
function foldForMatch(text: string): string {
  return text.toLowerCase()
    .replace(/[٠-٩]/g, (d) => String("٠١٢٣٤٥٦٧٨٩".indexOf(d)))
    .replace(/[\u064B-\u0652\u0640]/g, "")
    .replace(/[أإآ]/g, "ا").replace(/ى/g, "ي").replace(/ة/g, "ه")
    .replace(/\s+/g, " ").trim();
}

/** Did the text the customer will read actually name this deal — its store, or at least two words of the item? */
export function saysTheDeal(text: string, deal: { item?: unknown; store?: unknown }): boolean {
  const said = foldForMatch(text);
  const store = typeof deal.store === "string" ? foldForMatch(deal.store) : "";
  if (store.length >= 2 && said.includes(store)) return true;
  const words = typeof deal.item === "string" ? foldForMatch(deal.item).split(/[\s\-–—/]+/).filter((w) => w.length >= 3) : [];
  return words.filter((w) => said.includes(w)).length >= Math.min(2, words.length) && words.length > 0;
}

/**
 * A deal counts as offered only if the customer got it. On 2026-11-08, 10 of the last 16 greetings with a deal in their
 * facts never said it, and the deal was then held back for a week. A text that leaves the deal out doesn't count
 * (failed sends never reach this: the query reads sent rows). A row with no saved text yet, or one cut at [DELIVERY_TEXT_SAVED], can't be judged and still counts.
 */
function reachedTheCustomer(row: { facts?: unknown; delivery?: unknown }): boolean {
  const text = (row.delivery as { text?: unknown } | null | undefined)?.text;
  if (typeof text !== "string" || text.length >= DELIVERY_TEXT_SAVED) return true;
  return saysTheDeal(text, (row.facts as { taste_deal: { item?: unknown; store?: unknown } }).taste_deal);
}

/**
 * مفاتيح العروض اللي اتقالت (facts.taste_deal.key في تحيات الصبح) آخر [DEAL_REPEAT_DAYS] يوم، و`need:<صنف>` لكل عرض
 * اتقال عليه «مش مهتم» (facts.taste_deal.answer = no) آخر [DEAL_DECLINED_DAYS] يوم. صف من غير تاريخ = جديد.
 */
export function askedDealKeys(rows: ReadonlyArray<{ facts?: unknown; created_at?: string | null; delivery?: unknown }> | null | undefined, nowMs = Date.now()): Set<string> {
  const keys = new Set<string>();
  for (const r of rows ?? []) {
    const deal = (r?.facts as { taste_deal?: { key?: unknown; answer?: unknown; item?: unknown; store?: unknown } } | null)?.taste_deal;
    const key = deal?.key;
    if (typeof key !== "string" || !key) continue;
    if (!deal?.answer && !reachedTheCustomer(r)) continue;
    const at = Date.parse(String(r?.created_at ?? ""));
    const age = Number.isFinite(at) ? nowMs - at : 0;
    // «العرض ده غلط» (٤.١٩): نفس العرض مايتقالش تاني شهر، مش أسبوع بس.
    if (age <= (deal?.answer === "wrong" ? DEAL_DECLINED_DAYS : DEAL_REPEAT_DAYS) * 86_400_000) keys.add(key);
    const need = key.split(":")[1];
    if (deal?.answer === "no" && need && age <= DEAL_DECLINED_DAYS * 86_400_000) keys.add(`need:${need}`);
  }
  return keys;
}

/** عرض الصبح: القرايات، البحث، والاختيار. أي فشل = مفيش عرض. */
/**
 * [tight] = الميزانية في خطر (OVER/DANGER). هو و«أنا مفلس» مابيقفلوش العرض زي الأول (ZAD_PLAN ٤.٨): بيقصروه على
 * النواقص — اللي هيخلص الأول، وبعده قايمة الشرا — وبأرخص سعر، من غير اهتمامات.
 */
export async function loadTasteDeal(sb: SupabaseClient, userId: string, now = Date.now(), opts: { tight?: boolean; comfortable?: boolean } = {}): Promise<TasteDeal | null> {
  try {
    const family = await householdFamilyId(sb, userId);
    const [{ data: shop }, { data: profile }, { data: user }, { data: txns }, { data: past }, broke, { data: home }, { data: bought }, { data: said }] = await Promise.all([
      sb.from("zad_shopping_list").select("item_name").or(householdFilter(userId, family)).eq("is_purchased", false).limit(20),
      sb.from("zad_customer_profile").select("interests").eq("user_id", userId).maybeSingle(),
      sb.from("zad_users").select("country,travel_country,travel_since,last_lat,last_lon,last_location_at").eq("id", userId).maybeSingle(),
      sb.from("zad_transactions").select("merchant_name,title,created_at").eq("user_id", userId).eq("txn_kind", "expense")
        .gte("created_at", new Date(now - FAVORITE_WINDOW_DAYS * 86_400_000).toISOString()).limit(500),
      sb.from("zad_voice_moments").select("facts,created_at,delivery").eq("user_id", userId).eq("moment", "morning_greeting").eq("status", "sent")
        .gte("created_at", new Date(now - DEAL_DECLINED_DAYS * 86_400_000).toISOString()).limit(40),
      // فشل القراية = اعتبره شغال: النواقص بس بأرخص سعر، مش عرض تخزين.
      sb.from("zad_broke_mode").select("ends_at,ended_at").eq("user_id", userId).maybeSingle()
        .then((r) => r.error ? true : isBrokeModeActive(r.data as { ends_at?: string | null; ended_at?: string | null } | null, now), () => true),
      sb.from("zad_home_state").select("state").eq("user_id", userId).maybeSingle(),
      // ٤.١٥: اللي اتشرى قبل كده — منه ماركة البيت لكل صنف.
      sb.from("zad_inventory").select("item_name,created_at").or(householdFilter(userId, family)).limit(300),
      // ٤.١٥: الماركة اللي قالها في الشات — بتغلب اللي اتحسب من المشتريات.
      // ٤.١٥: والمحل اللي قال إنه بيشتري منه.
      sb.from("zad_memory").select("note,scope,valid_until").eq("user_id", userId).in("scope", [BRAND_PREFERENCE_SCOPE, STORE_PREFERENCE_SCOPE, TRANSPORT_SCOPE])
        .is("superseded_by", null).order("created_at", { ascending: false }).limit(20),
    ]);
    const tight = broke || opts.tight === true;
    const interests = (profile as { interests?: unknown } | null)?.interests;
    const shopping = ((shop ?? []) as Array<{ item_name: string }>).map((r) => r.item_name);
    const runningOut = runningOutNames((home as { state?: unknown } | null)?.state);
    // ٥.٨ (٣): «عايز أشتري جاكيت» — قبل قايمة الشرا لأنه قالها بنفسه؛ واللي اتشرى بيتقفل هنا. الفلوس ضيقة = مش وقت
    // رغبات، النواقص بس.
    const boughtRows = [
      ...((txns ?? []) as Array<{ title?: string | null; created_at?: string | null }>).map((t) => ({ name: t.title ?? null, at: t.created_at ?? null })),
      ...((bought ?? []) as Array<{ item_name: string | null; created_at?: string | null }>).map((b) => ({ name: b.item_name, at: b.created_at ?? null })),
    ];
    const wants = tight ? [] : (await openIntents(sb, userId, boughtRows, now)).slice(0, MAX_INTENT_ITEMS).map((i) => i.item);
    const items = tight
      ? tasteItems([...runningOut, ...shopping], [])
      : tasteItems([...wants, ...shopping, ...runningOut], Array.isArray(interests) ? interests.map(String) : []);
    // ٣.١٤: وهو مسافر، العرض من البلد اللي هو فيه — عرض في محل في بلده مالوش لازمة وهو برّه.
    const country = dealCountry(user as { country?: string | null; travel_country?: string | null; travel_since?: string | null } | null, now);
    const boughtNames = ((bought ?? []) as Array<{ item_name: string | null }>).map((r) => r.item_name ?? "");
    // من غير احتياج ممكن يبقى فيه عرض ناري (٤.٨) على حاجة اتشرت قبل كده — مش والفلوس ضيقة.
    // من غير احتياج خالص: عرض أساسي (EVERYDAY_STAPLES) — مش والفلوس ضيقة.
    if (!/^[A-Z]{2}$/.test(country) || (items.length === 0 && tight)) return null;
    const saidRows = ((said ?? []) as Array<{ note: string | null; scope?: string | null; valid_until?: string | null }>)
      .filter((m) => !m.valid_until || Date.parse(m.valid_until) > now);
    const saidOf = (scope: string) => saidRows.filter((m) => (m.scope ?? BRAND_PREFERENCE_SCOPE) === scope).map((m) => m.note ?? "");
    const favorites = [
      ...statedStores(saidOf(STORE_PREFERENCE_SCOPE)),
      ...favoriteStores((txns ?? []) as Array<{ merchant_name: string | null }>),
    ].filter((name, i, all) => all.findIndex((o) => itemKey(o) === itemKey(name)) === i);
    const skip = askedDealKeys(past as Array<{ facts?: unknown; created_at?: string | null; delivery?: unknown }>, now);
    const brands = new Map([...houseBrands(boughtNames), ...statedBrands(saidOf(BRAND_PREFERENCE_SCOPE))]);
    // ٤.٨: الفلوس مرتاحة ⇒ عرض على أساسي بيتخزّن واتشرى قبل كده بيتقال كفرصة تخزين.
    const stockable = opts.comfortable && !tight ? storableBought(boughtNames) : new Set<number>();
    // ٤.٧: المحلات حوالين نقطته. فشل أو مفيش نقطة = من غير ترتيب بالقرب، مش من غير عرض.
    const point = nearbyPoint(user as { last_lat?: number | null; last_lon?: number | null; last_location_at?: string | null } | null, now);
    const nearbyRaw = point
      ? await nearbySource.search({ ...point, tag: "supermarket", radius_meters: NEARBY_RADIUS_METERS }, userId).catch(() => null)
      : null;
    const nearby = nearbyStoreNames(nearbyRaw);
    const places = nearbyStorePlaces(nearbyRaw);
    // ٤.٣: مدينته — بالتوازي مع القرايات اللي جاية.
    const cityRead = customerCity(sb, userId, country).catch(() => "");
    const [{ data: storedAll, error: storedErr }, { data: fuelRow }, { data: pausedRows, error: pausedErr }, { data: feeRows, error: feeErr }] = await Promise.all([
      sb.from("zad_deals")
        .select("store,item_name,price,price_before,currency,source_kind,source_url,valid_until,lat,lng,deal_kind,city")
        .eq("country", country).gt("expires_at", new Date(now).toISOString()).limit(300),
      sb.from("zad_fuel_prices").select("price,currency,found_at").eq("country", country).maybeSingle(),
      sb.rpc("zad_deal_paused_sources", { p_days: 14 }),
      sb.rpc("zad_delivery_fees_typical", { p_country: country }),
    ]);
    if (storedErr) console.warn("[taste_deal] zad_deals read failed:", storedErr.message);
    // فشل قراية البوابة = من غير إيقاف (العرض لسه بمصدره وتاريخه و«ممكن يكون خلص»).
    if (pausedErr) console.warn("[taste_deal] paused sources read failed:", pausedErr.message);
    const paused = new Set(((pausedRows ?? []) as Array<{ source_kind: string }>).map((r) => r.source_kind));
    const stored = withoutPausedSources(dealsForCity(storedAll as Array<StoredDealRow & { city?: string | null }> | null, await cityRead), paused);
    // النية الأول: عرض على حاجة قال إنه عايزها يغلب محله المعتاد على حاجة من القايمة.
    const pick = (raw: unknown): TasteDeal | null => {
      const wanted = wants.length ? pickDeal(raw, wants, favorites, skip, nearby, false, brands, stockable) : null;
      if (wanted) return { ...wanted, intent: wants.find((w) => offerMatchesNeed(w, wanted.item)) };
      return pickDeal(raw, items, favorites, skip, nearby, tight, brands, stockable);
    };
    // ٤.١٠: المشوار من نقطته (مقرّبة لكيلو) للمحل اللي ليه إحداثيات، بسعر بنزين بلده.
    // ٤.٧: عرض من غير إحداثيات بياخد أقرب فرع باسمه حوالين نقطته. ٤.١٠: «معندناش عربية» = مفيش مشوار بالعربية.
    const noCar = saysNoCar(saidOf(TRANSPORT_SCOPE));
    const tripOf = (r: StoredDealRow & { currency?: string | null }) =>
      noCar ? null : tripCost(point, withBranch(r, places, point), usableFuel(fuelRow as { price?: number; currency?: string; found_at?: string } | null, r.currency ?? null, now));
    // ٤.١٠: عرض في تطبيق توصيل بيتطرح منه رسومه المعتادة. فشل القراية = من غير رسوم، زي الأول.
    if (feeErr) console.warn("[taste_deal] delivery fees read failed:", feeErr.message);
    const deliveryFor = (r: StoredDealRow & { currency?: string | null }) =>
      deliveryOf(feeRows as Array<{ app_key?: string; fee?: number; currency?: string }> | null, r.store, r.currency ?? null);
    const storedRaw = storedDeals(stored as StoredDealRow[] | null, tripOf, deliveryFor);
    const fromStore = items.length ? pick(storedRaw) : null;
    if (fromStore) return fromStore;
    if (items.length) {
      const res = await dealSource.search({ items, location: countryNameAr(country), country }, userId);
      const live = pick((res as { deals?: unknown } | null)?.deals);
      if (live) return live;
    }
    // الاحتياج الأول دايماً؛ العرض الناري بس لما مفيش عرض على حاجة ناقصة، وبعده عرض أساسي لأي بيت.
    return pickFireDeal(storedRaw, boughtNames, favorites, skip, nearby, tight, brands) ??
      pickStapleDeal(storedRaw, favorites, skip, nearby, tight);
  } catch (e) {
    console.warn("[taste_deal] failed:", (e as Error)?.message);
    return null;
  }
}
