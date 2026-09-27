// شيف زاد من جوه الشات — أداة suggest_recipes.
//
// العقل كان شايف المخزون وملاحظة «استخدمه قبل ما يخلص» بس، ومالوش طريق للشيف نفسه:
// «أطبخ إيه النهارده؟» كانت بتتجاوب من دماغ الموديل مش من شيف زاد. دلوقتي الأداة بتنادي
// نفس meal_suggestions اللي صفحة الشيف بتناديه (zad-core-intelligence) — نفس البرومبت،
// نفس آراء العميل في الوصفات، نفس وضع الطوارئ، نفس الكاش — بمخزون الـsnapshot.
//
// الدوال هنا نقية عشان تتختبر من غير شبكة؛ النداء نفسه في index.ts.

/** صف مخزون زي ما buildSnapshot بيبنيه (`snap.stock`). */
export interface ChefStockRow {
  name: string;
  qty: number;
  unit?: string | null;
}

/**
 * المخزون بنفس شكل `pantryForChef` في فلاتر: «اسم (كمية)» مفصولة بفاصلة، الموجود بس.
 * نفس الشكل = نفس مفتاح كاش meal_suggestions، فسؤال الشات وفتح صفحة الشيف على نفس
 * المخزون بيدفعوا نداء موديل واحد مش اتنين.
 */
export function pantryForChef(stock: ChefStockRow[] | null | undefined): string {
  return (stock ?? [])
    .filter((s) => typeof s?.name === "string" && s.name.trim() && Number(s.qty) > 0)
    .map((s) => `${s.name.trim()} (${Number(s.qty)})`)
    .join(", ");
}

interface ChefRecipe {
  recipe_name?: unknown;
  prep_time_minutes?: unknown;
  cost_estimate?: unknown;
  missing_ingredients_to_buy?: unknown;
  from_inventory?: unknown;
}

/**
 * رد meal_suggestions → نص قصير للموديل يعرضه. كل رقم فيه جاي من رد الشيف نفسه، والموديل
 * بيتقال صراحة يعرض من القايمة دي بس — مايخترعش وصفة من عنده جنبها.
 */
export function formatChefResult(result: unknown, currency = ""): string {
  const r = (result ?? {}) as { text?: unknown; recipes?: unknown; ok?: unknown };
  const recipes = Array.isArray(r.recipes) ? (r.recipes as ChefRecipe[]) : [];
  const intro = typeof r.text === "string" ? r.text.trim() : "";
  if (!recipes.length) {
    return intro
      ? `شيف زاد: ${intro}\n(مفيش وصفات مناسبة من المخزون الحالي — ماتخترعش وصفة.)`
      : "شيف زاد مارجّعش وصفات دلوقتي. قول للعميل بصراحة واعرض يفتح صفحة الشيف (app_command screen=recipes).";
  }
  const lines = recipes.slice(0, 6).map((x, i) => {
    const name = String(x.recipe_name ?? "").trim() || `وصفة ${i + 1}`;
    const missing = Array.isArray(x.missing_ingredients_to_buy)
      ? (x.missing_ingredients_to_buy as unknown[]).map((m) => String(m).trim()).filter(Boolean)
      : [];
    const parts = [
      x.from_inventory === true || missing.length === 0 ? "مكتملة من المخزون" : `ناقصها: ${missing.join("، ")}`,
    ];
    const minutes = Number(x.prep_time_minutes);
    if (Number.isFinite(minutes) && minutes > 0) parts.push(`${Math.round(minutes)} دقيقة`);
    const cost = Number(x.cost_estimate);
    if (Number.isFinite(cost) && cost > 0) parts.push(`حوالي ${Math.round(cost)}${currency ? ` ${currency}` : ""}`);
    return `${i + 1}. ${name} — ${parts.join(" · ")}`;
  });
  return [
    ...(intro ? [`شيف زاد: ${intro}`] : []),
    "وصفات شيف زاد (اعرض من دول بس، باختصار، والمكتملة من المخزون الأول):",
    ...lines,
    "لو العميل عاوز الخطوات أو يضيف الناقص لقايمة الشراء: افتحله صفحة الشيف (app_command screen=recipes).",
  ].join("\n");
}
