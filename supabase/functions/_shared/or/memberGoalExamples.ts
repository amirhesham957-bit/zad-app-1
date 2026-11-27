/**
 * م٧.٨: أمثلة الأفراد كدوال صافية (من غير I/O ولا جداول جديدة). كل دالة بتاخد بيانات الفرد نفسه بس؛ أي بيانات
 * مش موجودة في الداتابيز النهاردة (قيم تغذية الأصناف، مصروف الفرد المنفصل) المتصل بيمررها، والناقص متسجل في
 * ZAD_OR_PLAN. خصوصية م٧.٩: `ownedOrShared` هو الفلتر المطلوب قبل أي حساب على هدف/صرف فرد.
 */

export interface MemberOwned { member_id?: string | null }

/** بنود الفرد نفسه + اللي هو شاركه صراحة (sharedIds = ids البنود المشاركة). غيرهم ماينفعش يدخل أي حساب. */
export function ownedOrShared<T extends MemberOwned & { id?: string }>(
  rows: readonly T[], viewerMemberId: string, sharedIds: ReadonlySet<string> = new Set(),
): T[] {
  return rows.filter((r) => r.member_id === viewerMemberId || (r.id !== undefined && sharedIds.has(r.id)));
}

// ---- الأخ (جيم): بروتين من مخزن البيت ----
export interface PantryItem {
  name: string;
  quantity: number;
  unit?: string;
  /** جرام بروتين في الوحدة الواحدة؛ undefined = مش معروف. */
  proteinPerUnitG?: number;
}
export interface ProteinPlan { coveredG: number; targetG: number; shortfallG: number; usable: string[]; unknownProtein: string[] }

/** بروتين المخزن الموجود vs هدف اليوم. اللي قيمته مش معروفة بتتحط في unknownProtein (مابنخمّنش). */
export function proteinFromPantry(items: readonly PantryItem[], targetG: number): ProteinPlan {
  let covered = 0;
  const usable: string[] = [], unknown: string[] = [];
  for (const it of items) {
    if (!(it.quantity > 0)) continue;
    if (it.proteinPerUnitG === undefined || !(it.proteinPerUnitG >= 0)) { unknown.push(it.name); continue; }
    if (it.proteinPerUnitG > 0) { covered += it.quantity * it.proteinPerUnitG; usable.push(it.name); }
  }
  const target = Math.max(0, targetG);
  return { coveredG: Math.round(covered), targetG: target, shortfallG: Math.max(0, Math.round(target - covered)), usable, unknownProtein: unknown };
}

// ---- المكمّل: تاريخ النفاد ----
export interface RunoutInfo { daysLeft: number; runsOutOn: string; reorderBy: string }

/** remaining/daily = أيام باقية. reorderBy = قبل النفاد بـleadDays (افتراضي ٣). null لو مفيش استهلاك يومي معروف. */
export function supplementRunout(remaining: number, dailyUse: number, todayIso: string, leadDays = 3): RunoutInfo | null {
  if (!(dailyUse > 0) || !(remaining >= 0)) return null;
  const today = Date.parse(`${todayIso.slice(0, 10)}T00:00:00Z`);
  if (!Number.isFinite(today)) return null;
  const daysLeft = Math.floor(remaining / dailyUse);
  const day = (n: number) => new Date(today + n * 86_400_000).toISOString().slice(0, 10);
  return { daysLeft, runsOutOn: day(daysLeft), reorderBy: day(Math.max(0, daysLeft - leadDays)) };
}

// ---- مواعيد الجيم من zad_appointments ----
export interface ApptRow { title: string; starts_at: string; status?: string; for_person?: string | null }
const GYM_RE = /(جيم|gym|تمرين|كمال اجسام|كمال أجسام|workout)/i;

/** عدد جلسات الجيم القادمة في نافذة [fromIso, fromIso+days). الملغي والفايت مش بيتحسب. */
export function gymSessionsInWindow(appts: readonly ApptRow[], fromIso: string, days = 7): { count: number; dates: string[] } {
  const from = Date.parse(fromIso), to = from + days * 86_400_000;
  const hits = appts.filter((a) => {
    const t = Date.parse(a.starts_at);
    return GYM_RE.test(a.title) && Number.isFinite(t) && t >= from && t < to && (a.status === undefined || a.status === "upcoming");
  }).map((a) => a.starts_at.slice(0, 10)).sort();
  return { count: hits.length, dates: hits };
}

// ---- البنت: هدف ميزانية (ميكب/بيجامة) في حدود مصروفها، بذوقها ----
export interface TasteSignal { text: string; kind: "asked" | "bought" }
export interface Candidate { name: string; price: number; category?: string }

/** ذوق = عدد مرات ظهور كلمات الصنف في اللي سألت عنه (١) واشترته (٢). */
export function tasteScore(c: Candidate, signals: readonly TasteSignal[]): number {
  const words = `${c.name} ${c.category ?? ""}`.toLowerCase().split(/[^\p{L}\p{N}]+/u).filter((w) => w.length >= 3);
  let s = 0;
  for (const sig of signals) {
    const t = sig.text.toLowerCase();
    if (words.some((w) => t.includes(w))) s += sig.kind === "bought" ? 2 : 1;
  }
  return s;
}

export interface BudgetPicks { picks: Candidate[]; spent: number; left: number; skippedOverBudget: string[] }

/** اختيار طمّاع: الأعلى ذوقاً الأول (وبعدها الأرخص) طول ما يدخل في الباقي من المصروف. ماتتخطاش الحدود أبداً. */
export function pickWithinAllowance(cands: readonly Candidate[], allowanceLeft: number, signals: readonly TasteSignal[]): BudgetPicks {
  const ranked = cands.filter((c) => c.price > 0)
    .map((c) => ({ c, t: tasteScore(c, signals) }))
    .sort((a, b) => b.t - a.t || a.c.price - b.c.price);
  const picks: Candidate[] = [], skipped: string[] = [];
  const start = Math.max(0, allowanceLeft);
  let left = start;
  for (const { c } of ranked) {
    if (c.price <= left) { picks.push(c); left -= c.price; } else skipped.push(c.name);
  }
  return { picks, spent: start - left, left, skippedOverBudget: skipped };
}
