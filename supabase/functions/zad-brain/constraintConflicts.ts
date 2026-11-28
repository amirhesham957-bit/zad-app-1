// م٥ (ZAD_OR_PLAN): كاشف تعارض القيود — «لو التزمت بـX يوم D هيتعارض مع إيه؟». قراءة بس، ومن غير أي كتابة.
//
// دوال نقية: الصفوف بتتقرا في index.ts (case "check_constraint_conflicts") وبتتمرّر هنا. كل تعارض راجع معاه المصدر
// (الجدول واسم الصف)، وكل رقم في النص إما من كلام العميل (المبلغ والتاريخ) أو من صف، أو فرق بسيط بين رقمين منهم.
// المتاح (zad_budget_state.available) محسوب بعد الالتزامات، فمابنطرحش الالتزامات منه تاني: بنعرضها كتزامن بس.

import { medicineRunOut } from "../_shared/or/medicineRunOut.ts";

export interface ConflictInput { amount: number; date: string | null; label: string }

export interface BudgetState { available?: number | null; days_left?: number | null; currency?: string | null }
export interface DueRow { id?: string | null; title?: string | null; name?: string | null; amount?: number | null; minimum_payment?: number | null; due_day?: number | null; due_date?: string | null; renewal_date?: string | null }
export interface MedRow { id?: string | null; name: string; for_person?: string | null; remaining_quantity: number | null; daily_dose_count: number | null; units_per_dose?: number | null }
export interface ApptRow { id?: string | null; title: string; starts_at: string; expected_cost?: number | null; status?: string | null }

export interface ConflictSources {
  today: string; // YYYY-MM-DD بتوقيت الحساب
  timeZone: string;
  budget: BudgetState | null;
  obligations: readonly DueRow[];
  debts: readonly DueRow[];
  subscriptions: readonly DueRow[];
  pharmacy: readonly MedRow[];
  appointments: readonly ApptRow[];
}

export type ConflictKind = "over_budget" | "obligation_near" | "debt_near" | "subscription_near" | "medicine_runs_out" | "appointment_near";
export interface Conflict { kind: ConflictKind; text: string; source: string }

/** نص أدوات الموديل: تاريخ أو null. بيرفض أي تاريخ مش YYYY-MM-DD حقيقي أو في الماضي (الماضي مش التزام جديد). */
export function parseConflictInput(input: Record<string, unknown> | undefined, today: string): { value: ConflictInput } | { error: string } {
  const amount = Number(input?.amount);
  if (!Number.isFinite(amount) || amount <= 0 || amount > 1e9) return { error: "مرفوض: amount لازم رقم أكبر من صفر (المبلغ اللي هيلتزم بيه)." };
  let date: string | null = null;
  if (input?.date != null && String(input.date).trim() !== "") {
    const d = String(input.date).trim();
    if (!/^\d{4}-\d{2}-\d{2}$/.test(d) || toDay(d) === null) return { error: "مرفوض: date لازم YYYY-MM-DD صحيح." };
    if (d < today) return { error: "مرفوض: date في الماضي. ابعت تاريخ النهارده أو بعده." };
    date = d;
  }
  return { value: { amount, date, label: String(input?.label ?? "").trim().slice(0, 60) } };
}

const DAY = 86_400_000;
const NEAR_DAYS = 3; // نطاق «قريب من التاريخ» لما العميل يحدد تاريخ
const OPEN_DAYS = 7; // من غير تاريخ: الأسبوع الجاي

function toDay(s: string): number | null {
  const t = Date.parse(`${s}T00:00:00Z`);
  if (!Number.isFinite(t)) return null;
  return new Date(t).toISOString().slice(0, 10) === s ? Math.floor(t / DAY) : null;
}
const fromDay = (n: number) => new Date(n * DAY).toISOString().slice(0, 10);

/** أقرب تاريخ لـdue_day (يوم في الشهر) من النهارده فما بعد. الشهر القصير بيتقصّ على آخر يوم فيه. */
export function nextDueDate(dueDay: number, today: string): string | null {
  const t = toDay(today);
  if (t === null || !Number.isInteger(dueDay) || dueDay < 1 || dueDay > 31) return null;
  const [y, m] = today.split("-").map(Number);
  for (let k = 0; k < 2; k++) {
    const mi = m - 1 + k;
    const yy = y + Math.floor(mi / 12);
    const mm = ((mi % 12) + 12) % 12;
    const last = new Date(Date.UTC(yy, mm + 1, 0)).getUTCDate();
    const cand = Date.UTC(yy, mm, Math.min(dueDay, last)) / DAY;
    if (cand >= t) return fromDay(cand);
  }
  return null;
}

function dueOf(r: DueRow, today: string): string | null {
  const explicit = r.due_date ?? r.renewal_date ?? null;
  if (explicit) {
    const d = String(explicit).slice(0, 10);
    return toDay(d) !== null && d >= today ? d : null;
  }
  return r.due_day != null ? nextDueDate(Number(r.due_day), today) : null;
}

export function localDate(iso: string, timeZone: string): string | null {
  const t = Date.parse(iso);
  if (!Number.isFinite(t)) return null;
  try {
    const p = new Intl.DateTimeFormat("en-CA", { timeZone, year: "numeric", month: "2-digit", day: "2-digit" }).format(new Date(t));
    return /^\d{4}-\d{2}-\d{2}$/.test(p) ? p : null;
  } catch {
    return new Date(t).toISOString().slice(0, 10);
  }
}

export function findConflicts(input: ConflictInput, s: ConflictSources): Conflict[] {
  const out: Conflict[] = [];
  const cur = s.budget?.currency ? ` ${s.budget.currency}` : "";
  const todayN = toDay(s.today);
  if (todayN === null) return out;
  const targetN = input.date ? toDay(input.date) ?? todayN : todayN;
  const lo = input.date ? Math.max(todayN, targetN - NEAR_DAYS) : todayN;
  const hi = input.date ? targetN + NEAR_DAYS : todayN + OPEN_DAYS;
  const inWindow = (d: string | null) => {
    const n = d ? toDay(d) : null;
    return n !== null && n >= lo && n <= hi;
  };

  const avail = s.budget?.available;
  if (avail !== null && avail !== undefined && Number.isFinite(Number(avail)) && input.amount > Number(avail)) {
    const a = Number(avail);
    out.push({
      kind: "over_budget",
      text: `المبلغ ${Math.round(input.amount)}${cur} أكبر من المتاح (${Math.round(a)}${cur}) بفرق ${Math.round(input.amount - a)}${cur}.`,
      source: "zad_budget_state.available",
    });
  }

  const addDue = (rows: readonly DueRow[], kind: ConflictKind, table: string, label: string, money: (r: DueRow) => number | null | undefined) => {
    for (const r of rows) {
      const d = dueOf(r, s.today);
      if (!inWindow(d)) continue;
      const name = (r.title ?? r.name ?? "").trim() || label;
      const m = money(r);
      const amt = m != null && Number.isFinite(Number(m)) ? ` بـ${Math.round(Number(m))}${cur}` : "";
      out.push({ kind, text: `${label} «${name}»${amt} يوم ${d}، قريب من ${input.date ?? "النهارده"}.`, source: `${table}:${r.id ?? name}` });
    }
  };
  addDue(s.obligations, "obligation_near", "zad_obligations", "التزام", (r) => r.amount);
  addDue(s.debts, "debt_near", "zad_debts", "قسط دين", (r) => r.minimum_payment);
  addDue(s.subscriptions, "subscription_near", "zad_subscriptions", "اشتراك", (r) => r.amount);

  for (const m of s.pharmacy) {
    const ro = medicineRunOut(m, s.today); // P3.7: نفس الحساب الصافي (_shared/or/medicineRunOut.ts)
    if (!ro || todayN + ro.daysLeft > hi) continue;
    const rem = ro.remaining, days = ro.daysLeft, runOut = ro.runOutDate;
    const who = m.for_person ? ` (${m.for_person})` : "";
    out.push({
      kind: "medicine_runs_out",
      text: `الدوا «${m.name}»${who} هيخلص حوالي ${runOut} (الرصيد ${rem} بيكفي ${days} يوم).`,
      source: `zad_pharmacy_items:${m.id ?? m.name}`,
    });
  }

  for (const a of s.appointments) {
    if (a.status && a.status !== "upcoming") continue;
    const d = localDate(a.starts_at, s.timeZone);
    if (!inWindow(d)) continue;
    const cost = a.expected_cost != null && Number.isFinite(Number(a.expected_cost)) && Number(a.expected_cost) > 0
      ? ` وتكلفته المتوقعة ${Math.round(Number(a.expected_cost))}${cur}` : "";
    out.push({ kind: "appointment_near", text: `ميعاد «${a.title}» يوم ${d}${cost}.`, source: `zad_appointments:${a.id ?? a.title}` });
  }
  return out;
}

export function describeConflicts(input: ConflictInput, s: ConflictSources): string {
  const cur = s.budget?.currency ? ` ${s.budget.currency}` : "";
  const what = input.label ? `«${input.label}» ` : "";
  const head = `فحص تعارض ${what}${Math.round(input.amount)}${cur} ${input.date ? `يوم ${input.date}` : "دلوقتي"}:`;
  const found = findConflicts(input, s);
  const noBudget = s.budget?.available == null || !Number.isFinite(Number(s.budget.available));
  const lines = [head];
  if (found.length === 0) {
    lines.push("مفيش تعارض ظاهر مع الأقساط والالتزامات والاشتراكات والأدوية والمواعيد المتسجلة.");
  } else {
    for (const c of found) lines.push(`- ${c.text} [المصدر: ${c.source}]`);
  }
  if (noBudget) lines.push("مفيش سقف شهري متسجل، فمقارنة المتاح مش متاحة — اسأل العميل عن ميزانيته لو محتاجها.");
  lines.push("الأرقام دي بس اللي تتقال، وماتضيفش أرقام من عندك.");
  return lines.join("\n");
}
