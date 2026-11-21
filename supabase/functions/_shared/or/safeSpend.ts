export function mulberry32(seed: number): () => number {
  return function () {
    let t = (seed += 0x6D2B79F5);
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export const MIN_HISTORY_DAYS = 14;
export const DEFAULT_PATHS = 1000;

export interface SafeSpendInput {
  available: number;
  obligationsUntilPayday: number;
  margin: number;
  daysUntilPayday: number;
  spendHistory: readonly number[];
}

export interface SafeSpendResult {
  perDay: number;
  approximate: boolean;
  reachProbability: number | null;
  paths: number;
}

export function safeSpendToday(
  input: SafeSpendInput,
  opts: { paths?: number; seed?: number } = {},
): SafeSpendResult {
  const {
    available,
    obligationsUntilPayday,
    margin,
    daysUntilPayday,
    spendHistory,
  } = input;

  if (
    !Number.isFinite(available) || !Number.isFinite(obligationsUntilPayday) ||
    !Number.isFinite(margin) || !Number.isFinite(daysUntilPayday)
  ) {
    throw new RangeError("NaN/non-finite number in input");
  }
  if (margin < 0 || obligationsUntilPayday < 0) {
    throw new RangeError("Negative margin or obligations");
  }
  for (const h of spendHistory) {
    if (h < 0 || !Number.isFinite(h)) {
      throw new RangeError("Negative or non-finite history value");
    }
  }

  const days = Math.max(1, Math.floor(daysUntilPayday));
  const perDayRaw = (available - obligationsUntilPayday - margin) / days;
  const perDay = Math.round(Math.max(0, perDayRaw) * 100) / 100;

  if (spendHistory.length < MIN_HISTORY_DAYS) {
    return { perDay, approximate: true, reachProbability: null, paths: 0 };
  }

  const paths = opts.paths ?? DEFAULT_PATHS;
  const rng = mulberry32(opts.seed ?? 1);
  let successes = 0;
  const limit = available - obligationsUntilPayday;

  for (let p = 0; p < paths; p++) {
    let sum = 0;
    for (let d = 0; d < days; d++) {
      sum += spendHistory[Math.floor(rng() * spendHistory.length)];
    }
    if (sum <= limit) {
      successes++;
    }
  }

  const reachProbability = Math.round((successes / paths) * 1000) / 1000;

  return { perDay, approximate: false, reachProbability, paths };
}
