// وضع الطوارئ — منطق مشترك بين zad-brain وzad-core-intelligence.

/**
 * وضع الطوارئ «مفلس باقي الشهر» (20260914009000). صافية: خطة الأيام الباقية.
 * `cashLeft` = اللي العميل قاله بنفسه، وإلا المتاح من zad_budget_state لو السقف متأكد.
 * الأيام من days_left (أقل حاجة يوم)، والنهاية من cycle_end (حصري) أو الأيام الباقية.
 */
export function brokeModePlan(input: {
  cashLeft: number | null;
  available: number | null;
  limitConfirmed: boolean;
  daysLeft: number | null;
  cycleEnd: string | null;
  nowMs: number;
}): { cash_left: number | null; daily_cap: number | null; days_left: number; ends_at: string } {
  const days = Math.max(1, Math.min(45, Math.round(Number(input.daysLeft) || 0) || 1));
  const cash = input.cashLeft !== null && Number.isFinite(input.cashLeft)
    ? Math.max(0, input.cashLeft)
    : input.limitConfirmed && typeof input.available === "number" && Number.isFinite(input.available)
      ? Math.max(0, input.available)
      : null;
  const byCycle = input.cycleEnd && /^\d{4}-\d{2}-\d{2}$/.test(input.cycleEnd)
    ? Date.parse(`${input.cycleEnd}T00:00:00Z`)
    : NaN;
  const endMs = Number.isFinite(byCycle) && byCycle > input.nowMs + 3_600_000
    ? byCycle
    : input.nowMs + days * 86_400_000;
  return {
    cash_left: cash === null ? null : Math.round(cash * 100) / 100,
    daily_cap: cash === null ? null : Math.floor(cash / days),
    days_left: days,
    ends_at: new Date(endMs).toISOString(),
  };
}

/** الوضع شغال دلوقتي؟ صف قديم خلص وقته = مش شغال حتى لو ended_at فاضي. */
export function isBrokeModeActive(row: { ends_at?: string | null; ended_at?: string | null } | null, nowMs: number): boolean {
  if (!row || row.ended_at) return false;
  const end = Date.parse(String(row.ends_at ?? ""));
  return Number.isFinite(end) && end > nowMs;
}

/** وصفات الطوارئ: مفيش ولا صنف يتشرى. البهارات والملح والزيت والمية مش «شراء». */
const PANTRY_STAPLES = ["ملح", "فلفل", "زيت", "مية", "ماء", "بهارات", "سكر", "كمون"];
export function recipeNeedsNoShopping(missing: unknown): boolean {
  if (!Array.isArray(missing)) return true;
  return missing.every((m) => {
    const name = String(m ?? "").trim();
    return name === "" || PANTRY_STAPLES.some((s) => name.includes(s));
  });
}
