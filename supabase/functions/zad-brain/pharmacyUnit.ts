export function pharmacyUnit(raw: unknown): string {
  const unit = String(raw ?? "").trim();
  if (!unit) return "قرص";
  const u = unit.toLowerCase();
  if (/^(حب|قرص|أقراص|اقراص|tab|pill)/.test(u)) return "قرص";
  if (/^(كريم|مرهم|جل|جيل|دهان|لوشن|cream|ointment|gel|lotion)/.test(u)) return "دهان";
  if (/^(كبسول|cap)/.test(u)) return "كبسولة";
  if (/^(نقط|نقطة|قطر)/.test(u)) return "نقطة";
  return unit.slice(0, 30);
}
