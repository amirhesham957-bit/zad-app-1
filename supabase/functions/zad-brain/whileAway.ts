// whileAway.ts — «فاتك إيه» لما العميل يرجع بعد غياب (الموجة ٣ من «خطة سد الفجوات»، ٢٠٢٦-١٠-١٠).
//
// عميل غاب أيام ورجع كتب رسالة: البيت ماوقفش — البنك سجّل، المواعيد عدّت، وفيه معاملات مستنية رأيه. من غير ده
// العقل بيرد على الرسالة كأنه كلّمه امبارح. السطر بيتبني هنا بقواعد من الداتا (صفر توكنز، صفر أرقام مخترعة)،
// والموديل بيقوله بلهجته في أول الرد. مقاس على الحي (٢٠٢٦-١٠-١٠، قراية بس): ٣ رجعات بعد ٣ أيام أو أكتر في ٤٧ لفة.
//
// «آخر مرة» = آخر لفة في zad_chat_turns (كل القنوات: التطبيق وتليجرام والصوت). التنبيهات ولحظات الصوت مش كلام.

import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";

export const AWAY_DAYS = 3;
const DAY_MS = 86_400_000;

export interface AwayFacts {
  days: number;
  expenses: { count: number; total: number };
  currency: string | null;
  /** معاملات بنك مستنية تأكيده أو تصنيفه. */
  awaiting: number;
  /** مواعيد عدّت وهو غايب (عناوينها، أول اتنين). */
  appointments: string[];
}

/** عدد الأيام من آخر لفة، أو null لو مش «رجوع» (مفيش لفة قبل كده، أو أقل من AWAY_DAYS). */
export function awayDays(lastTurnAt: string | null | undefined, now: number): number | null {
  const at = lastTurnAt ? Date.parse(lastTurnAt) : NaN;
  if (!Number.isFinite(at) || at > now) return null;
  const days = Math.floor((now - at) / DAY_MS);
  return days >= AWAY_DAYS ? days : null;
}

function amount(n: number): string {
  return Math.round(n).toLocaleString("en-US");
}

/** السطر نفسه، أو null لو مافاتهوش حاجة تتقال. */
export function awayLine(f: AwayFacts): string | null {
  const parts: string[] = [];
  if (f.expenses.count > 0) {
    const what = f.expenses.count === 1 ? "مصروف واحد" : `${f.expenses.count} مصاريف`;
    parts.push(`اتسجل ${what} بـ${amount(f.expenses.total)}${f.currency ? ` ${f.currency}` : ""}`);
  }
  if (f.awaiting > 0) {
    parts.push(f.awaiting === 1 ? "فيه معاملة بنك مستنية تأكيدك" : `فيه ${f.awaiting} معاملات بنك مستنية تأكيدك`);
  }
  if (f.appointments.length > 0) {
    parts.push(`عدّى ${f.appointments.map((t) => `«${t}»`).join(" و")}`);
  }
  if (parts.length === 0) return null;
  return `من آخر مرة اتكلمنا (من ${f.days} أيام): ${parts.join("، و")}.`;
}

/** بلوك البرومبت للفة دي، أو "". */
export function whileAwayBlock(line: string | null): string {
  if (!line) return "";
  return "\n=== فاتك إيه ===\n" +
    "العميل راجع بعد غياب. ابدأ ردك بالسطر ده بلهجته — نفس الأرقام بالظبط، من غير زيادة ولا تعليق عليها — " +
    `وبعدين رد على رسالته هو:\n${line}\n`;
}

/** القراءات + السطر. أي قراية فشلت ⇒ مفيش سطر (سطر ناقص أوحش من مفيش). */
export async function loadWhileAway(
  sb: SupabaseClient,
  userId: string,
  lastTurnAt: string | null | undefined,
  currency: string | null,
  now = Date.now(),
): Promise<string | null> {
  const days = awayDays(lastTurnAt, now);
  if (days === null) return null;
  const since = new Date(Date.parse(lastTurnAt as string)).toISOString();
  const nowIso = new Date(now).toISOString();
  try {
    const [txRes, propRes, apptRes] = await Promise.all([
      sb.from("zad_transactions").select("amount").eq("user_id", userId).eq("txn_kind", "expense")
        .gt("created_at", since).limit(500),
      sb.from("zad_transaction_proposals").select("id").eq("user_id", userId)
        .in("status", ["needs_classification", "awaiting_confirmation"]).limit(50),
      sb.from("zad_appointments").select("title").eq("user_id", userId).neq("status", "cancelled")
        .gt("starts_at", since).lte("starts_at", nowIso).order("starts_at", { ascending: true }).limit(5),
    ]);
    if (txRes.error || propRes.error || apptRes.error) return null;
    const amounts = ((txRes.data ?? []) as Array<{ amount: number | string | null }>)
      .map((t) => Math.abs(Number(t.amount) || 0)).filter((a) => a > 0);
    return awayLine({
      days,
      expenses: { count: amounts.length, total: amounts.reduce((s, a) => s + a, 0) },
      currency: currency && currency !== "غير معروف" ? currency : null,
      awaiting: (propRes.data ?? []).length,
      appointments: ((apptRes.data ?? []) as Array<{ title: string | null }>)
        .map((a) => String(a.title ?? "").trim().slice(0, 40)).filter(Boolean).slice(0, 2),
    });
  } catch (e) {
    console.warn("[while_away] read failed:", (e as Error)?.message);
    return null;
  }
}
