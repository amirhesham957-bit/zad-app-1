// purchaseIntent.ts — النية المؤجلة (ZAD_PLAN ٥.٨ (٣)).
//
// «عايز أشتري جاكيت» كانت بتتقال في الشات وبتضيع: مفيش حاجة بتفتكرها لما عرض عليها يظهر. هنا بتتحفظ نية بتاريخ
// (تنتهي بعد ٦٠ يوم، أو لما تتشرى)، وعرض الصبح (tasteDeals.ts) بيدوّر لها قبل قايمة الشرا. الالتقاط بقواعد ثابتة على
// كلام العميل نفسه في الرسالة (زي النبرة في tone.ts) — مش أداة ولا سطر في برومبت الشات، فمابيلمسش ٣.٢.
// النفي («مش عايز أشتري») والماضي («اشتريت») مش نية. الشك = مفيش نية: عرض على حاجة ماقالهاش أوحش من مفيش عرض.

import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { itemKey } from "./shared.ts";
import { offerMatchesNeed } from "./productIdentity.ts";

export const INTENT_DAYS = 60;
/** نيتين بالكتير في أصناف العرض — الباقي لقايمة الشرا واللي هيخلص. */
export const MAX_INTENT_ITEMS = 2;

// بتشيل التشكيل والتطويل من غير ما تغيّر طول النص، عشان مكان الكلمة في النص المتوحّد = مكانها في الأصلي.
const strip = (s: string) => s.replace(/[ً-ْـ]/g, "");
const fold = (s: string) => s.replace(/[أإآ]/g, "ا").replace(/ى/g, "ي").replace(/ة/g, "ه");

const WANT = "عايز|عايزه|عاوز|عاوزه|عايزين|عاوزين|ابغي|ابغا|ابي|ناوي|ناويه|نفسي|حابب|حابه|بفكر|افكر|محتاج|محتاجه";
const BUY = "اشتري|نشتري|اشتريلي|اجيب|نجيب|اجيبلي|اخد|ناخد";
const INTENT = new RegExp(`(^|[\\s،,.!؟?])(${WANT})\\s+(?:ا|انا\\s+)?(?:${BUY})\\s+([^\\n.!؟?،,]{2,60})`);
const NEGATED = /(^|\s)(مش|مو|ما|مب|لا)\s*$/;

/** كلمات بتقفل اسم الحاجة: ميعاد، سبب، سعر، مكان — اللي بعدها مش اسم الصنف. */
const STOP = new Set([
  "بكام", "بكم", "من", "عشان", "علشان", "لان", "بس", "لما", "لو", "قبل", "بعد", "الشهر", "الاسبوع", "بكره",
  "بكرا", "النهارده", "اليوم", "قريب", "قريبا", "في", "فى", "و", "او", "ولا", "ب", "بحدود", "حدود", "ميزانيه", "تقريبا",
  "جديد", "جديده", "الجاي", "الجايه", "ده", "دي", "دا", "هنا", "عليه", "عليها", "ازاي", "فين", "امتي", "ايه", "منين",
]);

/** «حاجة» و«أكل» مش صنف يتدوّر له على عرض. */
const VAGUE = new Set(["حاجه", "حاجات", "شويه", "اكل", "حاجه حلوه", "هدوم", "هديه", "حاجه جديده", "حد", "اي حاجه"]);

/** الحاجة اللي العميل قال إنه ناوي يشتريها في الرسالة دي، أو null. أول نية بس. */
export function purchaseIntentFrom(message: string | null | undefined): string | null {
  const raw = strip(String(message ?? ""));
  const text = fold(raw);
  const m = INTENT.exec(text);
  if (!m) return null;
  const before = text.slice(0, m.index + m[1].length);
  if (NEGATED.test(before)) return null;
  const start = m.index + m[0].length - m[3].length;
  const words = raw.slice(start, start + m[3].length).trim().split(/\s+/);
  const kept: string[] = [];
  for (const w of words) {
    const f = fold(w).replace(/[^\p{L}\p{N}]/gu, "");
    if (!f || STOP.has(f) || /\d/.test(f) || (kept.length > 0 && f.startsWith("ب") && STOP.has(f.slice(1)))) break;
    kept.push(w.replace(/[^\p{L}\p{N}-]/gu, ""));
    if (kept.length === 3) break;
  }
  const item = kept.join(" ").trim();
  if (item.length < 2 || VAGUE.has(itemKey(item))) return null;
  return item.slice(0, 40);
}

/** النية اتشرت؟ مصروف بعدها اسمه هو الحاجة، أو صنف دخل المخزن بعدها. */
export function intentBought(
  intent: { item: string; said_at: string },
  bought: ReadonlyArray<{ name: string | null; at: string | null }>,
): boolean {
  const since = Date.parse(intent.said_at);
  return bought.some((b) => !!b.name && Date.parse(b.at ?? "") >= since && offerMatchesNeed(intent.item, b.name));
}

/** يحفظ النية لو الرسالة فيها واحدة. نفس الحاجة مفتوحة ⇒ ميعادها يتجدد. ماتوقفش اللفة أبداً. */
export async function notePurchaseIntent(sb: SupabaseClient, userId: string, message: string): Promise<string | null> {
  const item = purchaseIntentFrom(message);
  if (!item) return null;
  try {
    const { error } = await sb.rpc("zad_purchase_intent_note", { p_user: userId, p_item: item, p_key: itemKey(item), p_days: INTENT_DAYS });
    if (error) console.warn("[purchase_intent] note failed:", error.message);
  } catch (e) {
    console.warn("[purchase_intent] note failed:", (e as Error)?.message);
  }
  return item;
}

export interface OpenIntent {
  id: string;
  item: string;
  said_at: string;
}

/**
 * النيات المفتوحة لسه (الأحدث الأول)، بعد ما اللي اتشرى يتقفل. [bought] = مصروفات وأصناف مخزن من نفس الفترة —
 * القراية بتاعتها عند اللي بينادي عشان ماتتعادش.
 */
export async function openIntents(
  sb: SupabaseClient,
  userId: string,
  bought: ReadonlyArray<{ name: string | null; at: string | null }>,
  now = Date.now(),
): Promise<OpenIntent[]> {
  const { data, error } = await sb.from("zad_purchase_intents").select("id,item,said_at")
    .eq("user_id", userId).eq("status", "open").gt("expires_at", new Date(now).toISOString())
    .order("said_at", { ascending: false }).limit(10);
  if (error) return [];
  const open: OpenIntent[] = [];
  for (const r of (data ?? []) as OpenIntent[]) {
    if (!r?.item) continue;
    if (intentBought(r, bought)) {
      await sb.from("zad_purchase_intents").update({ status: "bought", closed_at: new Date(now).toISOString() }).eq("id", r.id)
        .then(({ error: e }) => e && console.warn("[purchase_intent] close failed:", e.message), () => {});
      continue;
    }
    open.push(r);
  }
  return open;
}
