// ملف أكل البيت في لقطة العقل (خطة المخزن الواعي ٥، المالك ١٤/١١).
//
// المقاس ١٤/١١ على الحي: صفر تفضيلات أكل (deal_affinity)، صفر براندات (zad_item_preferences)، صفر تقييم وصفات،
// لكل الحسابات. الالتقاط موجود (statedPreference بيحفظ «مش باكل X» من الشات، وset_item_preference للبراند) ومحدش
// قال حاجة. الأساسيات بقى ليها داتا حقيقية: الصنف اللي اتشرى ٣ أيام مختلفة أو العميل قال «أساسي» (restockCycle.ts).
// الملف قصير عن قصد (رجيم السياق ٣.٢): ٨ بالكتير في كل قايمة، والقايمة الفاضية مابتتبعتش.

export interface FoodProfile {
  people?: number;
  staples?: string[];
  brands?: string[];
  avoid?: string[];
  likes?: string[];
}

const MAX = 8;

export function foodProfile(input: {
  householdSize?: number | null;
  staples: readonly string[];
  preferences: ReadonlyArray<{ item_name: string | null; kind: string | null; brand: string | null }>;
  affinities: ReadonlyArray<{ term: string; polarity: "like" | "dislike"; weight: number }>;
}): FoodProfile | null {
  const uniq = (xs: Array<string | null | undefined>) => [...new Set(xs.map((x) => String(x ?? "").trim()).filter((x) => x.length > 0))].slice(0, MAX);
  const out: FoodProfile = {};
  const people = Number(input.householdSize);
  if (Number.isInteger(people) && people >= 1 && people <= 30) out.people = people;
  const staples = uniq([...input.staples]);
  if (staples.length) out.staples = staples;
  const brands = uniq(input.preferences.map((p) =>
    p.kind === "preferred_brand" && p.brand ? `${p.item_name}: ${p.brand}`
      : p.kind === "rejected_brand" && p.brand ? `${p.item_name}: مش ${p.brand}`
      : null
  ));
  if (brands.length) out.brands = brands;
  const byWeight = [...input.affinities].sort((a, b) => b.weight - a.weight);
  const avoid = uniq(byWeight.filter((a) => a.polarity === "dislike").map((a) => a.term));
  if (avoid.length) out.avoid = avoid;
  const likes = uniq(byWeight.filter((a) => a.polarity === "like" && a.weight >= 1).map((a) => a.term));
  if (likes.length) out.likes = likes;
  return Object.keys(out).length > (out.people ? 1 : 0) ? out : null;
}
