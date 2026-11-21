/**
 * TSB (Teunter-Syntetos-Babai) forecast for intermittent demand,
 * with Bayesian shrinkage to a prior and confidence bounds.
 */

/** Parameters for TSB demand smoothing. */
export interface TsbParams {
  alpha: number;
  beta: number;
}

/** Default smoothing parameters for TSB. */
export const TSB_DEFAULTS: TsbParams = {
  alpha: 0.2,
  beta: 0.1,
};

/** Prior belief about item consumption rate. */
export interface Prior {
  dailyRate: number;
  weight: number;
}

/** TSB model state after fitting daily demand series. */
export interface TsbState {
  p: number;
  z: number;
  days: number;
}

/** Forecast basis classification depending on observations count. */
export type ForecastBasis = "prior" | "blended" | "observed";

/** Forecast output including point rate, confidence bounds, and basis. */
export interface ItemForecast {
  rate: number;
  low: number;
  high: number;
  basis: ForecastBasis;
  days: number;
}

/**
 * Fits TSB state from a daily demand history (oldest first).
 * Throws RangeError if any element is negative, NaN, or non-finite.
 */
export function tsbFit(
  daily: readonly number[],
  params: TsbParams = TSB_DEFAULTS,
): TsbState {
  for (let i = 0; i < daily.length; i++) {
    const d = daily[i];
    if (!Number.isFinite(d) || d < 0) {
      throw new RangeError(`Invalid daily demand value at index ${i}: ${d}`);
    }
  }

  const n = daily.length;
  if (n === 0) {
    return { p: 0, z: 0, days: 0 };
  }

  const initLen = Math.min(n, 7);
  let posCount = 0;
  let posSum = 0;

  for (let i = 0; i < initLen; i++) {
    if (daily[i] > 0) {
      posCount++;
      posSum += daily[i];
    }
  }

  let p = posCount / initLen;
  let z = posCount > 0 ? posSum / posCount : 0;

  const { alpha, beta } = params;

  for (let i = 0; i < n; i++) {
    const d = daily[i];
    if (d > 0) {
      p += beta * (1 - p);
      z += alpha * (d - z);
    } else {
      p += beta * (0 - p);
    }
  }

  return { p, z, days: n };
}

/**
 * Returns expected daily demand rate from a TsbState (p * z).
 */
export function tsbRate(s: TsbState): number {
  return s.p * s.z;
}

/**
 * Shrinks observed rate toward a prior rate using weighted average.
 * Returns observed rate if denominator is 0.
 */
export function shrinkRate(
  observed: number,
  days: number,
  prior: Prior,
): number {
  const denom = days + prior.weight;
  if (denom === 0) {
    return observed;
  }
  return (days * observed + prior.weight * prior.dailyRate) / denom;
}

/**
 * Generates an item forecast given daily demand history, prior belief, and TSB parameters.
 */
export function forecastItem(
  daily: readonly number[],
  prior: Prior,
  params: TsbParams = TSB_DEFAULTS,
): ItemForecast {
  const n = daily.length;
  const state = tsbFit(daily, params);
  const obsRate = tsbRate(state);
  const rate = shrinkRate(obsRate, n, prior);

  let basis: ForecastBasis;
  if (n === 0) {
    basis = "prior";
  } else if (n < 14) {
    basis = "blended";
  } else {
    basis = "observed";
  }

  let low: number;
  let high: number;

  if (n < 2) {
    low = rate * 0.5;
    high = rate * 1.5;
  } else {
    let sum = 0;
    for (let i = 0; i < n; i++) {
      sum += daily[i];
    }
    const mean = sum / n;

    let sqDiffSum = 0;
    for (let i = 0; i < n; i++) {
      sqDiffSum += (daily[i] - mean) ** 2;
    }

    const sd = Math.sqrt(sqDiffSum / (n - 1));
    const se = sd / Math.sqrt(n + prior.weight);
    low = Math.max(0, rate - 1.645 * se);
    high = rate + 1.645 * se;
  }

  const round4 = (x: number) => Math.round(x * 1e4) / 1e4;

  return {
    rate: round4(rate),
    low: round4(low),
    high: round4(high),
    basis,
    days: n,
  };
}

/**
 * Calculates days until stock on hand runs empty given a daily consumption rate.
 * Returns null if rate <= 0.
 */
export function daysUntilEmpty(onHand: number, rate: number): number | null {
  if (rate <= 0) {
    return null;
  }
  return Math.max(0, onHand / rate);
}
