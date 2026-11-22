// م٥.٧: تنبيه المالك لما مزودات البحث تقع (وحدة نقية، من غير شبكة ولا أسرار).

export type RestRow = { source: string; until: string | null; reason?: string | null };
export type DealLogRow = { hits: number | null; searched_at?: string | null };

export type SearchAlertDecision = { alert: boolean; message: string; reason: string };

const HOURS = 3600_000;
export const MIN_RESTING = 2;
export const MIN_SEARCHES = 10;
export const ZERO_RATIO = 0.9;
export const ALERT_GAP_MS = 12 * HOURS;

export function decideSearchAlert(
  input: { restRows: RestRow[]; dealLog: DealLogRow[]; now: Date; lastAlertAt?: Date | null },
): SearchAlertDecision {
  const nowMs = input.now.getTime();
  const resting = [
    ...new Set(
      input.restRows
        .filter((r) => r.until && Date.parse(r.until) > nowMs)
        .map((r) => String(r.source).slice(0, 40)),
    ),
  ];
  const cutoff = nowMs - 24 * HOURS;
  const recent = input.dealLog.filter((r) => {
    if (!r.searched_at) return true;
    const t = Date.parse(r.searched_at);
    return Number.isNaN(t) || t >= cutoff;
  });
  const total = recent.length;
  const zero = recent.filter((r) => !r.hits || r.hits <= 0).length;
  const mostlyZero = total >= MIN_SEARCHES && zero / total >= ZERO_RATIO;
  const manyResting = resting.length >= MIN_RESTING;

  if (!manyResting && !mostlyZero) return { alert: false, message: "", reason: "healthy" };
  if (input.lastAlertAt && nowMs - input.lastAlertAt.getTime() < ALERT_GAP_MS) {
    return { alert: false, message: "", reason: "cooldown" };
  }

  const lines = ["تنبيه: البحث على الويب واقع."];
  if (resting.length > 0) lines.push(`المزودات الواقفة: ${resting.join("، ")}.`);
  if (total > 0) lines.push(`${zero} من ${total} عملية بحث رجعت 0 نتيجة في آخر ٢٤ ساعة.`);
  lines.push("جدّد المفتاح أو الكوتة (Tavily / Google / CSE) عشان العروض والترندات ترجع.");
  return {
    alert: true,
    message: lines.slice(0, 4).join("\n"),
    reason: manyResting && mostlyZero ? "both" : manyResting ? "providers_resting" : "zero_hits",
  };
}
