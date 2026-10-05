// nextRenewal.ts — التجديد الجاي لاشتراك، نفس public.zad_subscription_next_renewal بالظبط.
//
// المراجعة الشاملة (٢٠٢٦-١٠-٠٥): التطبيق بيحسب التجديد الجاي (Subscription.nextRenewalFrom)، والميزانية و«دفتر الأيام»
// بيستخدموا الدالة دي في SQL — لكن العقل والبوت وتذكير الفواتير والملخص كانوا بيقروا `renewal_date` الخام. تاريخ فات
// (نتفليكس ٢٠٢٦-١٠-٠٣) كان بيتقال «هيتجدد ٣ أكتوبر» بعد ما عدّى، وتذكير الفاتورة بيرن أول شهر بس وبعدين عمره ما يرن تاني.
// لو غيّرت هنا غيّر الدالة في SQL (والعكس) — واختبار `nextRenewal_test.ts` بيقفل الحالات.

const DAY = 86_400_000;

function iso(d: Date): string {
  return d.toISOString().slice(0, 10);
}

function lastDay(year: number, month0: number): number {
  return new Date(Date.UTC(year, month0 + 1, 0)).getUTCDate();
}

function parseIso(s: string): Date | null {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(s)) return null;
  const d = new Date(`${s}T00:00:00Z`);
  // '2026-02-31' بيعدّي الـregex بس مش تاريخ.
  return Number.isFinite(d.getTime()) && iso(d) === s ? d : null;
}

/** YYYY-MM-DD لأول تجديد في [asOf] أو بعده، أو null لو مفيش ما يتحسب منه. */
export function nextRenewal(
  renewalDate: string | null | undefined,
  dueDay: number | null | undefined,
  billingCycle: string | null | undefined,
  asOf: string,
): string | null {
  const asof = parseIso(asOf);
  if (!asof) return null;
  let anchor = renewalDate ? parseIso(String(renewalDate).slice(0, 10)) : null;
  let day: number;
  if (!anchor) {
    const fromText = Number((String(renewalDate ?? "").match(/\d{1,2}/) ?? [])[0]);
    day = Number(dueDay ?? (Number.isFinite(fromText) ? fromText : NaN));
    if (!Number.isInteger(day) || day < 1 || day > 31) return null;
    const y = asof.getUTCFullYear(), m = asof.getUTCMonth();
    anchor = new Date(Date.UTC(y, m, Math.min(day, lastDay(y, m))));
  } else {
    day = anchor.getUTCDate();
  }
  const cycle = String(billingCycle ?? "MONTHLY").toUpperCase();
  let next = anchor;
  for (let guard = 0; next < asof && guard < 600; guard++) {
    if (cycle === "YEARLY" || cycle === "ANNUAL") {
      next = new Date(Date.UTC(next.getUTCFullYear() + 1, next.getUTCMonth(), next.getUTCDate()));
    } else if (cycle === "WEEKLY") {
      next = new Date(next.getTime() + 7 * DAY);
    } else {
      const y = next.getUTCFullYear(), m = next.getUTCMonth() + 1;
      const ny = y + Math.floor(m / 12), nm = m % 12;
      next = new Date(Date.UTC(ny, nm, Math.min(day, lastDay(ny, nm))));
    }
  }
  return next < asof ? null : iso(next);
}
