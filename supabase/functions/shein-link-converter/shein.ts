// روابط SHEIN للخليج (ZAD_PLAN ١٠، المالك ١١/١١) — الجزء اللي مالوش شبكة، عشان يتختبر.
//
// ليه مابنركّبش الرابط بنفسنا: الرابط الحقيقي اللي لوحة SHEIN بتطلّعه شكله
// https://onelink.shein.com/60/67x9gydalfpz?ismg_ol=… ومافيهوش لا رقم الأفلييت ولا كود الإحالة.
// الصفحة اللي بيفتحها بتشيل `ad_type=KOC&koc_id=4559428113` (اتقاس ١١/١١). يعني النسبة جوه رابط
// SHEIN نفسه، وأي باراميتر بنزوّده على رابط منتج عادي (`aff_id=`، `ref_code=`) مالوش أي أثر معروف:
// الرابط بيفتح عادي وماحدش بياخد عمولة، ومفيش حاجة بتقول كده. فالدالة دي **بتتأكد** بس:
// الرابط من اللوحة، والصفحة بتاعته شايلة رقمنا.

/** الهوست الوحيد اللي بنقبله: روابط لوحة SHEIN. */
export const ONELINK_HOST = "onelink.shein.com";

/** البلاد اللي عروض SHEIN بتروحلها (مصر على أمازون). */
export const GULF = ["SA", "AE"] as const;
export type Gulf = typeof GULF[number];

export type LinkCheck =
  | { ok: true; url: string }
  | { ok: false; reason: "not_https" | "not_a_dashboard_link" | "malformed" | "too_long" };

/**
 * رابط من لوحة SHEIN، نضيف. رابط منتج عادي من shein.com بيترفض بـ`not_a_dashboard_link`:
 * اللي عايز يضيفه يطلّع رابطه من اللوحة الأول.
 */
export function dashboardLink(raw: string): LinkCheck {
  const text = raw.trim();
  if (text.length > 500) return { ok: false, reason: "too_long" };
  let u: URL;
  try {
    u = new URL(text);
  } catch {
    return { ok: false, reason: "malformed" };
  }
  if (u.protocol !== "https:") return { ok: false, reason: "not_https" };
  if (u.hostname !== ONELINK_HOST || u.username || u.password || u.port) {
    return { ok: false, reason: "not_a_dashboard_link" };
  }
  if (!/^\/\d+\/[A-Za-z0-9]+\/?$/.test(u.pathname)) return { ok: false, reason: "malformed" };
  u.hash = "";
  return { ok: true, url: u.toString() };
}

/** الهوستات اللي ممكن نمشي وراها لو onelink حوّل (كلها بتاعة SHEIN). */
export function isSheinHost(host: string): boolean {
  return host === "shein.com" || host.endsWith(".shein.com");
}

/** رقم الأفلييت (`koc_id`) اللي صفحة الرابط شايلاه، أو null. */
export function kocIdIn(page: string): string | null {
  const m = page.replace(/&amp;/g, "&").match(/[?&]koc_id=(\d{4,20})(?=[&"'\s<]|$)/);
  return m ? m[1] : null;
}

export interface OfferInput {
  title: string;
  url: string;
  image_url?: string | null;
  raw_url?: string | null;
  coupon_code?: string | null;
  target_countries?: string[];
  category?: string;
  is_active?: boolean;
}

export interface OfferRow {
  network: "shein";
  title: string;
  affiliate_url: string;
  image_url: string | null;
  raw_url: string | null;
  coupon_code: string | null;
  target_countries: Gulf[];
  category: string;
  is_active: boolean;
}

function httpsOrNull(v: unknown): string | null | undefined {
  if (v == null || v === "") return null;
  if (typeof v !== "string" || v.length > 1000) return undefined;
  try {
    return new URL(v).protocol === "https:" ? v : undefined;
  } catch {
    return undefined;
  }
}

/**
 * العرض زي ما هيتخزن، أو سبب الرفض. `coupon_code` لكود خصم **للمشتري** بس: كود الإحالة بتاع
 * المالك (B8U6U) مش خصم، ومابيتعرضش على الكارت (المالك ١١/١١).
 */
export function offerRow(
  input: OfferInput,
): { ok: true; row: OfferRow } | { ok: false; reason: string } {
  const title = (input.title ?? "").trim();
  if (title.length < 1 || title.length > 120) return { ok: false, reason: "bad_title" };
  const link = dashboardLink(input.url ?? "");
  if (!link.ok) return { ok: false, reason: link.reason };
  const image = httpsOrNull(input.image_url);
  if (image === undefined) return { ok: false, reason: "bad_image_url" };
  const raw = httpsOrNull(input.raw_url);
  if (raw === undefined || (raw && !isSheinHost(new URL(raw).hostname))) {
    return { ok: false, reason: "bad_raw_url" };
  }
  const code = (input.coupon_code ?? "").trim().toUpperCase() || null;
  if (code && !/^[A-Z0-9-]{3,20}$/.test(code)) return { ok: false, reason: "bad_coupon_code" };
  const countries = [...new Set((input.target_countries ?? [...GULF]).map((c) => c.toUpperCase()))];
  if (countries.length === 0 || !countries.every((c): c is Gulf => (GULF as readonly string[]).includes(c))) {
    return { ok: false, reason: "bad_countries" };
  }
  const category = (input.category ?? "fashion_home").trim();
  if (!/^[a-z_]{3,30}$/.test(category)) return { ok: false, reason: "bad_category" };
  return {
    ok: true,
    row: {
      network: "shein",
      title,
      affiliate_url: link.url,
      image_url: image,
      raw_url: raw,
      coupon_code: code,
      target_countries: countries as Gulf[],
      category,
      is_active: input.is_active ?? true,
    },
  };
}
