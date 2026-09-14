// المواسم الإسلامية بتقويم أم القرى (رمضان والعيدين) — ٢٠٢٦-٠٩-١٤.
//
// العقل والشيف وصباح الخير بيتصرفوا حسب الموسم: في رمضان مفيش «غدا» ولا «اشرب مية الصبح»،
// والوصفات للفطار والسحور، وقرب آخره فكرة الزكاة والعيدية. التاريخ الهجري محسوب بتوقيت
// العميل (Intl بتقويم islamic-umalqura — Deno فيه ICU كامل، اتأكد: 2027-02-08 = ١ رمضان ١٤٤٨).
// رؤية الهلال ممكن تفرق يوم عن الحساب؛ عشان كده الكلام بيقول «رمضان» مش «اليوم رقم كذا بالظبط»
// في الحاجات الحساسة.

export type SeasonKind = "ramadan" | "eid_fitr" | "eid_adha" | "dhul_hijjah" | null;

export interface Season {
  kind: SeasonKind;
  hijri_year: number;
  hijri_month: number;
  hijri_day: number;
}

export function hijriDate(date: Date, timeZone: string): { year: number; month: number; day: number } | null {
  try {
    const parts = new Intl.DateTimeFormat("en-u-ca-islamic-umalqura", {
      year: "numeric", month: "numeric", day: "numeric", timeZone,
    }).formatToParts(date);
    const get = (t: string) => Number(parts.find((p) => p.type === t)?.value);
    const year = get("year"), month = get("month"), day = get("day");
    return Number.isFinite(year) && Number.isFinite(month) && Number.isFinite(day) ? { year, month, day } : null;
  } catch {
    return null;
  }
}

export function seasonFor(date: Date, timeZone: string): Season | null {
  const h = hijriDate(date, timeZone);
  if (!h) return null;
  const kind: SeasonKind =
    h.month === 9 ? "ramadan"
    : h.month === 10 && h.day <= 3 ? "eid_fitr"
    : h.month === 12 && h.day >= 10 && h.day <= 13 ? "eid_adha"
    : h.month === 12 && h.day < 10 ? "dhul_hijjah"
    : null;
  return { kind, hijri_year: h.year, hijri_month: h.month, hijri_day: h.day };
}

/** سطر للموديل يوصف الموسم. فاضي لو مفيش موسم. */
export function seasonInstruction(season: Season | null): string {
  switch (season?.kind) {
    case "ramadan":
      return `إحنا في رمضان (اليوم ${season.hijri_day} تقريباً). مفيش أكل ولا شرب بالنهار: الوجبات فطار وسحور مش فطار صباحي وغدا، ` +
        "والتذكيرات والنصايح تراعي الصيام. ميزانية رمضان (ياميش، عزومات، زكاة الفطر) منطقية تتذكر" +
        (season.hijri_day >= 20 ? "، وقرّبنا من العيد: العيدية وزكاة الفطر وهدوم العيد." : ".");
    case "eid_fitr":
      return "إحنا في عيد الفطر: كل سنة وإنت طيب. العيدية والعزومات والخروجات مصاريف متوقعة، فرحي معاه من غير لوم.";
    case "eid_adha":
      return "إحنا في عيد الأضحى: كل سنة وإنت طيب. الأضحية واللحمة والعزومات مصاريف متوقعة، ولو فيه لحمة كتير اقترحي تخزينها صح.";
    case "dhul_hijjah":
      return "إحنا في العشر الأوائل من ذي الحجة وقرّب عيد الأضحى: الأضحية والعيدية مصاريف جاية تستاهل تتحسب.";
    default:
      return "";
  }
}
