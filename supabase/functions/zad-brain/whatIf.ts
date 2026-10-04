// whatIf.ts — «لو اشتريت…» (ZAD_LIVING_BRAIN.md الشريحة ٨).
//
// المالك (٢٠٢٦-١٠-٠٣): قبل قرار شراء، العقل يقول «لو اشتريت ده النهارده، مصاريف المدارس بعد ١٢ يوم
// هتبقى ضيقة — نأجله؟». `forward_ledger` كان بيحسب الرصيد يوم بيوم من غير الشراء ده؛ الملف ده بيعيد
// بناء الأيام نفسها من نفس النتيجة ويطرح المبلغ من يوم الشراء لقدام — حساب حتمي، صفر كوتة، والموديل
// بيصيغ بس. من غير مايجريشن: الرصيد اليومي في zad_forward_ledger =
//   opening − daily_burn × idx + مجموع أحداث الأيام لحد اليوم ده
// وأيام الأحداث بترجع كلها في event_days، فباقي الأيام بتتحسب من نفس المعادلة.

const DAY_MS = 86_400_000;

interface LedgerEvent { kind?: string; title?: string; amount?: number | string }
export interface ForwardLedger {
  as_of: string;
  horizon_days: number;
  opening_balance: number | string;
  daily_burn: number | string;
  cycle_end?: string | null;
  currency?: string | null;
  event_days?: Array<{ date: string; balance?: number | string; events?: LedgerEvent[] }>;
}

export interface DayPoint { date: string; balance: number }

export interface WhatIf {
  purchase: number;
  on: string;
  /** آخر يوم في الحكم: آخر الدورة لو جوه المدى — بعده القبض بييجي والتوقّع مابيحسبوش. */
  window_end: string;
  currency: string | null;
  /** الرصيد يوم الشراء بعده على طول. */
  balance_after_purchase: number;
  before: { first_negative: DayPoint | null; lowest: DayPoint | null; at_cycle_end: DayPoint | null };
  after: { first_negative: DayPoint | null; lowest: DayPoint | null; at_cycle_end: DayPoint | null };
  /** التزامات/اشتراكات الرصيد كان مغطيها ومش هيغطيها بعد الشراء — الأقرب الأول. */
  newly_uncovered: Array<{ date: string; kind: string; title: string; amount: number; balance_after: number }>;
  /** ok = مفيش يوم بالسالب بعد الشراء؛ tight = أول سالب جديد من الشراء؛ already_short = كان بالسالب قبله. */
  verdict: "ok" | "tight" | "already_short";
}

const num = (v: unknown): number => {
  const n = Number(v);
  return Number.isFinite(n) ? n : 0;
};
const round2 = (n: number) => Math.round(n * 100) / 100;
const isoDay = (ms: number) => new Date(ms).toISOString().slice(0, 10);

/** الرصيد كل يوم من as_of+1 لآخر المدى — نفس معادلة zad_forward_ledger. */
export function dailyBalances(ledger: ForwardLedger): DayPoint[] {
  const start = Date.parse(`${ledger.as_of}T00:00:00Z`);
  const horizon = Math.max(0, Math.trunc(num(ledger.horizon_days)));
  if (!Number.isFinite(start) || horizon === 0) return [];
  const eventsByDay = new Map<string, number>();
  for (const day of ledger.event_days ?? []) {
    eventsByDay.set(day.date, (day.events ?? []).reduce((sum, e) => sum + num(e.amount), 0));
  }
  const opening = num(ledger.opening_balance);
  const burn = Math.max(0, num(ledger.daily_burn));
  const out: DayPoint[] = [];
  let events = 0;
  for (let idx = 1; idx <= horizon; idx++) {
    const date = isoDay(start + idx * DAY_MS);
    events += eventsByDay.get(date) ?? 0;
    out.push({ date, balance: round2(opening - burn * idx + events) });
  }
  return out;
}

function summary(days: DayPoint[], cycleEnd: string | null | undefined) {
  const firstNegative = days.find((d) => d.balance < 0) ?? null;
  const lowest = days.reduce<DayPoint | null>((low, d) => (!low || d.balance < low.balance ? d : low), null);
  const atCycleEnd = cycleEnd ? days.find((d) => d.date === cycleEnd) ?? null : null;
  return { first_negative: firstNegative, lowest, at_cycle_end: atCycleEnd };
}

/**
 * الشراء [amount] يوم [onDate]؛ من غير تاريخ (أو النهارده) بيبان من أول يوم في التوقّع.
 * null لو المبلغ مش موجب أو التاريخ برّه المدى.
 */
export function simulatePurchase(ledger: ForwardLedger, amount: number, onDate?: string | null): WhatIf | null {
  const purchase = round2(num(amount));
  if (!(purchase > 0)) return null;
  const all = dailyBalances(ledger);
  if (!all.length) return null;
  const windowEnd = ledger.cycle_end && all.some((d) => d.date === ledger.cycle_end) ? ledger.cycle_end : all.at(-1)!.date;
  const before = all.filter((d) => d.date <= windowEnd);
  // شراء «النهارده» (as_of) بيأثّر من أول يوم في التوقّع.
  const on = onDate && onDate > ledger.as_of ? onDate : before[0].date;
  if (!before.some((d) => d.date === on)) return null;
  const after = before.map((d) => (d.date >= on ? { date: d.date, balance: round2(d.balance - purchase) } : d));
  const afterByDate = new Map(after.map((d) => [d.date, d.balance]));
  const beforeByDate = new Map(before.map((d) => [d.date, d.balance]));

  const newlyUncovered: WhatIf["newly_uncovered"] = [];
  for (const day of ledger.event_days ?? []) {
    if (day.date < on || day.date > windowEnd) continue;
    const b = beforeByDate.get(day.date);
    const a = afterByDate.get(day.date);
    if (b === undefined || a === undefined || !(b >= 0 && a < 0)) continue;
    for (const e of day.events ?? []) {
      if (num(e.amount) >= 0) continue;
      newlyUncovered.push({
        date: day.date,
        kind: String(e.kind ?? ""),
        title: String(e.title ?? ""),
        amount: round2(-num(e.amount)),
        balance_after: a,
      });
    }
  }

  const b = summary(before, ledger.cycle_end);
  const a = summary(after, ledger.cycle_end);
  return {
    purchase,
    on,
    window_end: windowEnd,
    currency: ledger.currency ?? null,
    balance_after_purchase: afterByDate.get(on) as number,
    before: b,
    after: a,
    newly_uncovered: newlyUncovered.slice(0, 5),
    verdict: b.first_negative ? "already_short" : a.first_negative ? "tight" : "ok",
  };
}
