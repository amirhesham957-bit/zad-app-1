/**
 * Google Search grounding through one paid key (owner, 2026-10-18).
 *
 * Grounding is not on the free tier for Gemini 3+: from 2026-10-05 every grounded call on the
 * ten free keys answered 429, and each search still spent up to eight of them before falling
 * through. The owner linked a billed project's key as `ZAD_SEARCH_KEY`. With it set, grounding
 * runs on that key alone; the free pool is never asked for grounding again. Without it,
 * grounding stays off unless `ZAD_GROUNDED_SEARCH=on` (the old free-pool behaviour, kept only
 * as an explicit switch).
 *
 * The paid project gives 5,000 grounded prompts a month free, then bills per thousand. A daily
 * cap (`ZAD_SEARCH_DAILY_CAP`, default 150 ≈ 4,500 a month) is taken from the database before
 * every paid call, so many function instances share one count.
 */

export type Env = (name: string) => string | undefined;

/** Which keys may run a grounded search, and whether they are the paid one. */
export interface GroundingPlan {
  keys: string[];
  paid: boolean;
}

export const DEFAULT_DAILY_CAP = 150;

/** The paid key, trimmed; null when unset or blank. */
export function paidSearchKey(env: Env): string | null {
  const k = (env("ZAD_SEARCH_KEY") ?? "").trim();
  return k.length > 0 ? k : null;
}

/** Null = grounding off. The paid key wins; the free pool only behind the explicit switch. */
export function groundingPlan(
  env: Env,
  freeKeys: string[],
): GroundingPlan | null {
  const paid = paidSearchKey(env);
  if (paid) return { keys: [paid], paid: true };
  if (env("ZAD_GROUNDED_SEARCH") === "on" && freeKeys.length > 0) {
    return { keys: freeKeys, paid: false };
  }
  return null;
}

/** The daily cap, from the secret when it is a positive whole number. */
export function dailyCap(env: Env): number {
  const n = Number((env("ZAD_SEARCH_DAILY_CAP") ?? "").trim());
  return Number.isInteger(n) && n > 0 ? n : DEFAULT_DAILY_CAP;
}

/** Calls `zad_search_budget_take`; the caller passes the RPC so tests need no database. */
export type BudgetRpc = (
  fn: string,
  args: Record<string, unknown>,
) => Promise<{ data: unknown; error: { message: string } | null }>;

/**
 * One paid search from today's budget. Fails closed: a database error spends nothing on
 * Google and the caller falls through to the free sources — the bill is the thing guarded.
 */
export async function takeSearchBudget(
  rpc: BudgetRpc,
  cap: number,
): Promise<boolean> {
  try {
    const { data, error } = await rpc("zad_search_budget_take", { p_cap: cap });
    if (error) {
      console.warn(
        "[paidSearch] budget check failed, not searching:",
        error.message,
      );
      return false;
    }
    return data === true;
  } catch (e) {
    console.warn(
      "[paidSearch] budget check threw, not searching:",
      (e as Error)?.message ?? e,
    );
    return false;
  }
}

/** What the paid searches have spent: today, the last seven days, and this month (UTC). */
export interface BudgetUsage {
  daily_cap: number;
  today: number;
  last_7_days: number;
  month: number;
  monthly_free: number;
}

/** The free grounded prompts the paid project gets each month, before billing. */
export const MONTHLY_FREE = 5000;

/** Sums `zad_search_budget` rows; `today` is the UTC date as YYYY-MM-DD. */
export function budgetUsage(
  rows: { day: string; used: number }[],
  today: string,
  cap: number,
): BudgetUsage {
  const weekStart = new Date(Date.parse(`${today}T00:00:00Z`) - 6 * 86400_000)
    .toISOString().slice(0, 10);
  const monthStart = `${today.slice(0, 7)}-01`;
  let t = 0, w = 0, m = 0;
  for (const r of rows) {
    const used = Number(r.used) || 0;
    if (r.day === today) t += used;
    if (r.day >= weekStart && r.day <= today) w += used;
    if (r.day >= monthStart && r.day <= today) m += used;
  }
  return { daily_cap: cap, today: t, last_7_days: w, month: m, monthly_free: MONTHLY_FREE };
}

/**
 * Where the paid grounded search sits in the source chain (2026-10-18). Behind the free sources,
 * a question about today or «the last time» was answered by whatever they had: the acceptance
 * probe's «مين كسب كاس العالم للأندية آخر مرة؟» got Wikipedia's 2023 winner. With the paid key
 * set, a live or «latest» question asks it first; the daily cap still guards the bill. Anything
 * else keeps the free sources first, so the budget goes where freshness is the answer.
 */
export function withPaidGroundingFirst<T extends [string, unknown]>(sources: T[], paid: boolean, fresh: boolean): T[] {
  if (!paid || !fresh) return sources;
  const grounded = sources.filter(([name]) => name === "gemini_google_search");
  return [...grounded, ...sources.filter(([name]) => name !== "gemini_google_search")];
}

/**
 * A refusal about the key or its Google Cloud project, not about the model (2026-10-18): from
 * 17:38 that day every paid call answered 403 «Gemini API has not been used in project … or it
 * is disabled». Every model on that key answers the same, so walking the four models only spent
 * four units of the daily cap and four round trips per search. One such answer stops the walk.
 */
export function keyRefused(status: number, body: string): boolean {
  if (status === 401 || status === 403) return true;
  return status === 400 && /API_KEY_INVALID|API key not valid/i.test(body);
}

/** How long a refused key rests before it is asked again: the owner fixes it in a console. */
export const KEY_REST_MS = 30 * 60 * 1000;
