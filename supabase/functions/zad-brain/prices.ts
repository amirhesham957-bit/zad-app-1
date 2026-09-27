// أدوات الأسعار في الشات — منطق نقي، النداءات في index.ts.
//
// ليه الملف ده (٢٠٢٦-٠٩-٢٧): أدوات الأسعار كانت بترجع كلام من غير أساس:
// - fetch_current_exchange_rate كانت بتقرا currency_rates، والجدول ده اتمسح في
//   20260905120000 (كان فاضي للأبد) — فكل سؤال صرف رجّع «مفيش بيانات». الأسعار الحقيقية
//   في zad_fx_rates (كود العملة → قيمتها بالدولار، بيحدّثها zad-fx-refresh-daily).
// - check_price_trend / get_nearby_deals كانوا بيحسبوا متوسط على price_index كله —
//   بلاغات جنيه وريال مع بعض — وبيكتبوا «جنيه» ثابت لأي عميل.
// الدوال هنا بتاخد الصفوف وترجّع النص، عشان كل قاعدة تتختبر من غير شبكة.

/** صف من zad_fx_rates. */
export interface FxRow {
  code: string;
  usd_rate: number | string;
  updated_at?: string | null;
}

/** سعر تحويل وحدة من [from] لـ[to] من جدول قيمة كل عملة بالدولار، أو null لو عملة ناقصة. */
export function crossRate(
  rows: FxRow[] | null | undefined,
  from: string,
  to: string,
): { rate: number; updatedAt: string | null } | null {
  const f = from.trim().toUpperCase();
  const t = to.trim().toUpperCase();
  const byCode = new Map((rows ?? []).map((r) => [String(r.code).toUpperCase(), r]));
  if (f === t && byCode.has(f)) return { rate: 1, updatedAt: byCode.get(f)!.updated_at ?? null };
  const a = byCode.get(f);
  const b = byCode.get(t);
  const ua = Number(a?.usd_rate);
  const ub = Number(b?.usd_rate);
  if (!a || !b || !(ua > 0) || !(ub > 0)) return null;
  const stamps = [a.updated_at, b.updated_at].filter((s): s is string => !!s).sort();
  return { rate: ua / ub, updatedAt: stamps[0] ?? null };
}

/** نص رد سعر الصرف — بتاريخ آخر تحديث الحقيقي، مش «محدّث آخر ساعة». */
export function describeRate(from: string, to: string, r: ReturnType<typeof crossRate>): string {
  const f = from.trim().toUpperCase();
  const t = to.trim().toUpperCase();
  if (!r) return `مفيش سعر صرف مسجّل لـ${f} أو ${t} عندي — قول للعميل كده، ماتخمّنش رقم.`;
  const digits = r.rate >= 10 ? 2 : 4;
  const when = r.updatedAt ? ` (آخر تحديث ${r.updatedAt.slice(0, 10)}، تقريبي)` : " (تقريبي)";
  return `1 ${f} ≈ ${r.rate.toFixed(digits)} ${t}${when}`;
}

/** صف سعر من price_index. */
export interface PriceRow {
  price: number | string;
  timestamp?: string | null;
  item_name?: string | null;
  location?: string | null;
  store_name?: string | null;
}

const positive = (rows: PriceRow[] | null | undefined) =>
  (rows ?? []).filter((r) => Number(r.price) > 0);

/**
 * اتجاه سعر صنف من بلاغات الناس بعملة العميل. [rows] الأحدث الأول. أقل من بلاغين = مفيش
 * اتجاه يتحسب، وبيتقال كده بدل نسبة من نقطة واحدة.
 */
export function summarizePriceTrend(
  rows: PriceRow[] | null | undefined,
  itemName: string,
  days: number,
  currency: string,
): string {
  const p = positive(rows);
  if (p.length === 0) {
    return `مفيش بلاغات أسعار لـ«${itemName}» بعملتك آخر ${days} يوم. قول للعميل كده، واعرض عليه يسجّل سعر من صفحة الأسعار (app_command screen=prices).`;
  }
  const values = p.map((r) => Number(r.price));
  const current = values[0];
  const avg = values.reduce((a, b) => a + b, 0) / values.length;
  const cur = currency ? ` ${currency}` : "";
  if (values.length < 2) {
    return `📊 ${itemName}: بلاغ واحد بس آخر ${days} يوم — ${current.toFixed(2)}${cur}. مفيش بيانات كفاية لاتجاه.`;
  }
  const oldest = values[values.length - 1];
  const change = ((current - oldest) / oldest) * 100;
  const trend = Math.abs(change) < 2 ? "مستقر" : change > 0 ? "صاعد" : "هابط";
  return [
    `📊 ${itemName} (${values.length} بلاغ من الناس، آخر ${days} يوم):`,
    `• آخر سعر: ${current.toFixed(2)}${cur}`,
    `• المتوسط: ${avg.toFixed(2)}${cur}`,
    `• التغيير من أقدم بلاغ: ${change > 0 ? "+" : ""}${change.toFixed(1)}% (${trend})`,
  ].join("\n");
}

/** أرخص البلاغات في فئة، مقارنة بمتوسط الفئة بعملة العميل. */
export function rankDeals(
  rows: PriceRow[] | null | undefined,
  category: string,
  savingsThreshold: number,
  currency: string,
): string {
  const p = positive(rows);
  if (p.length < 2) {
    return `مفيش بلاغات أسعار كفاية في «${category}» بعملتك آخر أسبوع للمقارنة. قول للعميل كده، ماتخترعش محلات.`;
  }
  const avg = p.reduce((s, r) => s + Number(r.price), 0) / p.length;
  const deals = p
    .map((r) => ({ ...r, savings: ((avg - Number(r.price)) / avg) * 100 }))
    .filter((r) => r.savings >= savingsThreshold)
    .sort((a, b) => b.savings - a.savings)
    .slice(0, 5);
  if (deals.length === 0) {
    return `مفيش بلاغ في «${category}» أرخص من المتوسط بأكتر من ${savingsThreshold}%.`;
  }
  const cur = currency ? ` ${currency}` : "";
  return [
    `🏪 أرخص بلاغات الناس في «${category}» (آخر أسبوع):`,
    ...deals.map((d) => {
      const where = [d.store_name, d.location].filter((s) => s && String(s).trim()).join("، ") || "مكان مش محدد";
      return `• ${where}: ${d.item_name ?? ""} = ${Number(d.price).toFixed(2)}${cur} (أقل من المتوسط بـ${d.savings.toFixed(0)}%)`;
    }),
  ].join("\n");
}
