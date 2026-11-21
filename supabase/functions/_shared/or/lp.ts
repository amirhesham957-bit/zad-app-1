import highsLoader from "npm:highs@1.15.4";

/** A declared variable. Bounds default to 0 and +Infinity; variables are continuous by default. */
export interface LpVar {
  name: string;
  lb?: number;
  ub?: number;
  integer?: boolean;
}

/** A linear constraint keyed by declared variable name. */
export interface LpConstraint {
  name: string;
  terms: Record<string, number>;
  op: "<=" | ">=" | "=";
  rhs: number;
}

/** A linear or mixed-integer linear optimization model. */
export interface LpModel {
  sense: "max" | "min";
  objective: Record<string, number>;
  vars: LpVar[];
  constraints: LpConstraint[];
}

/** The solver status, optimal objective (when available), and variable primal values. */
export interface LpResult {
  status: "optimal" | "infeasible" | "unbounded" | "other";
  objective: number | null;
  values: Record<string, number>;
}

const VAR_NAME = /^[A-Za-z_][A-Za-z0-9_]{0,30}$/;

interface HighsSolution {
  Status: string;
  ObjectiveValue: number;
  Columns: Record<string, { Primal: number }>;
}

interface HighsSolver {
  solve(model: string): HighsSolution;
}

type HighsFactory = () => Promise<HighsSolver>;
let highsPromise: Promise<HighsSolver> | undefined;

function loadHighs(): Promise<HighsSolver> {
  highsPromise ??= (highsLoader as unknown as HighsFactory)();
  return highsPromise;
}

function formatTerms(terms: Record<string, number>): string {
  const entries = Object.entries(terms);
  if (entries.length === 0) return "0";
  return entries.map(([name, coefficient], index) => {
    const term = `${Math.abs(coefficient)} ${name}`;
    if (index === 0) return coefficient < 0 ? `- ${term}` : term;
    return `${coefficient < 0 ? "-" : "+"} ${term}`;
  }).join(" ");
}

function formatBounds(v: LpVar): string {
  const lb = v.lb ?? 0;
  const ub = v.ub ?? Infinity;
  if (lb === -Infinity && ub === Infinity) return `${v.name} free`;
  if (ub === Infinity) return `${v.name} >= ${lb}`;
  if (lb === -Infinity) return `${v.name} <= ${ub}`;
  return `${lb} <= ${v.name} <= ${ub}`;
}

/** Serialize a model as CPLEX LP text, rejecting invalid names and coefficients. */
export function toLpText(m: LpModel): string {
  const declared = new Set<string>();
  for (const v of m.vars) {
    if (!VAR_NAME.test(v.name)) throw new RangeError(`bad variable name: ${v.name}`);
    if (declared.has(v.name)) throw new RangeError(`duplicate variable: ${v.name}`);
    if ((v.lb ?? 0) > (v.ub ?? Infinity)) throw new RangeError(`lower bound exceeds upper bound: ${v.name}`);
    declared.add(v.name);
  }

  for (const name of Object.keys(m.objective)) {
    if (!declared.has(name)) throw new RangeError(`undeclared objective variable: ${name}`);
    if (!Number.isFinite(m.objective[name])) throw new RangeError(`non-finite objective coefficient: ${name}`);
  }
  for (const c of m.constraints) {
    if (!Number.isFinite(c.rhs)) throw new RangeError(`non-finite rhs: ${c.name}`);
    for (const [name, coefficient] of Object.entries(c.terms)) {
      if (!declared.has(name)) throw new RangeError(`undeclared constraint variable: ${name}`);
      if (!Number.isFinite(coefficient)) throw new RangeError(`non-finite constraint coefficient: ${c.name}`);
    }
  }

  const lines = [
    m.sense === "max" ? "Maximize" : "Minimize",
    `  obj: ${formatTerms(m.objective)}`,
    "Subject To",
    ...m.constraints.map((c) => `  ${c.name}: ${formatTerms(c.terms)} ${c.op} ${c.rhs}`),
    "Bounds",
    ...m.vars.map((v) => `  ${formatBounds(v)}`),
  ];
  const integers = m.vars.filter((v) => v.integer);
  if (integers.length > 0) lines.push("General", ...integers.map((v) => `  ${v.name}`));
  lines.push("End");
  return lines.join("\n");
}

/** Solve with the shared HiGHS WASM instance and round returned primal values to 6 decimals. */
export async function solveLp(m: LpModel): Promise<LpResult> {
  const highs = await loadHighs();
  const solution = highs.solve(toLpText(m));
  const status = solution.Status === "Optimal"
    ? "optimal"
    : solution.Status === "Infeasible"
    ? "infeasible"
    : solution.Status === "Unbounded"
    ? "unbounded"
    : "other";
  const values: Record<string, number> = {};
  for (const v of m.vars) {
    const primal = solution.Columns[v.name]?.Primal;
    if (typeof primal !== "number") continue;
    const rounded = Math.round(primal * 1e6) / 1e6;
    values[v.name] = rounded === 0 ? 0 : rounded;
  }
  return {
    status,
    objective: status === "optimal" ? solution.ObjectiveValue : null,
    values,
  };
}
