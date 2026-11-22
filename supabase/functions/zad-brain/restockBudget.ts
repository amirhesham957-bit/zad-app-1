// م٥.٥ (ZAD_OR_PLAN): أولويات المخزن لما الفلوس قليلة. «معايا ٣٠٠ جنيه، أجيب إيه؟»
//
// المرشحين: أصناف المخزن اللي ميعادها جه (restockVerdict.due) وسطور القايمة اللي لسه ماتشترتش. الطبقة:
// ضروري = isEssential (restockCycle.ts)، مهم = صنف بيتعاد شراه بدورة، كمالي = الباقي. الضروري بيتأمن الأول
// والباقي knapsack بوزن الطبقة × الاستعجال (`_shared/or/pantryPriorities.ts`).
//
// **مفيش سعر مخترع.** السعر يا إما من سطر القايمة (estimated_price) يا إما آخر سعر دفعه البيت نفسه في price_index
// بنفس العملة. الصنف اللي مالوش سعر معروف مابيدخلش الحساب، وبيطلع في «محتاج سعره» عشان العميل يقوله.

import { planRestock, type RestockItem, type Tier } from "../_shared/or/pantryPriorities.ts";
import { priorCycleDays, restockKey, type RestockVerdict } from "../_shared/restockCycle.ts";

/** الفلوس بقرشين بالكتير. */
const asMoney = (n: number) => Math.round(n * 100) / 100;

export type BudgetInventoryRow = { item_name: string | null; verdict: RestockVerdict };
export type BudgetListRow = { item_name: string | null; estimated_price: number | null };
export type PricePaid = { item_name: string | null; price: number | null; timestamp: string | null };

export type Candidate = { name: string; tier: Tier; daysLeft: number; price: number | null; priceSource: "list" | "paid" | null };

export type BudgetPlan = {
  budget: number;
  buy: Array<{ name: string; price: number; tier: Tier; source: "list" | "paid" }>;
  spent: number;
  left: number;
  essentialsShort: Array<{ name: string; price: number }>;
  skipped: Array<{ name: string; price: number; tier: Tier }>;
  needPrice: Array<{ name: string; tier: Tier }>;
};

const TIER_ORDER: Record<Tier, number> = { essential: 0, important: 1, luxury: 2 };

function tierOf(v: RestockVerdict | null, name: string): Tier {
  if (v?.essential) return "essential";
  if (v && v.cycleDays !== null && v.reason !== "occasional" && v.reason !== "not_restocked") return "important";
  if (!v && priorCycleDays(name) !== null) return "important";
  return "luxury";
}

function daysLeftOf(v: RestockVerdict | null): number {
  if (!v) return 3;
  if (v.reason === "empty") return 0;
  if (v.cycleDays !== null && v.daysSinceBought !== null) return Math.max(0, v.cycleDays - v.daysSinceBought);
  return 3;
}

/** آخر سعر دفعه البيت لكل صنف (بالمفتاح المطبّع). */
export function latestPaid(rows: ReadonlyArray<PricePaid>): Map<string, number> {
  const best = new Map<string, { price: number; at: number }>();
  for (const r of rows) {
    const key = restockKey(String(r.item_name ?? ""));
    const price = Number(r.price);
    if (!key || !Number.isFinite(price) || price <= 0) continue;
    const at = Date.parse(r.timestamp ?? "") || 0;
    const cur = best.get(key);
    if (!cur || at > cur.at) best.set(key, { price, at });
  }
  return new Map([...best].map(([k, v]) => [k, v.price]));
}

/** المرشحين: المستحق من المخزن + القايمة، من غير تكرار (القايمة بتكسب في السعر لو العميل كتبه). */
export function budgetCandidates(
  inventory: ReadonlyArray<BudgetInventoryRow>,
  list: ReadonlyArray<BudgetListRow>,
  paid: ReadonlyMap<string, number>,
): Candidate[] {
  const verdicts = new Map<string, RestockVerdict>();
  for (const r of inventory) {
    const key = restockKey(String(r.item_name ?? ""));
    if (key) verdicts.set(key, r.verdict);
  }
  const out = new Map<string, Candidate>();
  for (const r of list) {
    const name = String(r.item_name ?? "").trim();
    const key = restockKey(name);
    if (!key || out.has(key)) continue;
    const v = verdicts.get(key) ?? null;
    const listPrice = Number(r.estimated_price);
    const price = Number.isFinite(listPrice) && listPrice > 0 ? listPrice : paid.get(key) ?? null;
    out.set(key, {
      name, tier: tierOf(v, name), daysLeft: daysLeftOf(v), price,
      priceSource: Number.isFinite(listPrice) && listPrice > 0 ? "list" : price !== null ? "paid" : null,
    });
  }
  for (const r of inventory) {
    const name = String(r.item_name ?? "").trim();
    const key = restockKey(name);
    if (!key || out.has(key) || !r.verdict.due) continue;
    const price = paid.get(key) ?? null;
    out.set(key, { name, tier: tierOf(r.verdict, name), daysLeft: daysLeftOf(r.verdict), price, priceSource: price !== null ? "paid" : null });
  }
  return [...out.values()];
}

export function planOnBudget(candidates: ReadonlyArray<Candidate>, budget: number): BudgetPlan {
  const priced = candidates.filter((c) => c.price !== null);
  const items: RestockItem[] = priced.map((c, i) => ({ id: String(i), price: c.price!, tier: c.tier, daysLeft: c.daysLeft }));
  const plan = planRestock(items, budget);
  const byId = (id: string) => priced[Number(id)];
  const short = new Set(plan.essentialsShort);
  const sortTier = <T extends { tier: Tier }>(xs: T[]) => xs.sort((a, b) => TIER_ORDER[a.tier] - TIER_ORDER[b.tier]);
  return {
    budget,
    buy: sortTier(plan.buy.map((id) => {
      const c = byId(id);
      return { name: c.name, price: c.price!, tier: c.tier, source: c.priceSource! };
    })),
    spent: plan.spent,
    left: asMoney(budget - plan.spent),
    essentialsShort: plan.essentialsShort.map((id) => ({ name: byId(id).name, price: byId(id).price! })),
    skipped: sortTier(plan.skip.filter((id) => !short.has(id)).map((id) => ({ name: byId(id).name, price: byId(id).price!, tier: byId(id).tier }))),
    needPrice: sortTier(candidates.filter((c) => c.price === null).map((c) => ({ name: c.name, tier: c.tier }))),
  };
}

const TIER_LABEL: Record<Tier, string> = { essential: "ضروري", important: "مهم", luxury: "كمالي" };

/** نتيجة الأداة للموديل: كل رقم هنا من الحساب، والموديل بيحكيه بس. */
export function describeBudgetPlan(p: BudgetPlan, currency: string): string {
  const m = (n: number) => `${asMoney(n)} ${currency}`.trim();
  if (!p.buy.length && !p.essentialsShort.length && !p.skipped.length && !p.needPrice.length) {
    return "مفيش حاجة مستحقة في المخزن ولا في القايمة دلوقتي — قول للعميل كده.";
  }
  const lines = [`الميزانية: ${m(p.budget)}.`];
  if (p.buy.length) {
    lines.push(`اشتري (${m(p.spent)}، يفضل ${m(p.left)}):`);
    for (const b of p.buy) lines.push(`- ${b.name} — ${m(b.price)} (${TIER_LABEL[b.tier]}${b.source === "paid" ? "، آخر سعر دفعتوه" : "، من القايمة"})`);
  } else {
    lines.push("مفيش صنف بسعر معروف يدخل في الميزانية دي.");
  }
  if (p.essentialsShort.length) {
    lines.push("ضروري مادخلش في الفلوس (قوله بوضوح):");
    for (const e of p.essentialsShort) lines.push(`- ${e.name} — ${m(e.price)}`);
  }
  if (p.skipped.length) lines.push(`يستنى: ${p.skipped.map((s) => `${s.name} (${m(s.price)})`).join("، ")}.`);
  if (p.needPrice.length) {
    lines.push(`محتاج سعره (مادخلش الحساب): ${p.needPrice.map((n) => `${n.name} (${TIER_LABEL[n.tier]})`).join("، ")}. ` +
      "اسأل العميل عن سعرهم لو عايز يدخلوا، ماتخمنش سعر.");
  }
  lines.push("الأرقام دي بس اللي تتقال. الأسعار آخر سعر معروف عند البيت، مش سعر المحل النهارده.");
  return lines.join("\n");
}
