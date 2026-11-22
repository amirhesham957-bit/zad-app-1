// Backtest (م٨.٣): إعادة تشغيل متدحرجة (rolling origin) على تاريخ كل بيت قبل أي نشر.
// دوال صافية: من غير شبكة ولا قاعدة بيانات. التنبؤ بيشوف الأحداث اللي قبل t بس.

import { type ForecastOutcome, coverage, mae } from "./forecastAccuracy.ts";
import { type DeployDecision, type ModelGateOptions, type ModelStats, shouldDeploy } from "./modelGate.ts";

export interface BacktestEvent {
  /** رقم اليوم (أو أي ترتيب زمني تصاعدي). */
  t: number;
  value: number;
}

export interface Prediction {
  predicted: number;
  low?: number;
  high?: number;
}

/** المتنبّئ: بياخد التاريخ السابق بس (مجمّد) والـt المطلوب التنبؤ بيه. */
export type Predictor = (history: readonly BacktestEvent[], t: number) => Prediction;

export interface BacktestOptions {
  /** أقل عدد أحداث للتدريب قبل أول تنبؤ (الافتراضي ٧). */
  minTrain?: number;
}

export interface HouseholdMetrics {
  n: number;
  mae: number | null;
  /** MAPE كنسبة (٠.١ = ١٠٪). بيتجاهل الصفوف اللي actual فيها صفر. */
  mape: number | null;
  mapeSkipped: number;
  coverage: number | null;
}

export interface HouseholdBacktest {
  id: string;
  rows: ForecastOutcome[];
  metrics: HouseholdMetrics;
}

export interface BacktestResult {
  households: HouseholdBacktest[];
  aggregate: HouseholdMetrics;
}

export interface Household {
  id: string;
  events: readonly BacktestEvent[];
}

function metricsOf(rows: readonly ForecastOutcome[]): HouseholdMetrics {
  let sum = 0;
  let used = 0;
  for (const r of rows) {
    if (r.actual > 0) {
      sum += Math.abs(r.predicted - r.actual) / r.actual;
      used++;
    }
  }
  return {
    n: rows.length,
    mae: mae(rows),
    mape: used === 0 ? null : sum / used,
    mapeSkipped: rows.length - used,
    coverage: coverage(rows),
  };
}

function checkOrdered(events: readonly BacktestEvent[], id: string): void {
  for (let i = 0; i < events.length; i++) {
    const e = events[i];
    if (!Number.isFinite(e.t) || !Number.isFinite(e.value) || e.value < 0) {
      throw new RangeError(`household ${id}: invalid event at index ${i}`);
    }
    if (i > 0 && e.t < events[i - 1].t) {
      throw new RangeError(`household ${id}: events must be ordered by t`);
    }
  }
}

/** Walk-forward: لكل نقطة i >= minTrain، المتنبّئ بيشوف events[0..i) بس. */
export function backtest(
  households: readonly Household[],
  predictor: Predictor,
  opts?: BacktestOptions,
): BacktestResult {
  const minTrain = opts?.minTrain ?? 7;
  if (!Number.isInteger(minTrain) || minTrain < 0) {
    throw new RangeError("minTrain must be a non-negative integer");
  }
  const out: HouseholdBacktest[] = [];
  const all: ForecastOutcome[] = [];
  for (const h of households) {
    checkOrdered(h.events, h.id);
    const rows: ForecastOutcome[] = [];
    for (let i = minTrain; i < h.events.length; i++) {
      const target = h.events[i];
      const history = Object.freeze(h.events.slice(0, i).map((e) => Object.freeze({ ...e })));
      const p = predictor(history, target.t);
      if (!Number.isFinite(p.predicted)) {
        throw new RangeError(`household ${h.id}: predictor returned non-finite value`);
      }
      const row: ForecastOutcome = { predicted: Math.max(0, p.predicted), actual: target.value };
      if (p.low !== undefined && p.high !== undefined) {
        row.low = Math.max(0, p.low);
        row.high = Math.max(0, p.high);
      }
      rows.push(row);
    }
    all.push(...rows);
    out.push({ id: h.id, rows, metrics: metricsOf(rows) });
  }
  return { households: out, aggregate: metricsOf(all) };
}

export interface BacktestComparison {
  candidate: BacktestResult;
  baseline: BacktestResult;
  /** شكل مدخلات shouldDeploy (modelGate). */
  candidateStats: ModelStats;
  baselineStats: ModelStats;
  /** baseline.mae - candidate.mae (موجب = المرشح أدق). */
  maeImprovement: number | null;
  /** عدد البيوت اللي المرشح فيها أدق. */
  householdsImproved: number;
  /** null لو مافيش عيّنة. */
  decision: DeployDecision | null;
}

export function compareBacktests(
  households: readonly Household[],
  candidate: { version: string; predict: Predictor },
  baseline: { version: string; predict: Predictor },
  opts?: BacktestOptions & ModelGateOptions,
): BacktestComparison {
  const c = backtest(households, candidate.predict, opts);
  const b = backtest(households, baseline.predict, opts);
  const cm = c.aggregate.mae;
  const bm = b.aggregate.mae;
  const candidateStats: ModelStats = { version: candidate.version, mae: cm ?? 0, n: c.aggregate.n };
  const baselineStats: ModelStats = { version: baseline.version, mae: bm ?? 0, n: b.aggregate.n };
  let improved = 0;
  c.households.forEach((h, i) => {
    const hb = b.households[i].metrics.mae;
    if (h.metrics.mae !== null && hb !== null && h.metrics.mae < hb) improved++;
  });
  return {
    candidate: c,
    baseline: b,
    candidateStats,
    baselineStats,
    maeImprovement: cm === null || bm === null ? null : bm - cm,
    householdsImproved: improved,
    decision: cm === null || bm === null ? null : shouldDeploy(candidateStats, baselineStats, opts),
  };
}

// ---------- بيوت اصطناعية ----------

export interface Persona {
  id: string;
  householdSize: number;
  /** استهلاك الفرد في اليوم. */
  ratePerPersonPerDay: number;
  /** احتمال يوم من غير استهلاك (٠..١). */
  intermittency: number;
  days: number;
  /** تذبذب نسبي حوالين المتوسط (٠..١). الافتراضي ٠.٢. */
  noise?: number;
}

/** PRNG حتمي (mulberry32). */
export function seededRng(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export function generateHousehold(persona: Persona, seed: number): Household {
  const { householdSize, ratePerPersonPerDay, intermittency, days } = persona;
  const noise = persona.noise ?? 0.2;
  if (!(householdSize > 0) || !(ratePerPersonPerDay >= 0) || !(days >= 0)) {
    throw new RangeError("invalid persona");
  }
  if (!(intermittency >= 0 && intermittency <= 1) || !(noise >= 0 && noise <= 1)) {
    throw new RangeError("intermittency and noise must be within 0..1");
  }
  const rng = seededRng(seed);
  const mean = householdSize * ratePerPersonPerDay;
  const events: BacktestEvent[] = [];
  for (let t = 0; t < days; t++) {
    const skip = rng() < intermittency;
    const jitter = 1 + (rng() * 2 - 1) * noise;
    events.push({ t, value: skip ? 0 : Math.max(0, Math.round(mean * jitter * 100) / 100) });
  }
  return { id: persona.id, events };
}

export function generateHouseholds(personas: readonly Persona[], seed: number): Household[] {
  return personas.map((p, i) => generateHousehold(p, seed + i * 7919));
}
