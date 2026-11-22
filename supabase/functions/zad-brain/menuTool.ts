// م٥.٢ (ZAD_OR_PLAN): منيو الأسبوع على ميزانية. «عاوز منيو ٥ أيام بـ٤٠٠ جنيه: كبسة ١٢٠، فراخ ٨٠، مكرونة ٤٠…»
//
// الأطباق وأسعارها من العميل (مفيش جدول أطباق، ومفيش سعر مخترع). الذوق من `zad_recipe_feedback`: حبّه = ٨،
// ماحبّوش = بيتشال من الاختيار، ومالوش رأي = ٥. الحساب كله في `_shared/or/menuPlan.ts` (HiGHS، الحل الأمثل).

import { type Dish, type MenuPlan, planMenu } from "../_shared/or/menuPlan.ts";

const asMoney = (n: number) => Math.round(n * 100) / 100;
export const MENU_MAX_DISHES = 40;

export type MenuInput = { name: string; cost: number; tags: string[] };
export type Feedback = ReadonlyMap<string, boolean>;

const norm = (s: string) => s.trim().toLowerCase().replace(/\s+/g, " ");

/** نص رفض عربي لو المدخلات غلط، وإلا الأطباق مطبّعة. */
export function parseMenuDishes(raw: unknown): { dishes: MenuInput[] } | { error: string } {
  if (!Array.isArray(raw) || raw.length === 0) return { error: "مرفوض: dishes لازم قايمة أطباق فيها اسم وسعر (من العميل)." };
  if (raw.length > MENU_MAX_DISHES) return { error: `مرفوض: أقصى عدد أطباق ${MENU_MAX_DISHES}.` };
  const seen = new Set<string>();
  const dishes: MenuInput[] = [];
  for (const r of raw as Array<Record<string, unknown>>) {
    const name = String(r?.name ?? "").trim().slice(0, 60);
    const cost = Number(r?.cost);
    if (name.length < 2) return { error: "مرفوض: كل طبق لازم اسم." };
    if (!Number.isFinite(cost) || cost < 0 || cost > 1_000_000) return { error: `مرفوض: سعر «${name}» لازم رقم من العميل.` };
    if (seen.has(norm(name))) continue;
    seen.add(norm(name));
    const tags = Array.isArray(r?.tags) ? (r.tags as unknown[]).map((t) => String(t).trim().slice(0, 20)).filter(Boolean).slice(0, 5) : [];
    dishes.push({ name, cost, tags });
  }
  return { dishes };
}

export const LIKED_TASTE = 8;
export const NEUTRAL_TASTE = 5;

export function feedbackMap(rows: ReadonlyArray<{ recipe_name: string | null; liked: boolean | null }>): Feedback {
  const m = new Map<string, boolean>();
  for (const r of rows) if (r.recipe_name && typeof r.liked === "boolean") m.set(norm(r.recipe_name), r.liked);
  return m;
}

export type MenuResult = { plan: MenuPlan; names: Map<string, string>; dropped: string[]; budget: number; days: number };

export async function buildMenu(
  inputs: readonly MenuInput[],
  feedback: Feedback,
  rules: { days: number; budget: number; maxRepeat?: number; minDistinctTags?: number },
): Promise<MenuResult> {
  const names = new Map<string, string>();
  const dropped: string[] = [];
  const dishes: Dish[] = [];
  inputs.forEach((d, i) => {
    const liked = feedback.get(norm(d.name));
    if (liked === false) {
      dropped.push(d.name);
      return;
    }
    const id = `d${i}`;
    names.set(id, d.name);
    dishes.push({ id, cost: d.cost, taste: liked === true ? LIKED_TASTE : NEUTRAL_TASTE, tags: d.tags });
  });
  const plan = await planMenu(dishes, rules);
  return { plan, names, dropped, budget: rules.budget, days: rules.days };
}

export function describeMenu(r: MenuResult, costs: ReadonlyMap<string, number>, currency: string): string {
  const m = (n: number) => `${asMoney(n)} ${currency}`.trim();
  const lines = [`ميزانية المنيو: ${m(r.budget)} لـ${r.days} أيام.`];
  r.plan.days.forEach((id, i) => {
    if (id === null) lines.push(`يوم ${i + 1}: مفيش طبق يدخل الميزانية.`);
    else lines.push(`يوم ${i + 1}: ${r.names.get(id)} — ${m(costs.get(id) ?? 0)}`);
  });
  lines.push(`الإجمالي: ${m(r.plan.spent)}، يفضل ${m(r.budget - r.plan.spent)}.`);
  if (!r.plan.feasible) lines.push("الميزانية أو الأطباق مش مكفية لكل الأيام أو التنوع المطلوب — قول للعميل بوضوح.");
  if (r.dropped.length) lines.push(`اتشالوا لأن البيت ماحبّهمش: ${r.dropped.join("، ")}.`);
  lines.push("الأرقام دي بس اللي تتقال. الأسعار من العميل نفسه.");
  return lines.join("\n");
}
