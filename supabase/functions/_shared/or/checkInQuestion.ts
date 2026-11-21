export const MIN_DAYS_BETWEEN_QUESTIONS = 7;

export interface CheckInCandidate {
  itemId: string;
  rate: number;
  low: number;
  high: number;
  onHand: number;
  essential: boolean;
  lastConfirmedDaysAgo: number;
}

export function infoValue(c: CheckInCandidate): number {
  if (
    !Number.isFinite(c.rate) || c.rate < 0 ||
    !Number.isFinite(c.low) || c.low < 0 ||
    !Number.isFinite(c.high) || c.high < 0 ||
    !Number.isFinite(c.onHand) || c.onHand < 0 ||
    !Number.isFinite(c.lastConfirmedDaysAgo) || c.lastConfirmedDaysAgo < 0
  ) {
    throw new RangeError("All numeric fields in CheckInCandidate must be non-negative finite numbers.");
  }

  if (c.rate === 0) return 0;

  const uncertainty = Math.min(3, (c.high - c.low) / c.rate);
  const urgency = 1 / (1 + (c.onHand / c.rate) / 7);
  const staleness = Math.min(1, c.lastConfirmedDaysAgo / 14);
  const weight = c.essential ? 2 : 1;

  const value = uncertainty * urgency * staleness * weight;
  return Math.round(value * 10000) / 10000;
}

export interface WeeklyQuestion {
  itemIds: string[];
  values: number[];
}

export function pickWeeklyQuestion(
  cands: readonly CheckInCandidate[],
  lastAskedDaysAgo: number | null,
  maxItems = 3,
  minValue = 0.05,
): WeeklyQuestion | null {
  if (lastAskedDaysAgo !== null && lastAskedDaysAgo < MIN_DAYS_BETWEEN_QUESTIONS) {
    return null;
  }

  const results = cands
    .map((c) => ({ itemId: c.itemId, value: infoValue(c) }))
    .filter((r) => r.value >= minValue)
    .sort((a, b) => {
      if (b.value !== a.value) return b.value - a.value;
      return a.itemId < b.itemId ? -1 : a.itemId > b.itemId ? 1 : 0; // not localeCompare: same order on every machine
    })
    .slice(0, maxItems);

  if (results.length === 0) return null;

  return {
    itemIds: results.map((r) => r.itemId),
    values: results.map((r) => r.value),
  };
}
