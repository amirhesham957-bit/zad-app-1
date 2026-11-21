export interface ForecastOutcome {
  predicted: number;
  actual: number;
  low?: number;
  high?: number;
}

function validateRow(row: ForecastOutcome): void {
  const check = (n: number | undefined) => {
    if (n !== undefined && (!Number.isFinite(n) || n < 0)) {
      throw new RangeError("Invalid forecast value: must be non-negative and finite");
    }
  };
  check(row.predicted);
  check(row.actual);
  check(row.low);
  check(row.high);
}

export function mae(rows: readonly ForecastOutcome[]): number | null {
  if (rows.length === 0) return null;
  rows.forEach(validateRow);
  const sum = rows.reduce((acc, row) => acc + Math.abs(row.actual - row.predicted), 0);
  return sum / rows.length;
}

export function wape(rows: readonly ForecastOutcome[]): number | null {
  if (rows.length === 0) return null;
  rows.forEach(validateRow);
  const sumActual = rows.reduce((acc, row) => acc + row.actual, 0);
  if (sumActual === 0) return null;
  const sumAbsDiff = rows.reduce((acc, row) => acc + Math.abs(row.actual - row.predicted), 0);
  return sumAbsDiff / sumActual;
}

export function bias(rows: readonly ForecastOutcome[]): number | null {
  if (rows.length === 0) return null;
  rows.forEach(validateRow);
  const sumActual = rows.reduce((acc, row) => acc + row.actual, 0);
  if (sumActual === 0) return null;
  const sumDiff = rows.reduce((acc, row) => acc + (row.predicted - row.actual), 0);
  return sumDiff / sumActual;
}

export function coverage(rows: readonly ForecastOutcome[]): number | null {
  rows.forEach(validateRow);
  const bandRows = rows.filter((row) => row.low !== undefined && row.high !== undefined);
  if (bandRows.length === 0) return null;
  const covered = bandRows.filter((row) => row.low! <= row.actual && row.actual <= row.high!).length;
  return covered / bandRows.length;
}

export interface AccuracyReport {
  n: number;
  mae: number | null;
  wape: number | null;
  bias: number | null;
  coverage: number | null;
  accuracyPct: number | null;
}

function round4(n: number | null): number | null {
  return n === null ? null : Math.round(n * 1e4) / 1e4;
}

export function accuracyReport(rows: readonly ForecastOutcome[]): AccuracyReport {
  const m = mae(rows);
  const w = wape(rows);
  const b = bias(rows);
  const c = coverage(rows);
  return {
    n: rows.length,
    mae: round4(m),
    wape: round4(w),
    bias: round4(b),
    coverage: round4(c),
    accuracyPct: w === null ? null : Math.round(Math.max(0, 1 - w) * 100),
  };
}
