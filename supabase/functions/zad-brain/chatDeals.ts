// chatDeals.ts — «هاتلي عروض كيتا»، «فيه عروض إيه؟»، «عروض على الزيت» في الشات (طلب المالك ٧/١١).
//
// قبل كده الوكيل مكانش معاه أداة بتقرا العروض المتخزنة غير where_to_buy (صنف واحد بس)، فطلب «دوّرلي على عروض» كان
// بيرجع نصيحة («ميزانيتنا فاضل فيها ٧٠٠… انزل بص بنفسك») بدل العروض. find_deals بيقرا zad_deals و zad_deal_codes
// في بلد العميل (أو بلد السفر)، من غير المصادر الموقوفة بالبلاغات، وبيرجّع العروض بأسعارها ولينكاتها. الميزانية مش شرط:
// العميل ممكن يخطط للشهر الجاي أو عنده فلوس تانية.

import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { codeStoreKey } from "./dealCodes.ts";
import { isGroceryTerm } from "../_shared/groceryLexicon.ts";
import { offerMatchesNeed } from "./productIdentity.ts";
import { itemKey } from "./shared.ts";
import { customerCity, dealCountry, dealsForCity } from "./tasteDeals.ts";

export const CHAT_DEALS_MAX = 8;
export const CHAT_CODES_MAX = 4;
export const CHAT_PICKS_MAX = 5;
export const CHAT_SHEIN_MAX = 4;

/**
 * عرض SHEIN للخليج (zad_affiliate_offers، المالك ١١/١١). الرابط رابط لوحة SHEIN اللي shein-link-converter اتأكد إن صفحته
 * شايلة koc_id بتاعنا قبل ما يتحفظ؛ النسبة جواه، فبيتبعت للعميل زي ما هو بالحرف. كود إحالة المالك مش هنا ومابيتقالش للعميل.
 */
export interface SheinOfferRow {
  title: string;
  affiliate_url: string;
  coupon_code: string | null;
  category: string | null;
}

/** البلاد اللي SHEIN بتروحلها؛ مصر على أمازون. */
export const SHEIN_COUNTRIES = new Set(["SA", "AE"]);

const ONELINK = /^https:\/\/onelink\.shein\.com\/\d+\/[A-Za-z0-9]+\/?(\?\S*)?$/;

/** طلب لبس أو أطفال أو بيت وديكور — اللي SHEIN بتبيعه، مش بقالة. */
const SHEIN_TOPIC =
  /شي ?ان|shein|لبس|ملابس|هدوم|فستان|فساتين|بلوز|قميص|بنطلون|جيبه|عبايه|جزمه|شنط|شنطه|اكسسوار|اطفال|عيال|بيبي|مواليد|ديكور|مفارش|ستاير|سجاد|مخدات|مطبخ|تنظيم|fashion|dress|kids|decor/;

/**
 * عروض SHEIN اللي تطابق الطلب: محل اتطلب غير SHEIN = مفيش؛ صنف بقالة = مفيش؛ صنف لبس/بيت = اللي عنوانه فيه الصنف الأول
 * وبعدهم الأحدث؛ من غير محل ولا صنف = الأحدث. رابط مش من لوحة SHEIN بيتشال هنا كمان. نقي.
 */
export function matchSheinOffers(rows: readonly SheinOfferRow[], store: string, item: string, max = CHAT_SHEIN_MAX): SheinOfferRow[] {
  const wantStore = itemKey(store);
  if (wantStore && !/شي ?ان|shein/.test(wantStore)) return [];
  const want = itemKey(item);
  if (want && !wantStore && !SHEIN_TOPIC.test(want)) return [];
  const valid = rows.filter((r) => r.title?.trim() && ONELINK.test(String(r.affiliate_url ?? "").trim()));
  // كلمة بكلمة: «لبس أطفال» يلاقي «طقم ولادي أطفال»؛ الكلمات العامة (لبس، عروض) مابتعدّش.
  const words = want.split(" ").filter((w) => w.length >= 3 && !/^(لبس|ملابس|هدوم|عروض|عرض|حاجه|حاجات|من|شي|ان|shein)$/.test(w));
  const score = (r: SheinOfferRow) => words.filter((w) => itemKey(r.title).includes(w)).length;
  return valid
    .map((r, i) => ({ r, i, s: score(r) }))
    .sort((a, b) => b.s - a.s || a.i - b.i)
    .slice(0, max)
    .map((x) => x.r);
}

/** ترشيح من تيك توك أو إنستجرام من غير سعر (zad_social_picks، طلب المالك ١٠/١١). */
export interface ChatPickRow {
  platform: string;
  kind: string;
  store: string | null;
  title: string;
  summary: string;
  discount_percent: number | string | null;
  likes: number | string | null;
  source_url: string;
}

const PICK_KIND_WORD: Record<string, string> = {
  offer: "عرض", recipe: "وصفة", idea: "فكرة", restaurant: "مطعم", supermarket: "سوبرماركت", delivery: "توصيل",
};

/**
 * الترشيحات اللي تطابق الطلب: محل اتطلب = بتوعه بس؛ صنف اتطلب = اللي عنوانه أو ملخصه فيه الصنف؛ من غير الاتنين = الأحدث.
 * الأكتر لايكات الأول في نفس الدرجة. نقي.
 */
export function matchChatPicks(rows: ChatPickRow[], store: string, item: string, max = CHAT_PICKS_MAX): ChatPickRow[] {
  const want = itemKey(item);
  const out = rows.filter((r) => {
    if (store && !(r.store && sameStore(r.store, store))) return false;
    if (want.length >= 2 && !itemKey(`${r.title} ${r.summary}`).includes(want)) return false;
    return true;
  });
  return out.sort((a, b) => (Number(b.likes) || 0) - (Number(a.likes) || 0)).slice(0, max);
}

export interface ChatDealRow {
  store: string;
  item_name: string;
  price: number | string;
  price_before?: number | string | null;
  currency?: string | null;
  source_kind: string;
  source_url?: string | null;
  valid_until?: string | null;
  city?: string | null;
}

export interface ChatCodeRow {
  store: string;
  store_key: string;
  code: string;
  discount_percent: number | string | null;
  discount_amount: number | string | null;
  currency: string | null;
  min_order: number | string | null;
  valid_until: string | null;
  source_url: string;
}

const sameStore = (a: string, b: string) => {
  const ka = codeStoreKey(a);
  const kb = codeStoreKey(b);
  return ka.length >= 2 && kb.length >= 2 && (ka === kb || ka.includes(kb) || kb.includes(ka));
};

const saving = (r: ChatDealRow): number | null => {
  const price = Number(r.price);
  const before = Number(r.price_before);
  return Number.isFinite(before) && before > price && price > 0 ? Math.round((before - price) / before * 100) : null;
};

const https = (u: unknown) => typeof u === "string" && /^https:\/\/\S{4,500}$/.test(u.trim()) ? u.trim() : null;

/**
 * العروض والأكواد اللي تطابق الطلب: [store] (اسم المحل أو التطبيق) و/أو [item] (الصنف). من غير الاتنين = أقوى الخصومات
 * في البلد. الخصم الأكبر الأول، الصنف مرة، والمحل مرتين بالكتير لو مش هو اللي اتطلب.
 */
export function matchChatDeals(
  deals: readonly ChatDealRow[],
  codes: readonly ChatCodeRow[],
  store: string,
  item: string,
): { deals: ChatDealRow[]; codes: ChatCodeRow[] } {
  const wantStore = store.trim();
  // «عروض المقاضي» = العروض كلها (٤.٢٥).
  const wantItem = isGroceryTerm(item) ? "" : item.trim();
  const picked = deals
    .filter((d) => d.store && d.item_name && Number(d.price) > 0)
    .filter((d) => !wantStore || sameStore(wantStore, d.store))
    .filter((d) => !wantItem || offerMatchesNeed(wantItem, d.item_name))
    .map((d, i) => ({ d, i, s: saving(d) ?? 0 }))
    .sort((a, b) => b.s - a.s || a.i - b.i);
  const out: ChatDealRow[] = [];
  const items = new Set<string>();
  const perStore = new Map<string, number>();
  for (const { d } of picked) {
    const ik = `${itemKey(d.item_name)}|${codeStoreKey(d.store)}`;
    const sk = codeStoreKey(d.store);
    if (items.has(ik) || (!wantStore && (perStore.get(sk) ?? 0) >= 2)) continue;
    items.add(ik);
    perStore.set(sk, (perStore.get(sk) ?? 0) + 1);
    out.push(d);
    if (out.length >= CHAT_DEALS_MAX) break;
  }
  const codeOut = codes
    .filter((c) => (!wantStore || sameStore(wantStore, c.store)) && (!wantItem || wantStore || out.some((d) => sameStore(d.store, c.store))))
    .slice(0, CHAT_CODES_MAX);
  return { deals: out, codes: codeOut };
}

/** نتيجة الأداة للموديل: أرقام ولينكات جاهزة، والتعليمات اللي تمنع الوصاية. */
export function describeChatDeals(
  found: { deals: ChatDealRow[]; codes: ChatCodeRow[]; picks?: ChatPickRow[]; shein?: SheinOfferRow[] }, store: string, item: string,
): string {
  const what = [item && `«${item}»`, store && `في ${store}`].filter(Boolean).join(" ") || "في بلده";
  const picks = found.picks ?? [];
  const shein = found.shein ?? [];
  if (!found.deals.length && !found.codes.length && !picks.length && !shein.length) {
    return `مفيش عروض متخزنة شغالة ${what} دلوقتي. قول كده للعميل بوضوح، واعرض تدوّر على النت (web_search) لو عايز.`;
  }
  const lines = found.deals.map((d) => {
    const s = saving(d);
    const before = s !== null ? ` بدل ${Number(d.price_before)} (خصم ${s}٪)` : "";
    const until = d.valid_until ? ` لحد ${String(d.valid_until).slice(0, 10)}` : "";
    const link = https(d.source_url);
    return `- ${d.item_name} — ${d.store}: ${Number(d.price)} ${d.currency ?? ""}${before}${until}${link ? ` — ${link}` : ""}`;
  });
  const codeLines = found.codes.map((c) => {
    const off = Number(c.discount_percent) > 0 ? `${Number(c.discount_percent)}٪` : Number(c.discount_amount) > 0 ? `${Number(c.discount_amount)} ${c.currency ?? ""}` : "خصم";
    const min = Number(c.min_order) > 0 ? ` على طلب ${Number(c.min_order)} أو أكتر` : "";
    const until = c.valid_until ? ` لحد ${String(c.valid_until).slice(0, 10)}` : "";
    const link = https(c.source_url);
    return `- كود ${c.code} — ${c.store}: ${off}${min}${until}${link ? ` — ${link}` : ""}`;
  });
  const pickLines = picks.map((p) => {
    const where = p.platform === "instagram" ? "إنستجرام" : p.platform === "youtube" ? "يوتيوب" : "تيك توك";
    const off = Number(p.discount_percent) > 0 ? ` (خصم ${Number(p.discount_percent)}٪)` : "";
    const summary = p.summary ? ` — ${p.summary}` : "";
    return `- ${PICK_KIND_WORD[p.kind] ?? "ترشيح"} على ${where}: ${p.title}${p.store ? ` (${p.store})` : ""}${off}${summary} — ${p.source_url}`;
  });
  const sheinLines = shein.map((o) => {
    const code = o.coupon_code ? ` — كود خصم للمشتري: ${o.coupon_code}` : "";
    return `- ${o.title} — SHEIN${code} — ${o.affiliate_url.trim()}`;
  });
  return [
    ...(lines.length ? [`العروض الشغالة ${what} (من صفحات المحلات وفيديوهاتهم، ممكن تكون خلصت):`, ...lines] : []),
    ...(codeLines.length ? ["أكواد خصم:", ...codeLines] : []),
    ...(pickLines.length
      ? ["ترشيحات حديثة من تيك توك وإنستجرام (من غير أسعار مكتوبة؛ اعرضها بلينكاتها زي ما هي وقول إن التفاصيل في الفيديو):", ...pickLines]
      : []),
    ...(sheinLines.length
      ? [
        "اختيارات من SHEIN (لبس وبيت، بتوصل السعودية والإمارات؛ من غير أسعار مكتوبة — السعر على الصفحة):",
        ...sheinLines,
        "لينكات SHEIN دي لينكات أفلييت: انسخها بالحرف زي ما هي، ماتختصرهاش ولا تضيف عليها ولا تشيل منها حاجة. " +
        "زاد بياخد عمولة صغيرة من الشراء منها من غير ما السعر يزيد على العميل — قول كده في سطر لو عرضتها.",
      ]
      : []),
    "اعرضهم للعميل الأول، بأسعارهم ولينكاتهم زي ما هم. الميزانية مش سبب تحجب أو تأجّل بيه العروض؛ لو عندك ملاحظة فلوس فسطر واحد في الآخر.",
  ].join("\n");
}

/** يقرا عروض وأكواد بلد العميل ويرجّع النص للموديل. */
export async function findChatDeals(sb: SupabaseClient, userId: string, store: string, item: string, now = Date.now()): Promise<string> {
  const { data: me } = await sb.from("zad_users").select("country,travel_country,travel_since").eq("id", userId).maybeSingle();
  const country = dealCountry(me as { country?: string | null; travel_country?: string | null; travel_since?: string | null } | null, now);
  if (!/^[A-Z]{2}$/.test(country)) return "بلد العميل مش معروف، فمقدرش أجيب عروض. اسأله هو في أنهي بلد.";
  const [{ data: deals, error }, { data: codes }, { data: paused }, city] = await Promise.all([
    sb.from("zad_deals").select("store,item_name,price,price_before,currency,source_kind,source_url,valid_until,city")
      .eq("country", country).gt("expires_at", new Date(now).toISOString()).order("found_at", { ascending: false }).limit(400),
    sb.from("zad_deal_codes").select("store,store_key,code,discount_percent,discount_amount,currency,min_order,valid_until,source_url")
      .eq("country", country).gt("expires_at", new Date(now).toISOString()).order("found_at", { ascending: false }).limit(100),
    sb.rpc("zad_deal_paused_sources", { p_days: 14 }),
    customerCity(sb, userId, country).catch(() => ""),
  ]);
  const { data: picks } = await sb.from("zad_social_picks")
    .select("platform,kind,store,title,summary,discount_percent,likes,source_url")
    .eq("country", country).gt("expires_at", new Date(now).toISOString()).order("found_at", { ascending: false }).limit(80)
    .then((r) => r, () => ({ data: null }));
  if (error) return "مقدرتش أقرا العروض دلوقتي — قول للعميل كده بصراحة.";
  const pausedKinds = new Set(((paused ?? []) as Array<{ source_kind: string }>).map((r) => r.source_kind));
  const rows = dealsForCity((deals ?? []) as ChatDealRow[], city).filter((d) => !pausedKinds.has(d.source_kind));
  const found = matchChatDeals(rows, (codes ?? []) as ChatCodeRow[], store, item);
  // SHEIN للخليج بس (المالك ١١/١١): السعودية والإمارات؛ مصر على أمازون.
  const { data: shein } = SHEIN_COUNTRIES.has(country)
    ? await sb.from("zad_affiliate_offers").select("title,affiliate_url,coupon_code,category")
      .eq("is_active", true).contains("target_countries", [country]).order("created_at", { ascending: false }).limit(60)
      .then((r) => r, () => ({ data: null }))
    : { data: null };
  return describeChatDeals({
    ...found,
    picks: matchChatPicks((picks ?? []) as ChatPickRow[], store, item),
    shein: matchSheinOffers((shein ?? []) as SheinOfferRow[], store, item),
  }, store, item);
}
