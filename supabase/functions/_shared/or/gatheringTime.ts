/**
 * Weekly gathering-time search (ZAD_OR_PLAN م٥.٢). All inputs use minutes since the start of the week
 * in the household's civil time; earliest and latest are local minutes-of-day applied to every day.
 */

export interface Busy {
  member: string;
  start: number;
  end: number;
}

export interface GatheringRules {
  members: readonly string[];
  minutes: number;
  earliest?: number;
  latest?: number;
  step?: number;
  preferred?: ReadonlyArray<{ start: number; end: number; bonus: number }>;
}

export interface GatheringSlot {
  start: number;
  end: number;
  present: string[];
  missing: string[];
  score: number;
}

const DAY_MINUTES = 1440;
const WEEK_DAYS = 7;

/** Return the highest-scoring non-overlapping slots, using half-open interval overlap throughout. */
export function bestGatherings(
  busy: readonly Busy[],
  rules: GatheringRules,
  count = 3,
): GatheringSlot[] {
  const minutes = rules.minutes;
  const earliest = rules.earliest ?? 9 * 60;
  const latest = rules.latest ?? 23 * 60;
  const step = rules.step ?? 30;

  if (!Number.isInteger(minutes) || minutes < 15 || minutes > 360) {
    throw new RangeError(`minutes must be an integer in 15..360: ${minutes}`);
  }
  if (!Number.isInteger(step) || step < 5 || step > 120) {
    throw new RangeError(`step must be an integer in 5..120: ${step}`);
  }
  if (
    !Number.isInteger(earliest) || !Number.isInteger(latest) ||
    earliest < 0 || latest > DAY_MINUTES || earliest >= latest
  ) {
    throw new RangeError(`invalid minutes-of-day bounds: ${earliest}..${latest}`);
  }
  for (const interval of busy) {
    if (interval.end <= interval.start) {
      throw new RangeError(`busy end must be after start for ${interval.member}`);
    }
  }

  const limit = Math.max(0, Math.floor(count));
  if (limit === 0) return [];

  const members = new Set(rules.members);
  const relevantBusy = busy.filter((interval) => members.has(interval.member));
  const candidates: GatheringSlot[] = [];

  for (let day = 0; day < WEEK_DAYS; day++) {
    const dayStart = day * DAY_MINUTES;
    for (let localStart = earliest; localStart <= latest - minutes; localStart += step) {
      const start = dayStart + localStart;
      const end = start + minutes;
      if (end > dayStart + latest || end > dayStart + DAY_MINUTES) continue;

      const present: string[] = [];
      const missing: string[] = [];
      for (const member of rules.members) {
        const blocked = relevantBusy.some((interval) =>
          interval.member === member && interval.start < end && interval.end > start
        );
        (blocked ? missing : present).push(member);
      }

      let bonus = 0;
      for (const window of rules.preferred ?? []) {
        if (start >= window.start && end <= window.end) bonus += window.bonus;
      }
      candidates.push({ start, end, present, missing, score: 100 * present.length + bonus });
    }
  }

  candidates.sort((a, b) => b.score - a.score || a.start - b.start);
  const selected: GatheringSlot[] = [];
  for (const candidate of candidates) {
    if (selected.length >= limit) break;
    const overlaps = selected.some((slot) => candidate.start < slot.end && candidate.end > slot.start);
    if (!overlaps) selected.push(candidate);
  }
  return selected;
}
