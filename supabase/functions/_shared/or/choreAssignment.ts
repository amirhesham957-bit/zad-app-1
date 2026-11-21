// choreAssignment.ts — minimum-cost chore assignment using the Hungarian algorithm.

/** Assign every row to at most one column, minimizing the total cost. */
export function hungarian(cost: readonly (readonly number[])[]): number[] {
  const rows = cost.length;
  if (rows === 0) return [];

  const cols = cost[0].length;
  for (const row of cost) {
    if (row.length !== cols) throw new RangeError("Cost matrix must be rectangular");
    for (const value of row) {
      if (!Number.isFinite(value)) throw new RangeError("Cost matrix entries must be finite");
    }
  }

  // Pad with zero-cost workers/jobs so the same square algorithm handles both
  // rectangular orientations. Padding columns are reported as unassigned (-1).
  const n = Math.max(rows, cols);
  const a = Array.from({ length: n }, (_, r) =>
    Array.from({ length: n }, (_, c) => r < rows && c < cols ? cost[r][c] : 0)
  );

  // Potentials and matching use the 1-indexed Kuhn–Munkres formulation.
  const u = new Array<number>(n + 1).fill(0);
  const v = new Array<number>(n + 1).fill(0);
  const p = new Array<number>(n + 1).fill(0);
  const way = new Array<number>(n + 1).fill(0);

  for (let i = 1; i <= n; i++) {
    p[0] = i;
    let j0 = 0;
    const minv = new Array<number>(n + 1).fill(Infinity);
    const used = new Array<boolean>(n + 1).fill(false);

    do {
      used[j0] = true;
      const i0 = p[j0];
      let delta = Infinity;
      let j1 = 0;

      for (let j = 1; j <= n; j++) {
        if (used[j]) continue;
        const cur = a[i0 - 1][j - 1] - u[i0] - v[j];
        if (cur < minv[j]) {
          minv[j] = cur;
          way[j] = j0;
        }
        if (minv[j] < delta) {
          delta = minv[j];
          j1 = j;
        }
      }

      for (let j = 0; j <= n; j++) {
        if (used[j]) {
          u[p[j]] += delta;
          v[j] -= delta;
        } else {
          minv[j] -= delta;
        }
      }
      j0 = j1;
    } while (p[j0] !== 0);

    do {
      const j1 = way[j0];
      p[j0] = p[j1];
      j0 = j1;
    } while (j0 !== 0);
  }

  const assign = new Array<number>(rows).fill(-1);
  for (let j = 1; j <= n; j++) {
    const row = p[j] - 1;
    if (row >= 0 && row < rows) assign[row] = j <= cols ? j - 1 : -1;
  }
  return assign;
}

export interface Chore {
  id: string;
  minutes: number;
}

export interface Member {
  id: string;
  minutesBudget: number;
  dislikes?: readonly string[];
}

export const DISLIKE_PENALTY = 30;

export interface ChorePlan {
  assignments: { choreId: string; memberId: string }[];
  unassigned: string[];
  totalCost: number;
}

const FORBIDDEN_COST = 1e9;

/** Assign at most one chore to each member in a single round. */
export function assignChores(chores: readonly Chore[], members: readonly Member[]): ChorePlan {
  const choreIds = new Set<string>();
  for (const chore of chores) {
    if (choreIds.has(chore.id)) throw new RangeError(`Duplicate chore id: ${chore.id}`);
    choreIds.add(chore.id);
    if (!Number.isFinite(chore.minutes) || chore.minutes < 0) {
      throw new RangeError("Chore minutes must be finite and non-negative");
    }
  }

  const memberIds = new Set<string>();
  for (const member of members) {
    if (memberIds.has(member.id)) throw new RangeError(`Duplicate member id: ${member.id}`);
    memberIds.add(member.id);
    if (!Number.isFinite(member.minutesBudget) || member.minutesBudget < 0) {
      throw new RangeError("Member minutes budget must be finite and non-negative");
    }
  }

  // Chores are rows and members are columns, so the result is already in chore
  // order. Extra chores receive a padding column and are therefore unassigned.
  const costs = chores.map((chore) =>
    members.map((member) => {
      if (chore.minutes > member.minutesBudget) return FORBIDDEN_COST;
      const dislikes = member.dislikes ?? [];
      return chore.minutes + (dislikes.includes(chore.id) ? DISLIKE_PENALTY : 0);
    })
  );
  const memberForChore = hungarian(costs);
  const assignments: ChorePlan["assignments"] = [];
  const unassigned: string[] = [];
  let totalCost = 0;

  for (let choreIndex = 0; choreIndex < chores.length; choreIndex++) {
    const memberIndex = memberForChore[choreIndex];
    const chore = chores[choreIndex];
    if (memberIndex < 0 || chore.minutes > members[memberIndex].minutesBudget) {
      unassigned.push(chore.id);
      continue;
    }

    assignments.push({ choreId: chore.id, memberId: members[memberIndex].id });
    totalCost += costs[choreIndex][memberIndex];
  }

  return { assignments, unassigned, totalCost };
}
