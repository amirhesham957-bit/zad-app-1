// pharmacyStock.ts — medicine stock left after logged doses, reorder point in supply days, next dose in the member's own time zone

export const DOSE_TIME_RE = /^([01]\d|2[0-3]):[0-5]\d$/;

export interface PharmacyStockInput {
  restockQty: number;
  dosesTakenSince: number;
  unitsPerDose: number;
  timesPerDay: number;
  leadTimeDays?: number;
  safetyDays?: number;
}

function validateInput(i: PharmacyStockInput) {
  const fields = [
    "restockQty",
    "dosesTakenSince",
    "unitsPerDose",
    "timesPerDay",
  ] as const;
  for (const field of fields) {
    const val = i[field];
    if (typeof val !== "number" || !Number.isFinite(val) || val < 0) {
      throw new RangeError(`Invalid ${field}: ${val}`);
    }
  }
}

export function dailyUse(i: PharmacyStockInput): number {
  validateInput(i);
  return i.timesPerDay * i.unitsPerDose;
}

export function remainingUnits(i: PharmacyStockInput): number {
  validateInput(i);
  return Math.max(0, i.restockQty - i.dosesTakenSince * i.unitsPerDose);
}

export function daysOfSupply(i: PharmacyStockInput): number | null {
  const use = dailyUse(i);
  if (use === 0) return null;
  return Math.round((remainingUnits(i) / use) * 10) / 10;
}

export function reorderPoint(i: PharmacyStockInput): number {
  const leadTimeDays = i.leadTimeDays ?? 3;
  const safetyDays = i.safetyDays ?? 2;
  if (!Number.isFinite(leadTimeDays) || leadTimeDays < 0 || !Number.isFinite(safetyDays) || safetyDays < 0) {
    throw new RangeError("Invalid leadTimeDays or safetyDays");
  }
  return dailyUse(i) * (leadTimeDays + safetyDays);
}

export function shouldReorder(i: PharmacyStockInput): boolean {
  const use = dailyUse(i);
  return use > 0 && remainingUnits(i) <= reorderPoint(i);
}

export function localDate(iso: string, timeZone: string): string {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date(iso));
}

export function nextDose(
  times: readonly string[],
  nowIso: string,
  timeZone: string,
): { date: string; time: string } | null {
  if (times.length === 0) return null;

  for (const t of times) {
    if (!DOSE_TIME_RE.test(t)) {
      throw new RangeError(`Invalid dose time: ${t}`);
    }
  }

  const now = new Date(nowIso);
  const formatter = new Intl.DateTimeFormat("en-CA", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23", // not hour12:false — V8 renders midnight as "24:05" with that
  });

  const parts = formatter.formatToParts(now);
  const getPart = (type: string) => parts.find((p) => p.type === type)?.value;
  const localDateStr = `${getPart("year")}-${getPart("month")}-${getPart("day")}`;
  const localTimeStr = `${getPart("hour")}:${getPart("minute")}`;

  // Find next in today
  const todayTimes = times.filter((t) => t > localTimeStr).sort();
  if (todayTimes.length > 0) {
    return { date: localDateStr, time: todayTimes[0] };
  }

  // Find earliest in next day
  // By the calendar, not now + 24h: a DST day is 23 or 25 hours long.
  const [y, m, d] = localDateStr.split("-").map(Number);
  const tomorrowDateStr = new Date(Date.UTC(y, m - 1, d + 1)).toISOString().slice(0, 10);

  const sortedTimes = [...times].sort();
  return { date: tomorrowDateStr, time: sortedTimes[0] };
}
