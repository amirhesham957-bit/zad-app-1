// productIdentity.ts — حارس الهوية: «دول نفس الحاجة؟» (الموجة ٦، ٢٠٢٦-١٠-١١).
//
// فحص ما قبل الإطلاق: المية خمس أصناف واللبن صنفين، فالاستهلاك عمره ما بيتعلّم. قرار المالك: العقل
// **يسأل العميل مرة** ومايدمجش لوحده. هنا الجزء اللي بيلاقي الأزواج اللي تستاهل السؤال، من غير موديل:
//
//   - المفتاح نفس zad_inventory_name_key في SQL (الألف والتاء المربوطة والألف المقصورة و«ال» في
//     أول كل كلمة) — لو اتغيّر هنا يتغيّر هناك.
//   - كلمات التغليف («عبوة»، «إزازة»، «كرتونة»…) والأرقام والوحدات بتتشال قبل المقارنة: «عبوة مياه»
//     و«إزازة ماء» الاتنين مية.
//   - زوج بيستاهل السؤال لو الاتنين من نفس العيلة في قاموس الأساسيات (لبن/حليب، مياه/ماء، عيش/خبز…)،
//     أو أول كلمة مفيدة فيهم واحدة («مياه إيلانو» / «مياه نستله»).
//   - زوج اتجاوب عليه (zad_product_pairs، same أو different) مابيتسألش تاني أبداً، واللي اتسأل ومااتجاوبش
//     بيستنى ٣٠ يوم (نفس قاعدة الفضول).
//
// السؤال بيتسأل في خانة «سؤال اليوم» في تحية الصبح (voiceMoments.ts)، والجواب بيوصل لفة شات عادية بأداة
// answer_same_product (asked_this_morning.tool).

import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { askedCuriosityKeys, ASK_AGAIN_AFTER_DAYS, type Curiosity } from "./curiosity.ts";
import { householdFamilyId, householdFilter } from "../_shared/household.ts";

const DAY_MS = 86_400_000;

/** نفس public.zad_inventory_name_key. */
export function productNameKey(name: string | null | undefined): string {
  const s = String(name ?? "").trim().toLowerCase()
    .replace(/[أإآ]/g, "ا").replace(/ة/g, "ه").replace(/ى/g, "ي");
  return s.split(/\s+/).filter((w) => w !== "")
    .map((w) => (w.startsWith("ال") && w.length > 2 ? w.slice(2) : w))
    .join(" ");
}

/** كلمات تغليف ووحدات — مش اسم المنتج (بعد المفتاح: ة ⇒ ه، و«ال» متشالة). */
const PACKAGING = new Set([
  "عبوه", "ازازه", "زجاجه", "كرتونه", "علبه", "كيس", "باكو", "شيكاره", "برطمان", "جركن",
  "لتر", "ليتر", "مل", "كيلو", "كجم", "جرام", "جم", "حبه", "قطعه",
]);

/** عيلات الأساسيات: كلمة من نفس العيلة في الاسمين = يستاهل السؤال. */
const STAPLE_GROUPS: ReadonlyArray<readonly string[]> = [
  ["لبن", "حليب"],
  ["مياه", "ميه", "مايه", "ماء", "مية"],
  ["عيش", "خبز", "توست"],
  ["رز", "ارز"],
  ["زيت"],
  ["سكر"],
  ["شاي"],
  ["قهوه", "بن", "نسكافيه"],
  ["بيض"],
  ["جبنه", "جبن"],
  ["زبادي", "روب"],
  ["فراخ", "دجاج", "فرخه"],
  ["لحمه", "لحم"],
  ["مكرونه", "معكرونه", "باستا"],
  ["صابون"],
  ["مناديل", "محارم"],
  ["عدس"],
  ["فول"],
].map((g) => g.map((w) => productNameKey(w)));

const GROUP_OF = new Map<string, number>();
STAPLE_GROUPS.forEach((g, i) => g.forEach((w) => GROUP_OF.set(w, i)));

/** الكلمات اللي تفرق: من غير تغليف ولا أرقام. */
export function meaningfulWords(name: string): string[] {
  return productNameKey(name).split(" ")
    .filter((w) => w !== "" && !PACKAGING.has(w) && !/^[\d.,٠-٩]+$/.test(w));
}

/** مفتاح الزوج مرتب، زي a_key/b_key في zad_product_pairs. */
export function pairKey(a: string, b: string): string {
  const [x, y] = [productNameKey(a), productNameKey(b)].sort();
  return `${x}|${y}`;
}

export interface SamePair {
  a: string;
  b: string;
  /** staple = من نفس عيلة الأساسيات؛ head = أول كلمة واحدة. */
  why: "staple" | "head";
}

/**
 * الأزواج اللي تستاهل «دول نفس الحاجة؟» — الأساسيات الأول. [decided] = مفاتيح الأزواج اللي اتجاوبت
 * (أو اتسألت قريب). الأسماء بترتيبها (الأحدث أو الأهم الأول).
 */
export function samePairCandidates(names: readonly string[], decided: ReadonlySet<string>): SamePair[] {
  const unique: string[] = [];
  const seenKeys = new Set<string>();
  for (const n of names) {
    const name = String(n ?? "").trim();
    const key = productNameKey(name);
    if (!key || seenKeys.has(key)) continue;
    seenKeys.add(key);
    unique.push(name);
  }
  const staple: SamePair[] = [];
  const head: SamePair[] = [];
  for (let i = 0; i < unique.length; i++) {
    for (let j = i + 1; j < unique.length; j++) {
      const a = unique[i];
      const b = unique[j];
      if (decided.has(pairKey(a, b))) continue;
      const wa = meaningfulWords(a);
      const wb = meaningfulWords(b);
      if (wa.length === 0 || wb.length === 0) continue;
      const ga = new Set(wa.map((w) => GROUP_OF.get(w)).filter((g): g is number => g !== undefined));
      if (wb.some((w) => ga.has(GROUP_OF.get(w) ?? -1))) staple.push({ a, b, why: "staple" });
      else if (wa[0] === wb[0] && wa[0].length >= 3) head.push({ a, b, why: "head" });
    }
  }
  return [...staple, ...head];
}

/** السؤال كـ«فضول» بأداة الجواب. */
export function samePairQuestion(p: SamePair): Curiosity {
  return {
    key: `same:${pairKey(p.a, p.b)}`,
    kind: "same_product",
    question: `عندك «${p.a}» و«${p.b}» — دول نفس الحاجة ولا حاجتين مختلفين؟`,
    record:
      `لو قال نفس الحاجة ⇒ answer_same_product (a = «${p.a}»، b = «${p.b}»، same = true، keep = الاسم اللي يحبه ` +
      `لو قاله وإلا «${p.a}»)؛ لو قال مختلفين ⇒ same = false. ماتدمجش من غير ما يقول، وقول في جملة إيه اللي هيحصل ` +
      `(«تمام، هعدّهم صنف واحد عشان أعرف إمتى بيخلص»).`,
    tool: "answer_same_product",
  };
}

/** القراءات + القرار. أي قراءة فشلت ⇒ null (مفيش سؤال أحسن من سؤال اتجاوب). */
export async function sameProductAsk(sb: SupabaseClient, userId: string, now = Date.now()): Promise<Curiosity | null> {
  try {
    const family = await householdFamilyId(sb, userId);
    const house = householdFilter(userId, family);
    const [pantry, list, pairs, asked] = await Promise.all([
      sb.from("zad_inventory").select("item_name,created_at").or(house)
        .order("created_at", { ascending: false }).limit(300),
      sb.from("zad_shopping_list").select("item_name").or(house).eq("is_purchased", false).limit(100),
      sb.from("zad_product_pairs").select("a_key,b_key").or(house).limit(500),
      sb.from("zad_voice_moments").select("facts")
        .eq("user_id", userId).eq("moment", "morning_greeting").eq("status", "sent")
        .gte("created_at", new Date(now - ASK_AGAIN_AFTER_DAYS * DAY_MS).toISOString()).limit(60),
    ]);
    if (pantry.error || list.error || pairs.error || asked.error) return null;
    const decided = new Set<string>(
      ((pairs.data ?? []) as Array<{ a_key: string; b_key: string }>).map((p) => `${p.a_key}|${p.b_key}`),
    );
    for (const key of askedCuriosityKeys(asked.data as Array<{ facts?: unknown }>)) {
      if (key.startsWith("same:")) decided.add(key.slice(5));
    }
    const names = [
      ...((pantry.data ?? []) as Array<{ item_name: string | null }>).map((r) => r.item_name ?? ""),
      ...((list.data ?? []) as Array<{ item_name: string | null }>).map((r) => r.item_name ?? ""),
    ];
    const first = samePairCandidates(names, decided)[0];
    return first ? samePairQuestion(first) : null;
  } catch (e) {
    console.warn("[identity] read failed:", (e as Error)?.message);
    return null;
  }
}
