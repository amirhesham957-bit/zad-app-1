// foodPattern.ts — صورة أكل البيت من المشتريات (ZAD_PLAN ٥.١٠ بند ٦، طلب المالك ٨/١١).
//
// وصف مشتريات البيت كله، مرة في الشهر بالكتير، وبعد اختيار صريح من الإعدادات (`zad_users.food_pattern_enabled`).
// مش تشخيص: مفيش كلمة عن نقص فيتامين أو مرض، ومفيش استنتاج عن فرد بعينه. المشتريات المتسجلة مش كل اللي البيت أكله، والسؤال بيقول كده.

import type { Curiosity } from "./curiosity.ts";
import { itemKey } from "./shared.ts";

/** أقل عدد أصناف أكل مختلفة عشان الصورة تعني حاجة. */
export const FOOD_MIN_ITEMS = 8;
export const FOOD_WINDOW_DAYS = 28;
/** الحلويات والمشروبات الغازية من الأصناف: فوق النسبة دي تتقال. */
export const SWEET_SHARE = 0.4;

const GROUPS: ReadonlyArray<readonly [string, RegExp]> = [
  ["veg", /(طماطم|خيار|بصل|بطاطس|جزر|كوسه|باذنجان|فلفل|خس|سبانخ|ملوخيه|بامي[هه]|كرنب|قرنبيط|بروكلي|خضار|فاصوليا خضرا|بسله)/],
  ["fruit", /(تفاح|موز|برتقال|عنب|مانجو|فراوله|جوافه|رمان|كمثري|يوسفي|بطيخ|شمام|فاكه[هة])/],
  ["protein", /(فراخ|دجاج|لحم|لحمه|كفته|سمك|تونه|جمبري|بيض|عدس|فول|حمص|كبد)/],
  ["sweet", /(شوكولا|بسكويت|شيبس|حلاوه|حلويات|كيك|ايس كريم|مولتو|كولا|بيبسي|سفن اب|سبرايت|مشروب غازي|عصير معلب|طاقه)/],
];
const OTHER_FOOD = /(رز|ارز|مكرون|عيش|خبز|لبن|حليب|جبن|زبادي|زيت|سمن|سكر|دقيق|شاي|قهوه|تمر|عسل)/;

export interface FoodBought {
  name: string | null;
  at?: string | null;
}

export function foodGroups(rows: readonly FoodBought[], nowMs: number): { total: number; counts: Record<string, number> } {
  const cut = nowMs - FOOD_WINDOW_DAYS * 86_400_000;
  const counts: Record<string, number> = { veg: 0, fruit: 0, protein: 0, sweet: 0 };
  const seen = new Set<string>();
  let total = 0;
  for (const r of rows) {
    const key = itemKey(String(r.name ?? ""));
    const at = Date.parse(r.at ?? "");
    if (!key || seen.has(key) || (Number.isFinite(at) && at < cut)) continue;
    seen.add(key);
    const group = GROUPS.find(([, p]) => p.test(key))?.[0];
    if (group) counts[group]++;
    if (group || OTHER_FOOD.test(key)) total++;
  }
  return { total, counts };
}

const DISCLAIMER = "ده من المشتريات المتسجلة بس، وأي حاجة تخص الصحة الدكتور أولى بيها.";

/** ملاحظة واحدة، الأهم الأول. مفتاحها بيمنع تكرارها قبل ٣٠ يوم (recentlyAskedKeys). */
export function foodPatternNote(rows: readonly FoodBought[], nowMs: number): Curiosity | null {
  const { total, counts } = foodGroups(rows, nowMs);
  if (total < FOOD_MIN_ITEMS) return null;
  const note = (gap: string, what: string, offer: string): Curiosity => ({
    key: `food:${gap}`, kind: "food_pattern",
    question: `آخر ٤ أسابيع ${what}. ${offer} ${DISCLAIMER}`,
    record: "آه ⇒ add_shopping_item بأصناف بسيطة يختارها أو تقترحها عليه. لأ ⇒ ولا حاجة. متتكلمش عن مرض أو نقص فيتامين ومتفترضش حاجة عن فرد في البيت.",
    tool: "add_shopping_item",
  });
  if (counts.veg === 0) return note("veg", "مشتريات البيت المتسجلة مافيهاش خضار تقريباً", "أحطلك كام صنف في القايمة؟");
  if (counts.fruit === 0) return note("fruit", "مفيش فاكهة في مشتريات البيت المتسجلة", "أضيف فاكهة الموسم للقايمة؟");
  if (counts.protein === 0) return note("protein", "المشتريات المتسجلة مافيهاش بروتين زي فراخ أو بيض أو بقوليات", "أحطلك حاجة منهم بأرخص عرض؟");
  if (counts.sweet / total >= SWEET_SHARE) return note("sweet", "الحلويات والمشروبات الغازية واخدة حتة كبيرة من المشتريات المتسجلة", "تحب أقترح بدايل بنفس الميزانية؟");
  return null;
}

/** عرض التفعيل، مرة واحدة: زاد بيعرّف الميزة، والعميل هو اللي يفتحها. */
export function foodPatternInvite(rows: readonly FoodBought[], nowMs: number): Curiosity | null {
  if (foodGroups(rows, nowMs).total < FOOD_MIN_ITEMS) return null;
  return {
    key: "clue:food_invite", kind: "food_pattern",
    question: "تحب أقولك مرة في الشهر صورة أكل البيت من المشتريات؟ بتتفتح من الإعدادات ← «صورة أكل البيت»، وتقدر تقفلها في أي وقت.",
    record: "مفيش حاجة تتسجل: المفتاح في الإعدادات. لو وافق قوله يفتحه من هناك.",
  };
}
