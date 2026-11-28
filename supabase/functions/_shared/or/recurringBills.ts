// P3.6: كاشف المصاريف الثابتة من معاملات البنك: نفس التاجر + مبلغ قريب + فترة ثابتة، ٣ مرات على الأقل.
// دالة صافية: من غير شبكة ولا كتابة. الناتج مرشح بس، والتأكيد بيعدّي على الباب (confirm_obligation ← zad_commit_intent).
// كل رقم في النتيجة (المبلغ، الفترة، اليوم، العدد) محسوب من صفوف المعاملات نفسها، والصفوف المستعملة راجعة في `evidence`.
// الأرقام المختارة (اتقاست على بيانات اصطناعية بس، مش على حسابات حية، راجع التست):
//   - المبلغ: كل مرة جوه ±١٠٪ من وسيط المبالغ (فاتورة نت/كهربا بتتغير بالقليل؛ أكتر من كده مش «ثابت»).
//   - الفترة: كل فرق بين مرتين جوه ±٣ أيام من وسيط الفروق (±٤ للشهري عشان طول الشهور)، والوسيط في نطاق أسبوعي ٦–٨ / نص شهري ١٣–١٦ / شهري ٢٧–٣٣.
//   - الحي: آخر مرة في حدود ١٫٥ × الفترة من النهارده، وإلا الالتزام غالباً وقف.

export interface BankTxn {
  id?: string | null;
  title?: string | null;
  merchant_name?: string | null;
  amount: number;
  created_at: string;
  txn_kind?: string | null;
}

export type Period = "weekly" | "biweekly" | "monthly";

export interface RecurringCandidate {
  merchant: string;
  amount: number; // وسيط المبالغ، مقرّب لأقرب جنيه
  period: Period;
  periodDays: number; // وسيط الفروق بالأيام
  dueDay: number; // يوم الشهر لآخر مرة (UTC)
  count: number;
  lastDate: string; // YYYY-MM-DD
  nextDate: string; // آخر مرة + الوسيط
  evidence: string[]; // id المعاملات (أو التاريخ لو مفيش id)
}

export const MIN_OCCURRENCES = 3;
export const AMOUNT_TOLERANCE = 0.1;
export const ALIVE_FACTOR = 1.5;
const DAY = 86_400_000;
const PERIODS: Array<{ period: Period; lo: number; hi: number; jitter: number }> = [
  { period: "weekly", lo: 6, hi: 8, jitter: 1 },
  { period: "biweekly", lo: 13, hi: 16, jitter: 2 },
  { period: "monthly", lo: 27, hi: 33, jitter: 4 },
];

function median(xs: number[]): number {
  const s = [...xs].sort((a, b) => a - b);
  const m = s.length >> 1;
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
}

export function normMerchant(s: string): string {
  return s.toLowerCase().replace(/[ً-ْـ]/g, "").replace(/\d+/g, " ").replace(/[^\p{L}\s]/gu, " ")
    .replace(/\s+/g, " ").trim();
}

const dayStr = (t: number) => new Date(t).toISOString().slice(0, 10);

/** `known` = عناوين الالتزامات والاشتراكات الموجودة، اللي بتتطابق (احتواء) بتتشال. */
export function detectRecurringBills(txns: readonly BankTxn[], known: readonly string[], now: Date): RecurringCandidate[] {
  const knownNorm = known.map(normMerchant).filter((k) => k.length > 0);
  const groups = new Map<string, { label: string; rows: Array<{ t: number; amount: number; ref: string }> }>();
  for (const x of txns) {
    if (x.txn_kind && x.txn_kind !== "expense") continue;
    const label = (x.merchant_name ?? x.title ?? "").trim();
    const key = normMerchant(label);
    const amount = Number(x.amount);
    const t = Date.parse(x.created_at);
    if (key.length < 2 || !Number.isFinite(amount) || amount <= 0 || !Number.isFinite(t)) continue;
    const g = groups.get(key) ?? { label, rows: [] };
    g.rows.push({ t: Math.floor(t / DAY) * DAY, amount, ref: x.id ?? x.created_at.slice(0, 10) });
    groups.set(key, g);
  }
  const out: RecurringCandidate[] = [];
  for (const [key, g] of groups) {
    if (knownNorm.some((k) => key.includes(k) || k.includes(key))) continue;
    // أكتر من معاملة في نفس اليوم = مرة واحدة (أول واحدة)، مش تكرار.
    const byDay = new Map<number, { t: number; amount: number; ref: string }>();
    for (const r of g.rows) if (!byDay.has(r.t)) byDay.set(r.t, r);
    const rows = [...byDay.values()].sort((a, b) => a.t - b.t);
    if (rows.length < MIN_OCCURRENCES) continue;
    const med = median(rows.map((r) => r.amount));
    if (rows.some((r) => Math.abs(r.amount - med) > med * AMOUNT_TOLERANCE)) continue;
    const gaps = rows.slice(1).map((r, i) => Math.round((r.t - rows[i].t) / DAY));
    const gapMed = median(gaps);
    const p = PERIODS.find((q) => gapMed >= q.lo && gapMed <= q.hi);
    if (!p || gaps.some((d) => Math.abs(d - gapMed) > p.jitter)) continue;
    const last = rows[rows.length - 1];
    if (now.getTime() - last.t > gapMed * ALIVE_FACTOR * DAY) continue;
    out.push({
      merchant: g.label,
      amount: Math.round(med),
      period: p.period,
      periodDays: gapMed,
      dueDay: new Date(last.t).getUTCDate(),
      count: rows.length,
      lastDate: dayStr(last.t),
      nextDate: dayStr(last.t + gapMed * DAY),
      evidence: rows.map((r) => r.ref),
    });
  }
  return out.sort((a, b) => b.count - a.count || b.amount - a.amount);
}

const PERIOD_AR: Record<Period, string> = { weekly: "كل أسبوع", biweekly: "كل أسبوعين", monthly: "كل شهر" };

/** سؤال التأكيد: الأرقام كلها من المرشح (العدد، المبلغ، آخر تاريخ). مابيكتبش حاجة. */
export function recurringQuestion(c: RecurringCandidate): string {
  return `لقيت دفعة «${c.merchant}» حوالي ${c.amount} ${PERIOD_AR[c.period]}، آخر ${c.count} مرات (آخرهم ${c.lastDate}). أسجّلها التزام ثابت؟`;
}
