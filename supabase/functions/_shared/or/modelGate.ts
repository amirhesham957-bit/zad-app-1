// بوابة نشر النموذج (م٨.٤): ماينفعش ننشر نموذج جديد إلا لو أدق من الحالي وعنده عيّنة كفاية.

export interface ModelStats {
  version: string;
  mae: number;
  n: number;
}

export interface DeployDecision {
  deploy: boolean;
  reason: string;
}

export interface ModelGateOptions {
  minN?: number;
  /** Required relative MAE improvement (0.05 = 5% better). Default 0 = any improvement. */
  margin?: number;
}

function assertValidStats(stats: ModelStats, label: string): void {
  if (!Number.isFinite(stats.mae) || stats.mae < 0) {
    throw new RangeError(`${label}.mae must be finite and non-negative`);
  }
  if (!Number.isFinite(stats.n) || stats.n < 0) {
    throw new RangeError(`${label}.n must be finite and non-negative`);
  }
}

/** Decide whether a candidate model may replace the current one. */
export function shouldDeploy(
  candidate: ModelStats,
  current: ModelStats,
  opts?: ModelGateOptions,
): DeployDecision {
  const minN = opts?.minN ?? 30;
  if (!Number.isFinite(minN) || minN < 0) {
    throw new RangeError("minN must be finite and non-negative");
  }
  const margin = opts?.margin ?? 0;
  if (!Number.isFinite(margin) || margin < 0 || margin >= 1) {
    throw new RangeError("margin must be in [0, 1)");
  }
  assertValidStats(candidate, "candidate");
  assertValidStats(current, "current");

  if (candidate.mae >= current.mae) {
    return {
      deploy: false,
      reason:
        `candidate MAE ${candidate.mae} is not better than current ${current.mae}`,
    };
  }
  if (candidate.mae > current.mae * (1 - margin)) {
    return {
      deploy: false,
      reason:
        `candidate MAE ${candidate.mae} does not beat current ${current.mae} by margin ${margin}`,
    };
  }
  if (candidate.n < minN) {
    return {
      deploy: false,
      reason: `candidate n ${candidate.n} is below minimum ${minN}`,
    };
  }
  return {
    deploy: true,
    reason:
      `candidate ${candidate.version} MAE ${candidate.mae} beats current ${current.version} MAE ${current.mae}`,
  };
}
