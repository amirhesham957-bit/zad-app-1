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

/**
 * الموسم الجاي (ZAD_LIVING_BRAIN.md الشريحة ١٩): «يجهّز قوائم الاحتياجات قبل موسم ارتفاع الأسعار». أول يوم
 * في رمضان أو في ذي الحجة جوه [horizonDays] يوم. null لو مفيش، أو لو إحنا فيه أصلاً (seasonFor بيغطيه).
 */
export function upcomingSeason(
  date: Date, timeZone: string, horizonDays = 21,
): { kind: "ramadan" | "dhul_hijjah"; in_days: number; hijri_year: number } | null {
  for (let d = 1; d <= horizonDays; d++) {
    const s = seasonFor(new Date(date.getTime() + d * 86_400_000), timeZone);
    if (!s || s.hijri_day !== 1) continue;
    if (s.hijri_month === 9) return { kind: "ramadan", in_days: d, hijri_year: s.hijri_year };
    if (s.hijri_month === 12) return { kind: "dhul_hijjah", in_days: d, hijri_year: s.hijri_year };
  }
  return null;
}

/** سطر للموديل عن الموسم الجاي — تجهيز قبل ما الأسعار تعلى، مش ضغط شراء. */
export function upcomingSeasonInstruction(u: { kind: "ramadan" | "dhul_hijjah"; in_days: number } | null): string {
  if (!u) return "";
  return u.kind === "ramadan"
    ? `رمضان بعد حوالي ${u.in_days} يوم، والسلع الأساسية والياميش أسعارها بتعلى قبله. لو جه سياقه، اقترح قايمة تجهيز من اللي ` +
      "ناقص في البيت فعلاً (تمر، زيت، سكر، رز، مكرونة، ياميش) يشتريها بدري — وبس لو الميزانية تسمح، من غير ضغط."
    : `ذي الحجة بعد حوالي ${u.in_days} يوم (والعيد بعدها بعشرة): لو بيضحّي، الحجز بدري أرخص؛ واللحمة والعيدية مصاريف جاية ` +
      "تستاهل تتحسب. اسأله مرة لو هيضحّي السنة دي — من غير افتراض.";
}
