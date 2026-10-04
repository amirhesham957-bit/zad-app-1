// school.ts — جدول الحصص في يوم العيلة (ZAD_LIVING_BRAIN.md الشريحة ٢١).
//
// zad_school_timetable بيتملى من الكاميرا (روشتة/جدول حصص، 20261004110000). هنا بيتحول ليوم: مين عنده إيه
// النهارده وبكرة — للشات («عند عمر حصص إيه بكرة؟») ولـ«تصبح على خير» («جهّز شنطة عمر: رياضيات وعلوم»).

export interface TimetableRow {
  person: string;
  weekday: number;
  period: number;
  starts: string | null;
  subject: string;
}

export interface SchoolDay {
  person: string;
  subjects: string[];
  /** أول حصة لو وقتها مكتوب (HH:MM). */
  first_start: string | null;
}

/** حصص [weekday] (٠ = الأحد) لكل شخص، بالترتيب. اليوم اللي مالوش حصص = مش في القايمة. */
export function schoolDay(rows: readonly TimetableRow[], weekday: number): SchoolDay[] {
  const byPerson = new Map<string, TimetableRow[]>();
  for (const r of rows) {
    if (r.weekday !== weekday || !r.subject?.trim()) continue;
    byPerson.set(r.person, [...(byPerson.get(r.person) ?? []), r]);
  }
  return [...byPerson.entries()].map(([person, list]) => {
    const ordered = [...list].sort((a, b) => a.period - b.period);
    const first = ordered[0]?.starts;
    return {
      person,
      subjects: [...new Set(ordered.map((r) => r.subject.trim()))].slice(0, 10),
      first_start: first ? String(first).slice(0, 5) : null,
    };
  });
}

/** اليوم في الأسبوع (٠ = الأحد) لتاريخ YYYY-MM-DD — من غير منطقة زمنية: التاريخ نفسه محلي. */
export function weekdayOfDate(localDate: string, plusDays = 0): number {
  const d = new Date(`${localDate}T12:00:00Z`);
  return new Date(d.getTime() + plusDays * 86_400_000).getUTCDay();
}
