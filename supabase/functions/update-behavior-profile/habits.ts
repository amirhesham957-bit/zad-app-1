// habits.ts — محلات البيت ومواعيد شراه ودورة كل صنف (ZAD_PLAN المرحلة ٣، الملف السلوكي التراكمي، الشريحة ٤).
//
// طلب المالك ٦/١١: «يتعلم المحلات المفضلة، ومتوسط الصرف الحقيقي، ومواعيد الشرا»، ويستخدمه العقل والبوت، ويظهر
// للعميل في صفحة «نمط استهلاكك». كل ده بيتحسب بالليل من المعاملات والمخزن — من غير موديل.
//
// الوقت بتوقيت سوق الحساب (zad_market_timezone)، مش UTC: الكود القديم كان بيحسب يوم الأسبوع بـgetDay() على UTC، فشرا
// الساعة ١ بالليل في الرياض بيتحسب اليوم اللي قبله.

import { cycleDays, priorCycleDays, restockKey, restockVerdict } from "../_shared/restockCycle.ts";

const DAY_MS = 86_400_000;

export interface HabitTxn {
  amount: number | string | null;
  merchant_name: string | null;
  category: string | null;
  created_at: string | null;
  is_expense: boolean | null;
}

export interface FavoriteStore {
  store: string;
  /** أيام مختلفة اتصرف فيها هنا (آخر ٩٠ يوم). */
  visits: number;
  total: number;
  /** نصيبه من صرف المحلات المعروفة، ٠–١٠٠. */
  share: number;
  last_at: string;
}

/** اسم تاجر مش محل: باكدج أندرويد، أو رقم/كارت. */
const NOT_A_STORE = /^(com|org|net)\.|^\*+\d*$|^\d+$/i;

const storeName = (s: string) => s.replace(/\s+/g, " ").trim().slice(0, 60);

export function favoriteStores(txns: readonly HabitTxn[], tz: string, limit = 6): FavoriteStore[] {
  const by = new Map<string, { store: string; days: Set<string>; total: number; last: number }>();
  let all = 0;
  for (const t of txns) {
    if (!t.is_expense || !t.merchant_name || !t.created_at) continue;
    const name = storeName(t.merchant_name);
    const amount = Number(t.amount);
    const at = Date.parse(t.created_at);
    if (name.length < 2 || NOT_A_STORE.test(name) || !(amount > 0) || !Number.isFinite(at)) continue;
    const key = restockKey(name);
    const e = by.get(key) ?? { store: name, days: new Set<string>(), total: 0, last: 0 };
    e.days.add(localDate(at, tz));
    e.total += amount;
    e.last = Math.max(e.last, at);
    by.set(key, e);
    all += amount;
  }
  return [...by.values()]
    .sort((a, b) => b.days.size - a.days.size || b.total - a.total)
    .slice(0, limit)
    .map((e) => ({
      store: e.store, visits: e.days.size, total: Math.round(e.total * 100) / 100,
      share: all > 0 ? Math.round((e.total / all) * 100) : 0, last_at: new Date(e.last).toISOString(),
    }));
}

export type DayPart = "morning" | "noon" | "evening" | "night";

export interface ShoppingRhythm {
  /** أيام الأسبوع بالترتيب ٠=الأحد، عدد أيام الشرا في كل يوم. */
  by_weekday: number[];
  by_part: Record<DayPart, number>;
  /** اليوم والفترة الأكتر — null لو أقل من ٤ أيام شرا (مفيش نمط لسه). */
  top_weekday: number | null;
  top_part: DayPart | null;
  /** المسافة المعتادة بين مشاوير الشرا بالأيام (الوسيط) — null لو أقل من ٣ مشاوير. */
  typical_gap_days: number | null;
  shopping_days: number;
}

const GROCERY = /بقال|سوبر|ماركت|هايبر|خضار|فاكه|لحوم|البان|مخبز|grocery|supermarket/i;

/** مشاوير الشرا: مصروف في فئة أكل/بقالة، أو في محل من المحلات المفضلة لو مفيش فئة. */
export function shoppingRhythm(txns: readonly HabitTxn[], tz: string): ShoppingRhythm {
  const days = new Map<string, { weekday: number; parts: DayPart[] }>();
  for (const t of txns) {
    if (!t.is_expense || !t.created_at || !(Number(t.amount) > 0)) continue;
    if (!GROCERY.test(`${t.category ?? ""} ${t.merchant_name ?? ""}`)) continue;
    const at = Date.parse(t.created_at);
    if (!Number.isFinite(at)) continue;
    const { date, weekday, hour } = localParts(at, tz);
    const e = days.get(date) ?? { weekday, parts: [] };
    e.parts.push(partOf(hour));
    days.set(date, e);
  }
  const byWeekday = [0, 0, 0, 0, 0, 0, 0];
  const byPart: Record<DayPart, number> = { morning: 0, noon: 0, evening: 0, night: 0 };
  for (const d of days.values()) {
    byWeekday[d.weekday]++;
    for (const p of new Set(d.parts)) byPart[p]++;
  }
  const n = days.size;
  const sorted = [...days.keys()].sort();
  const gaps: number[] = [];
  for (let i = 1; i < sorted.length; i++) gaps.push((Date.parse(sorted[i]) - Date.parse(sorted[i - 1])) / DAY_MS);
  const g = [...gaps].sort((a, b) => a - b);
  return {
    by_weekday: byWeekday,
    by_part: byPart,
    top_weekday: n >= 4 ? byWeekday.indexOf(Math.max(...byWeekday)) : null,
    top_part: n >= 4 ? (Object.entries(byPart).sort((a, b) => b[1] - a[1])[0][0] as DayPart) : null,
    typical_gap_days: g.length >= 2 ? Math.round(g.length % 2 ? g[(g.length - 1) / 2] : (g[g.length / 2 - 1] + g[g.length / 2]) / 2) : null,
    shopping_days: n,
  };
}

export interface ItemCycle {
  item: string;
  cycle_days: number;
  /** true = من مرات شرا البيت نفسه، false = البداية المعقولة لنوع الصنف. */
  learned: boolean;
  /** العميل صحّح الدورة بنفسه. */
  set_by_customer: boolean;
  last_bought: string | null;
  /** فاضل كام يوم على الشرا الجاي (سالب = عدّى). null = مفيش تاريخ شرا. */
  due_in_days: number | null;
  due: boolean;
}

export interface CycleItemRow {
  item_name: string | null;
  quantity: number | string | null;
  low_stock_threshold?: number | string | null;
  category?: string | null;
  restock_mode?: string | null;
  restock_cycle_days?: number | null;
  created_at?: string | null;
}

/** دورة كل صنف في المخزن، الأقرب للشرا الأول. شنط الكاشير والأصناف «على فترات» برّه. */
export function itemCycles(
  pantry: readonly CycleItemRow[],
  purchaseDays: ReadonlyMap<string, string[]>,
  now = Date.now(),
  limit = 40,
): ItemCycle[] {
  const out: ItemCycle[] = [];
  const seen = new Set<string>();
  for (const row of pantry) {
    const name = String(row.item_name ?? "").trim();
    const key = restockKey(name);
    if (!key || seen.has(key)) continue;
    seen.add(key);
    const bought = [...(purchaseDays.get(key) ?? []), ...(row.created_at ? [row.created_at] : [])];
    const v = restockVerdict({
      name, category: row.category, quantity: row.quantity, threshold: row.low_stock_threshold,
      restockMode: row.restock_mode, purchaseDays: bought, cycleOverride: row.restock_cycle_days,
    }, now);
    if (v.cycleDays === null || v.reason === "occasional") continue;
    const prior = priorCycleDays(name, row.category);
    const distinctDays = new Set(bought.map((d) => d.slice(0, 10))).size;
    const last = bought.reduce((m, d) => Math.max(m, Date.parse(d) || 0), 0);
    out.push({
      item: name,
      cycle_days: v.cycleDays,
      learned: distinctDays >= 2 && cycleDays(prior, bought) !== prior,
      set_by_customer: row.restock_cycle_days != null,
      last_bought: last > 0 ? new Date(last).toISOString() : null,
      due_in_days: v.daysSinceBought === null ? null : v.cycleDays - v.daysSinceBought,
      due: v.due,
    });
  }
  return out
    .sort((a, b) => (a.due_in_days ?? 9_999) - (b.due_in_days ?? 9_999))
    .slice(0, limit);
}

/** YYYY-MM-DD بتوقيت [tz]. */
export function localDate(ms: number, tz: string): string {
  return localParts(ms, tz).date;
}

function localParts(ms: number, tz: string): { date: string; weekday: number; hour: number } {
  let parts: Intl.DateTimeFormatPart[];
  try {
    parts = new Intl.DateTimeFormat("en-US", {
      timeZone: tz, year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", hourCycle: "h23", weekday: "short",
    }).formatToParts(new Date(ms));
  } catch {
    return localParts(ms, "UTC");
  }
  const get = (t: string) => parts.find((p) => p.type === t)?.value ?? "";
  const weekday = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"].indexOf(get("weekday"));
  return { date: `${get("year")}-${get("month")}-${get("day")}`, weekday: Math.max(0, weekday), hour: Number(get("hour")) || 0 };
}

function partOf(hour: number): DayPart {
  if (hour >= 5 && hour < 12) return "morning";
  if (hour >= 12 && hour < 17) return "noon";
  if (hour >= 17 && hour < 22) return "evening";
  return "night";
}
