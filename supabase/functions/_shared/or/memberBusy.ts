/**
 * جدول مواعيد الفرد -> مشغول بالدقايق من أول الأسبوع (ZAD_OR_PLAN م٥.٢)، يتغذى بيه `bestGatherings`.
 * دالة صافية: مفيش قراية داتابيز. المدني = إزاحة ثابتة جوه weekStartIso.
 */
import type { Busy } from "./gatheringTime.ts";

export interface MemberEvent {
  member: string;
  startIso: string;
  endIso?: string;
  /** لو مفيش نهاية. الافتراضي ٦٠ دقيقة. */
  durationMinutes?: number;
}

const WEEK_MINUTES = 7 * 1440;

/** weekStartIso = بداية يوم ٠ (منتصف ليل مدني) بصيغة ISO بإزاحتها. المواعيد برا الأسبوع بتتقص أو بتتشال. */
export function eventsToBusy(
  events: readonly MemberEvent[],
  weekStartIso: string,
): Busy[] {
  const base = Date.parse(weekStartIso);
  if (!Number.isFinite(base)) return [];
  const out: Busy[] = [];
  for (const e of events) {
    const s = Date.parse(e.startIso);
    if (!Number.isFinite(s) || !e.member) continue;
    let en = e.endIso ? Date.parse(e.endIso) : NaN;
    if (!Number.isFinite(en)) en = s + (e.durationMinutes ?? 60) * 60000;
    if (en <= s) continue;
    const start = Math.max(0, Math.round((s - base) / 60000));
    const end = Math.min(WEEK_MINUTES, Math.round((en - base) / 60000));
    if (end > start) out.push({ member: e.member, start, end });
  }
  return out.sort((a, b) => a.start - b.start || a.member.localeCompare(b.member));
}
