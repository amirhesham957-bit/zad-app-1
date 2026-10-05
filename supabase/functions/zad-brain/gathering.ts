// gathering.ts — نمط العزومة (ZAD_LIVING_BRAIN.md §١٠ والشريحة ٣٥، قرار المالك ٢٠٢٦-١٠-٠٥).
//
// «التقاط كلمات الضيافة من الشات تلقائياً لتجهيز قائمة وميزانية المناسبة». التقاط الكلام تلميح نية (specialists.ts)؛ هنا
// الحساب: كميات بالفرد لعزومة غدا/عشا أو قعدة حلو، اللي عندك في البيت منها، ووضع الفلوس — صفر توكنز.
//
// **مفيش إجمالي فلوس مخترع.** `price_index` مالوش عمود وحدة (سعر الرز ده للكيلو ولا للشيكارة؟)، فضرب الكيلوهات في سعر يبقى رقم
// شكله دقيق وهو تخمين. اللي بيتقال: المتاح بعد الالتزامات، ولو العميل حدد ميزانية — تكفي ولا لأ، وقد إيه من المتاح.
//
// الكميات تقديرية (أعراف طبخ البيوت)، وبتتقال كده. السطور بالكيلو اسمها فيه الكمية والكمية ١ (`zad_shopping_list.quantity`
// integer)؛ المتعدّ (عيش، إزايز) كميته في الكمية.

import { normalizeItemName } from "./lowStock.ts";

export type GatheringMeal = "meal" | "sweets";

interface Rule {
  key: string;
  /** اسم السطر — «عيش» في مصر و«خبز» برّه. */
  name: (country: string) => string;
  perPerson: number;
  unit: "كجم" | "رغيف" | "إزازة ١ لتر" | "إزازة ١٫٥ لتر" | "قطعة";
  /** الكمية لكل وحدة شرا (الإزازة ١ لتر = ١، ١٫٥ لتر = ١٫٥). */
  per?: number;
  /** كلمات أسماء المخزون اللي بتغطي السطر ده. */
  matches: readonly string[];
}

const RULES: Record<GatheringMeal, readonly Rule[]> = {
  meal: [
    { key: "rice", name: () => "رز", perPerson: 0.1, unit: "كجم", matches: ["رز", "ارز"] },
    { key: "protein", name: () => "لحمة أو فراخ", perPerson: 0.3, unit: "كجم", matches: ["لحم", "لحمه", "فراخ", "دجاج", "كفته"] },
    { key: "salad", name: () => "خضار سلطة", perPerson: 0.15, unit: "كجم", matches: ["طماطم", "خيار", "خس"] },
    { key: "bread", name: (c) => (c === "EG" ? "عيش" : "خبز"), perPerson: 2, unit: "رغيف", matches: ["عيش", "خبز"] },
    { key: "drinks", name: () => "عصير أو مياه غازية", perPerson: 0.5, unit: "إزازة ١ لتر", per: 1, matches: ["عصير", "بيبسي", "كوكا", "غازيه"] },
    { key: "water", name: () => "مياه", perPerson: 1, unit: "إزازة ١٫٥ لتر", per: 1.5, matches: ["مياه", "مايه"] },
    { key: "fruit", name: () => "فاكهة", perPerson: 0.2, unit: "كجم", matches: ["فاكهه", "تفاح", "موز", "برتقال", "عنب"] },
    { key: "dessert", name: () => "حلويات", perPerson: 1, unit: "قطعة", matches: ["حلويات", "جاتوه", "كيك", "بسبوسه", "كنافه"] },
  ],
  sweets: [
    { key: "dessert", name: () => "حلويات", perPerson: 2, unit: "قطعة", matches: ["حلويات", "جاتوه", "كيك", "بسبوسه", "كنافه"] },
    { key: "fruit", name: () => "فاكهة", perPerson: 0.25, unit: "كجم", matches: ["فاكهه", "تفاح", "موز", "برتقال", "عنب"] },
    { key: "drinks", name: () => "عصير أو مياه غازية", perPerson: 0.4, unit: "إزازة ١ لتر", per: 1, matches: ["عصير", "بيبسي", "كوكا", "غازيه"] },
    { key: "water", name: () => "مياه", perPerson: 0.5, unit: "إزازة ١٫٥ لتر", per: 1.5, matches: ["مياه", "مايه"] },
  ],
};

export interface GatheringLine {
  key: string;
  name: string;
  /** للعرض: «١٫٢ كجم» أو «٢٠ رغيف». */
  amount: string;
  /** اسم سطر قايمة التسوق وكميته (integer). */
  list_name: string;
  list_quantity: number;
  /** اللي في البيت من نفس النوع (اسمه وكميته)، للعرض — مش بيتخصم: الوحدات في المخزون مش موحّدة. */
  at_home: string[];
  on_list: boolean;
}

export interface GatheringPlan {
  people: number;
  meal: GatheringMeal;
  lines: GatheringLine[];
  money: {
    available: number | null;
    currency: string | null;
    budget: number | null;
    /** null = مفيش ميزانية محددة أو المتاح مش معروف. */
    fits: boolean | null;
    share_of_available: number | null;
    saving_agreement: boolean;
  };
  note: string;
}

function fmt(n: number): string {
  return String(Math.round(n * 10) / 10).replace(".", "٫");
}

function covers(rule: Rule, name: string): boolean {
  const words = normalizeItemName(name).split(" ").map((w) => (w.startsWith("ال") ? w.slice(2) : w));
  return rule.matches.some((m) => words.includes(m));
}

export function gatheringPlan(input: {
  people: number;
  meal: GatheringMeal;
  country: string | null;
  pantry: ReadonlyArray<{ item_name: string; quantity: number | null; unit: string | null }>;
  shopping: readonly string[];
  available: number | null;
  currency: string | null;
  budget: number | null;
  savingAgreement: boolean;
}): GatheringPlan {
  const people = Math.max(1, Math.round(input.people));
  const country = String(input.country ?? "").toUpperCase();
  const lines = RULES[input.meal].map((r): GatheringLine => {
    const total = r.perPerson * people;
    const name = r.name(country);
    const counted = r.unit !== "كجم";
    const units = counted ? Math.ceil(total / (r.per ?? 1)) : 0;
    const amount = counted ? `${units} ${r.unit}` : `${fmt(total)} كجم`;
    return {
      key: r.key,
      name,
      amount,
      list_name: counted ? name : `${name} (${fmt(total)} كجم)`,
      list_quantity: counted ? units : 1,
      at_home: input.pantry.filter((p) => (p.quantity ?? 0) > 0 && covers(r, p.item_name))
        .map((p) => `${p.item_name} ${fmt(Number(p.quantity))}${p.unit ? ` ${p.unit}` : ""}`).slice(0, 3),
      on_list: input.shopping.some((s) => covers(r, s)),
    };
  });
  const available = Number.isFinite(Number(input.available)) && input.available !== null ? Number(input.available) : null;
  const budget = input.budget !== null && Number(input.budget) > 0 ? Number(input.budget) : null;
  const fits = budget !== null && available !== null ? budget <= available : null;
  const share = budget !== null && available !== null && available > 0 ? Math.round((budget / available) * 100) / 100 : null;
  return {
    people,
    meal: input.meal,
    lines,
    money: { available, currency: input.currency, budget, fits, share_of_available: share, saving_agreement: input.savingAgreement },
    note: "الكميات تقديرية بالفرد (أعراف بيوت)، مش وصفة. مفيش إجمالي فلوس: أسعار الناس من غير وحدة، فالضرب يبقى تخمين.",
  };
}

/** سطور قايمة التسوق اللي هتتضاف: مش موجودة في القايمة، ومش في [skip] (اللي العميل قال عنده منه). */
export function gatheringListRows(plan: GatheringPlan, skip: readonly string[]): Array<{ item_name: string; quantity: number }> {
  const skipped = skip.map((s) => normalizeItemName(s));
  return plan.lines
    .filter((l) => !l.on_list && !skipped.some((s) => s && normalizeItemName(l.name).includes(s)))
    .map((l) => ({ item_name: l.list_name, quantity: l.list_quantity }));
}
