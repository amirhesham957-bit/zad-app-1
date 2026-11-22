// استخراج الأنماط الأسبوعية (م٨.٧) من zad_events لكل فرد لوحده، بحد أدنى ٥ مرات.
// خصوصية (م٧.٩): الدالة بتاخد فرد واحد (viewerMemberId) وبترجّع أنماطه هو بس؛ أحداث أي فرد تاني بتتجاهل ومابتأثرش
// على النتيجة (مفيش تجميع بين الأفراد). دالة نقية: مافيش I/O. الوقت المدني بمنطقة الحساب مش الجهاز.

export const MIN_PATTERN_OCCURRENCES = 5;

export interface PatternEvent {
  memberId: string;
  kind: string;
  occurredAt: string; // ISO
}

export type DayPart = "morning" | "afternoon" | "evening" | "night";

export interface WeeklyPattern {
  memberId: string;
  kind: string;
  weekday: number; // 0=الأحد … 6=السبت
  dayPart: DayPart;
  count: number;
}

const WEEKDAYS: Record<string, number> = { Sun: 0, Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6 };

export function dayPartOf(hour: number): DayPart {
  if (hour >= 5 && hour < 12) return "morning";
  if (hour >= 12 && hour < 17) return "afternoon";
  if (hour >= 17 && hour < 22) return "evening";
  return "night";
}

function localParts(iso: string, timeZone: string): { weekday: number; hour: number } | null {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return null;
  const f = new Intl.DateTimeFormat("en-US", { timeZone, weekday: "short", hour: "numeric", hourCycle: "h23" })
    .formatToParts(d);
  const wd = WEEKDAYS[f.find((p) => p.type === "weekday")?.value ?? ""];
  const hour = Number(f.find((p) => p.type === "hour")?.value);
  if (wd === undefined || !Number.isFinite(hour)) return null;
  return { weekday: wd, hour };
}

/** أنماط الفرد `viewerMemberId` بس. مرتبة بالعدد نزولاً ثم بثبات (kind، يوم). */
export function extractWeeklyPatterns(
  events: readonly PatternEvent[],
  viewerMemberId: string,
  opts: { timeZone?: string; minOccurrences?: number } = {},
): WeeklyPattern[] {
  const timeZone = opts.timeZone ?? "Africa/Cairo";
  const min = Math.max(1, opts.minOccurrences ?? MIN_PATTERN_OCCURRENCES);
  const counts = new Map<string, WeeklyPattern>();
  for (const e of events) {
    if (e.memberId !== viewerMemberId) continue;
    const p = localParts(e.occurredAt, timeZone);
    if (!p) continue;
    const dayPart = dayPartOf(p.hour);
    const key = `${e.kind}|${p.weekday}|${dayPart}`;
    const cur = counts.get(key);
    if (cur) cur.count++;
    else counts.set(key, { memberId: viewerMemberId, kind: e.kind, weekday: p.weekday, dayPart, count: 1 });
  }
  return [...counts.values()]
    .filter((p) => p.count >= min)
    .sort((a, b) => b.count - a.count || a.kind.localeCompare(b.kind) || a.weekday - b.weekday);
}
