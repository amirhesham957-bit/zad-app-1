// م٣.٤ (ZAD_OR_PLAN): «الدوا هيخلص امتى؟ أطلبه إمتى؟» — الرصيد ونقطة إعادة الطلب بأيام التوريد وميعاد الجرعة الجاية.
//
// الحساب في `_shared/or/pharmacyStock.ts`. remaining_quantity بيتخصم منه عند كل جرعة (doseDoor) فهو الرصيد نفسه،
// فـdosesTakenSince = 0 (زي medicineStock.ts). أيام التوريد من العميل (افتراضي ٣ + ٢ أمان). مفيش منطقة زمنية لكل فرد
// في الجداول، فميعاد الجرعة بمنطقة حساب العميل، أو time_zone لو قالها.

import { daysOfSupply, DOSE_TIME_RE, nextDose, type PharmacyStockInput, remainingUnits, reorderPoint, shouldReorder } from "../_shared/or/pharmacyStock.ts";

export type PharmacyRow = {
  name: string;
  for_person?: string | null;
  remaining_quantity: number | null;
  daily_dose_count: number | null;
  units_per_dose?: number | null;
  dose_times?: string | null;
};

export type ReorderInput = { name: string; leadTimeDays: number | undefined; safetyDays: number | undefined; timeZone: string | undefined };

export function parseReorderInput(input: Record<string, unknown> | undefined): { value: ReorderInput } | { error: string } {
  const num = (v: unknown, field: string): { v?: number } | { error: string } => {
    if (v == null) return {};
    const n = Number(v);
    if (!Number.isFinite(n) || n < 0 || n > 90) return { error: `مرفوض: ${field} لازم رقم من ٠ لـ٩٠ يوم.` };
    return { v: n };
  };
  const lead = num(input?.lead_time_days, "lead_time_days");
  if ("error" in lead) return lead;
  const safety = num(input?.safety_days, "safety_days");
  if ("error" in safety) return safety;
  let timeZone: string | undefined;
  if (input?.time_zone != null) {
    timeZone = String(input.time_zone).trim();
    try {
      new Intl.DateTimeFormat("en-US", { timeZone });
    } catch {
      return { error: "مرفوض: time_zone مش منطقة زمنية صحيحة (مثلاً Africa/Cairo)." };
    }
  }
  return { value: { name: String(input?.name ?? "").trim().toLowerCase().slice(0, 60), leadTimeDays: lead.v, safetyDays: safety.v, timeZone } };
}

export function describeReorder(rows: readonly PharmacyRow[], v: ReorderInput, nowIso: string, accountTz: string): string {
  const tz = v.timeZone ?? accountTz;
  const picked = rows.filter((r) => !v.name || r.name.trim().toLowerCase().includes(v.name) || v.name.includes(r.name.trim().toLowerCase()));
  if (picked.length === 0) return v.name ? `مرفوض: مفيش دواء اسمه «${v.name}» في الصيدلية.` : "مفيش أدوية في الصيدلية.";
  const lead = v.leadTimeDays ?? 3;
  const lines = [`رصيد الأدوية ونقطة إعادة الطلب (توريد ${lead} يوم + ${v.safetyDays ?? 2} أمان)، المواعيد بتوقيت ${tz}:`];
  for (const r of picked) {
    const who = r.for_person ? ` (${r.for_person})` : "";
    if (r.remaining_quantity === null || !Number.isFinite(Number(r.remaining_quantity))) {
      lines.push(`- ${r.name}${who}: مفيش رصيد متسجل.`);
      continue;
    }
    const times = Number(r.daily_dose_count ?? 0);
    const units = Number(r.units_per_dose ?? 1);
    const i: PharmacyStockInput = {
      restockQty: Math.max(0, Number(r.remaining_quantity)),
      dosesTakenSince: 0,
      unitsPerDose: Number.isFinite(units) && units > 0 ? units : 1,
      timesPerDay: Number.isFinite(times) && times > 0 ? times : 0,
      leadTimeDays: v.leadTimeDays,
      safetyDays: v.safetyDays,
    };
    const days = daysOfSupply(i);
    let line = `- ${r.name}${who}: باقي ${remainingUnits(i)} وحدة`;
    if (days === null) {
      line += "، مفيش جدول جرعات فمفيش حساب أيام.";
    } else {
      line += `، يكفي ${days} يوم، نقطة الطلب ${reorderPoint(i)} وحدة — ${shouldReorder(i) ? "اطلبه دلوقتي" : "لسه بدري"}.`;
    }
    const doseTimes = String(r.dose_times ?? "").split(",").map((t) => t.trim()).filter((t) => DOSE_TIME_RE.test(t));
    const next = nextDose(doseTimes, nowIso, tz);
    if (next) line += ` الجرعة الجاية ${next.date} ${next.time}.`;
    lines.push(line);
  }
  lines.push("الأرقام دي بس اللي تتقال.");
  return lines.join("\n");
}
