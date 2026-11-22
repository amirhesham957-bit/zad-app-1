import type { ItemForecast } from "./tsb.ts";

/** Multiplier applied when a customer says consumption is faster than forecast. */
export const TAP_FACTOR = 1.3;

/** Direction of a customer's rate correction. */
export type Tap = "faster" | "slower";

const HOUR_MS = 60 * 60 * 1000;
const DAY_MS = 24 * HOUR_MS;

function round4(value: number): number {
  return Math.round(value * 1e4) / 1e4;
}

function validateForecast(f: ItemForecast): void {
  for (const [name, value] of [["rate", f.rate], ["low", f.low], ["high", f.high]] as const) {
    if (!Number.isFinite(value) || value < 0) {
      throw new RangeError(`${name} must be finite and >= 0: ${value}`);
    }
  }
}

function validateQuantity(name: string, value: number): void {
  if (!Number.isFinite(value) || value < 0) {
    throw new RangeError(`${name} must be finite and >= 0: ${value}`);
  }
}

/** Applies a faster/slower tap to the rate and its confidence band. */
export function tapCorrection(f: ItemForecast, tap: Tap): ItemForecast {
  if (tap !== "faster" && tap !== "slower") {
    throw new RangeError(`Unknown tap: ${tap}`);
  }
  validateForecast(f);

  const factor = tap === "faster" ? TAP_FACTOR : 1 / TAP_FACTOR;
  return {
    ...f,
    rate: round4(f.rate * factor),
    low: round4(f.low * factor),
    high: round4(f.high * factor),
  };
}

/** Blends a newly observed stock level into the forecast and its confidence band. */
export function levelCorrection(
  f: ItemForecast,
  prevQty: number,
  prevAtMs: number,
  nowQty: number,
  nowMs: number,
): ItemForecast {
  validateQuantity("prevQty", prevQty);
  validateQuantity("nowQty", nowQty);
  if (!Number.isFinite(prevAtMs) || !Number.isFinite(nowMs)) {
    throw new RangeError("timestamps must be finite");
  }
  if (nowMs < prevAtMs) {
    throw new RangeError("nowMs must not be before prevAtMs");
  }

  const elapsedMs = nowMs - prevAtMs;
  if (elapsedMs < HOUR_MS || nowQty >= prevQty) return f;

  validateForecast(f);
  const elapsedDays = elapsedMs / DAY_MS;
  const implied = (prevQty - nowQty) / elapsedDays;
  const w = Math.max(f.days, 1);
  const rate = (w * f.rate + elapsedDays * implied) / (w + elapsedDays);
  const low = f.rate === 0 ? rate * 0.5 : rate * (f.low / f.rate);
  const high = f.rate === 0 ? rate * 1.5 : rate * (f.high / f.rate);
  const days = f.days + 1;

  return {
    ...f,
    rate: round4(rate),
    low: round4(low),
    high: round4(high),
    days,
    basis: days >= 14 ? "observed" : "blended",
  };
}
