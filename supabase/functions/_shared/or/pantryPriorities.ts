export type Tier = "essential" | "important" | "luxury";

export const TIER_WEIGHT: Record<Tier, number> = {
  essential: 100,
  important: 10,
  luxury: 1,
};

export interface RestockItem {
  id: string;
  price: number;
  tier: Tier;
  daysLeft: number;
}

export interface RestockPlan {
  buy: string[];
  skip: string[];
  spent: number;
  essentialsShort: string[];
}

export function urgency(daysLeft: number): number {
  return 1 / (1 + daysLeft);
}

export function planRestock(
  items: readonly RestockItem[],
  budget: number,
): RestockPlan {
  if (!Number.isFinite(budget) || budget < 0) {
    throw new RangeError("Budget must be finite and non-negative");
  }

  const ids = new Set<string>();
  for (const item of items) {
    if (!Number.isFinite(item.price) || item.price <= 0) {
      throw new RangeError("Price must be finite and greater than zero");
    }
    if (!Number.isFinite(item.daysLeft) || item.daysLeft < 0) {
      throw new RangeError("Days left must be finite and non-negative");
    }
    if (ids.has(item.id)) {
      throw new RangeError("Item ids must be unique");
    }
    ids.add(item.id);
  }

  const toCents = (value: number) => Math.round(value * 100);
  let remainingCents = toCents(budget);
  let spentCents = 0;
  const selected = new Set<string>();
  const essentialsShort: string[] = [];

  const essentials = items
    .map((item, index) => ({ item, index }))
    .filter(({ item }) => item.tier === "essential")
    .sort((a, b) => {
      if (a.item.daysLeft !== b.item.daysLeft) {
        return a.item.daysLeft - b.item.daysLeft;
      }
      if (a.item.id === b.item.id) return a.index - b.index;
      return a.item.id < b.item.id ? -1 : 1;
    });

  for (const { item } of essentials) {
    const cost = toCents(item.price);
    if (cost <= remainingCents) {
      selected.add(item.id);
      remainingCents -= cost;
      spentCents += cost;
    } else {
      essentialsShort.push(item.id);
    }
  }

  const candidates = items.filter((item) =>
    item.tier === "important" || item.tier === "luxury"
  );
  const candidateTotal = candidates.reduce(
    (total, item) => total + toCents(item.price),
    0,
  );
  const capacity = Math.min(remainingCents, candidateTotal);
  const values = new Float64Array(capacity + 1);
  const decisions: Array<Uint8Array | undefined> = new Array(candidates.length);

  candidates.forEach((item, index) => {
    const cost = toCents(item.price);
    if (cost > capacity) return;

    const value = TIER_WEIGHT[item.tier] * urgency(item.daysLeft);
    const row = new Uint8Array(capacity + 1);
    for (let available = capacity; available >= cost; available -= 1) {
      const candidate = values[available - cost] + value;
      if (candidate > values[available]) {
        values[available] = candidate;
        row[available] = 1;
      }
    }
    decisions[index] = row;
  });

  let available = capacity;
  for (let index = candidates.length - 1; index >= 0; index -= 1) {
    const row = decisions[index];
    if (row?.[available] === 1) {
      const item = candidates[index];
      selected.add(item.id);
      spentCents += toCents(item.price);
      available -= toCents(item.price);
    }
  }

  const buy: string[] = [];
  const skip: string[] = [];
  for (const item of items) {
    if (selected.has(item.id)) buy.push(item.id);
    else skip.push(item.id);
  }

  return {
    buy,
    skip,
    spent: spentCents / 100,
    essentialsShort,
  };
}
