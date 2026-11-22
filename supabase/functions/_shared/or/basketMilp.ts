// م٥.٣: السلة على المحلات. كل صنف يتشرى من محل واحد، والهدف أقل (سعر + رسوم توصيل)،
// مع الحد الأدنى للطلب وأقصى عدد محلات. نقي: من غير DB ولا شبكة. الحل بـHiGHS عبر lp.ts.
// البديل (greedy): أرخص محل لكل صنف لما البيانات مش كافية، والمخرج بيقول أنهي مسار اشتغل.
import { type LpConstraint, type LpModel, solveLp } from "./lp.ts";

export interface BasketItem {
  name: string;
  qty: number;
}

export interface StoreOffer {
  /** سعر الوحدة. غايب أو مش رقم موجب = الصنف مش متاح. */
  price?: number | null;
  available?: boolean;
}

export interface BasketStore {
  name: string;
  /** مفتاحها اسم الصنف. */
  offers: Record<string, StoreOffer>;
  deliveryFee?: number;
  minOrder?: number;
}

export interface BasketInput {
  items: BasketItem[];
  stores: BasketStore[];
  maxStores?: number;
}

export type BasketPath = "milp" | "greedy";

export interface BasketLine {
  item: string;
  store: string;
  qty: number;
  unitPrice: number;
  cost: number;
}

export interface BasketResult {
  path: BasketPath;
  /** سبب البديل لو path=greedy. */
  fallbackReason?: "thin_price_data" | "solver_infeasible" | "solver_unavailable";
  lines: BasketLine[];
  /** أصناف مفيش ولا محل بيوفرها (أو كميتها غلط). */
  unavailable: string[];
  storesUsed: string[];
  itemsCost: number;
  fees: number;
  total: number;
  /** محلات تحت الحد الأدنى للطلب (بتظهر في البديل بس). */
  minOrderViolations: string[];
}

const r2 = (n: number) => Math.round(n * 100) / 100;

function unitPrice(s: BasketStore, item: string): number | null {
  const o = s.offers[item];
  if (!o || o.available === false) return null;
  const p = o.price;
  return typeof p === "number" && Number.isFinite(p) && p > 0 ? p : null;
}

function summarize(
  input: BasketInput,
  pick: Map<number, number>,
  unavailable: string[],
  path: BasketPath,
  fallbackReason?: BasketResult["fallbackReason"],
): BasketResult {
  const lines: BasketLine[] = [];
  const perStore = new Map<number, number>();
  for (const [i, s] of pick) {
    const it = input.items[i];
    const up = unitPrice(input.stores[s], it.name)!;
    const cost = up * it.qty;
    lines.push({ item: it.name, store: input.stores[s].name, qty: it.qty, unitPrice: up, cost: r2(cost) });
    perStore.set(s, (perStore.get(s) ?? 0) + cost);
  }
  let fees = 0;
  const violations: string[] = [];
  for (const [s, sub] of perStore) {
    fees += input.stores[s].deliveryFee ?? 0;
    if (sub < (input.stores[s].minOrder ?? 0)) violations.push(input.stores[s].name);
  }
  const itemsCost = [...perStore.values()].reduce((a, b) => a + b, 0);
  return {
    path,
    ...(fallbackReason ? { fallbackReason } : {}),
    lines,
    unavailable,
    storesUsed: [...perStore.keys()].map((s) => input.stores[s].name),
    itemsCost: r2(itemsCost),
    fees: r2(fees),
    total: r2(itemsCost + fees),
    minOrderViolations: violations,
  };
}

function greedy(
  input: BasketInput,
  covered: number[],
  unavailable: string[],
  reason: BasketResult["fallbackReason"],
): BasketResult {
  const pick = new Map<number, number>();
  for (const i of covered) {
    let best = -1;
    let bp = Infinity;
    input.stores.forEach((s, si) => {
      const p = unitPrice(s, input.items[i].name);
      if (p !== null && p < bp) {
        bp = p;
        best = si;
      }
    });
    pick.set(i, best);
  }
  return summarize(input, pick, unavailable, "greedy", reason);
}

/** تخصيص الأصناف على المحلات بأقل تكلفة كلية. مابيرميش على بيانات ناقصة: بيرجع البديل. */
export async function planBasket(input: BasketInput): Promise<BasketResult> {
  const covered: number[] = [];
  const unavailable: string[] = [];
  let thin = false;
  input.items.forEach((it, i) => {
    if (!(it.qty > 0) || !Number.isFinite(it.qty)) {
      unavailable.push(it.name);
      return;
    }
    const n = input.stores.filter((s) => unitPrice(s, it.name) !== null).length;
    if (n === 0) unavailable.push(it.name);
    else {
      covered.push(i);
      if (n < 2) thin = true;
    }
  });
  if (covered.length === 0) return summarize(input, new Map(), unavailable, "greedy", "thin_price_data");
  if (thin) return greedy(input, covered, unavailable, "thin_price_data");

  const vars: LpModel["vars"] = [];
  const objective: Record<string, number> = {};
  const constraints: LpConstraint[] = [];
  const xName = (i: number, s: number) => `x${i}_${s}`;
  input.stores.forEach((s, si) => {
    vars.push({ name: `y${si}`, ub: 1, integer: true });
    objective[`y${si}`] = s.deliveryFee ?? 0;
  });
  const minTerms = new Map<number, Record<string, number>>();
  for (const i of covered) {
    const assign: Record<string, number> = {};
    input.stores.forEach((s, si) => {
      const p = unitPrice(s, input.items[i].name);
      if (p === null) return;
      const x = xName(i, si);
      vars.push({ name: x, ub: 1, integer: true });
      objective[x] = p * input.items[i].qty;
      assign[x] = 1;
      constraints.push({ name: `l${i}_${si}`, terms: { [x]: 1, [`y${si}`]: -1 }, op: "<=", rhs: 0 });
      const t = minTerms.get(si) ?? {};
      t[x] = p * input.items[i].qty;
      minTerms.set(si, t);
    });
    constraints.push({ name: `a${i}`, terms: assign, op: "=", rhs: 1 });
  }
  for (const [si, t] of minTerms) {
    const mo = input.stores[si].minOrder ?? 0;
    if (mo > 0) constraints.push({ name: `m${si}`, terms: { ...t, [`y${si}`]: -mo }, op: ">=", rhs: 0 });
  }
  if (input.maxStores !== undefined && input.maxStores >= 1) {
    const t: Record<string, number> = {};
    input.stores.forEach((_, si) => t[`y${si}`] = 1);
    constraints.push({ name: "cap", terms: t, op: "<=", rhs: Math.floor(input.maxStores) });
  }

  let res;
  try {
    res = await solveLp({ sense: "min", objective, vars, constraints });
  } catch {
    return greedy(input, covered, unavailable, "solver_unavailable");
  }
  if (res.status !== "optimal") return greedy(input, covered, unavailable, "solver_infeasible");

  const pick = new Map<number, number>();
  for (const i of covered) {
    for (let si = 0; si < input.stores.length; si++) {
      if ((res.values[xName(i, si)] ?? 0) > 0.5) pick.set(i, si);
    }
  }
  return summarize(input, pick, unavailable, "milp");
}
