// P3.7: نفاد الدوا الحتمي = الرصيد ÷ (جرعات في اليوم × وحدات في الجرعة). دالة صافية، من غير موديل.
// المصدر: remaining_quantity وdaily_dose_count وunits_per_dose من صف zad_pharmacy_items (كل رقم في النص منهم).
// remaining_quantity بيتخصم عند كل جرعة (doseDoor)، فهو الرصيد نفسه. من غير جدول جرعات أو من غير رصيد = null (مابنخمّنش).
import { dailyUse, remainingUnits, type PharmacyStockInput } from "./pharmacyStock.ts";

export interface RunOutRow {
  name?: string | null;
  remaining_quantity: number | null;
  daily_dose_count: number | null;
  units_per_dose?: number | null;
}

export interface RunOut {
  daysLeft: number; // أيام كاملة بيكفيها الرصيد (٠ = مايكفيش جرعات النهارده كاملة)
  runOutDate: string; // YYYY-MM-DD: اليوم اللي الرصيد مابيكفيش فيه جرعاته
  dailyUnits: number;
  remaining: number;
}

const DAY = 86_400_000;

/** `today` = YYYY-MM-DD بتوقيت الحساب. null لو الرصيد أو الجدول ناقص أو مش رقم صالح. */
export function medicineRunOut(m: RunOutRow, today: string): RunOut | null {
  if (m.remaining_quantity === null || m.remaining_quantity === undefined) return null;
  const rem = Number(m.remaining_quantity);
  const times = Number(m.daily_dose_count ?? 0);
  const units = Number(m.units_per_dose ?? 1);
  if (!Number.isFinite(rem) || !Number.isFinite(times) || !(times > 0)) return null;
  const t = Date.parse(`${today}T00:00:00Z`);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(today) || !Number.isFinite(t)) return null;
  const i: PharmacyStockInput = {
    restockQty: Math.max(0, rem),
    dosesTakenSince: 0,
    unitsPerDose: Number.isFinite(units) && units > 0 ? units : 1,
    timesPerDay: times,
  };
  const per = dailyUse(i);
  const left = remainingUnits(i);
  const daysLeft = Math.floor(left / per);
  return {
    daysLeft,
    runOutDate: new Date(t + daysLeft * DAY).toISOString().slice(0, 10),
    dailyUnits: per,
    remaining: left,
  };
}

/** نص «when» للتنبيه: التاريخ والرصيد من الصف. من غير جدول = «قريب» زي الأول. */
export function runOutWhen(m: RunOutRow, today: string): string {
  const r = medicineRunOut(m, today);
  if (!r) return "قريب";
  return r.daysLeft <= 0
    ? `النهارده (الرصيد ${r.remaining} مايكفيش جرعاته)`
    : `حوالي ${r.runOutDate} (الرصيد ${r.remaining} بيكفي ${r.daysLeft} يوم)`;
}
