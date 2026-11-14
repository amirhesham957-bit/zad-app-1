// «شربنا ٣ مية»، «خلّصنا علبة جبنة»، «عملنا مكرونة» — الاستهلاك من الكلام (خطة المخزن الواعي، الخطوة ٢، المالك ١٤/١١).
//
// المقاس ١٤/١١ على حساب المالك: ٢٩ صنف وصفر معدل استهلاك، لأن كل الملاحظات شرا أو إضافة ومفيش ولا نزلة. الطريق
// الوحيد للنزول كان update_inventory_qty بالكمية الفاضلة («فاضل كام؟») — والناس مابتعدّش اللي فاضل، بتقول اللي
// استعملته. الأداة دي بتطرح من الكمية وبتسجّل القراية، فـzad_consumption يتعلّم من أول جملة.
//
// المطابقة أوسع من add_inventory_item (pantryMatch.ts) عن قصد: «مية» لازم تلاقي «زجاجة مياه بسعة 1.5 لتر … 6 قطع».
// بس لو الكلام بيشاور على أكتر من صنف بيرفض ويقول الاختيارات — طرح من الصنف الغلط أوحش من سؤال.
// الكلمات تحت بيانات مطابقة مع كلام العميل وأسامي الأصناف — ممنوع تترجم (قاعدة i18n في CLAUDE.md).

import { normalizeItemName, samePantryItem } from "./pantryMatch.ts";

/** كلمات بنفس المعنى في كلام الناس عن المخزن. */
const SAME_WORD: Record<string, string> = {
  "مية": "مياه", "ميه": "مياه", "مايه": "مياه", "ماء": "مياه", "مويه": "مياه", "مياه": "مياه",
  "رز": "ارز", "ارز": "ارز",
  "عيش": "عيش", "خبز": "عيش",
  "جبن": "جبنه", "جبنه": "جبنه",
  "مكرونه": "مكرونه", "معكرونه": "مكرونه",
};

function words(name: string): string[] {
  return normalizeItemName(name).split(" ").filter((w) => w.length > 0).map((w) => SAME_WORD[w] ?? w);
}

export interface ConsumeRow {
  id: string;
  item_name: string;
  quantity: number | null;
  unit: string | null;
  user_id?: string | null;
  created_at?: string | null;
}

export type ConsumeMatch<T> = { row: T } | { ambiguous: string[] } | null;

/**
 * الصف اللي العميل استعمل منه. نفس الاسم (pantryMatch) الأول؛ وإلا الصفوف اللي فيها كل كلمات كلامه
 * («مية» ⇐ «زجاجة مياه …»). أكتر من صنف: اللي فيه كمية بس، ولو لسه أكتر من واحد = ambiguous بأساميهم.
 */
export function matchConsumeRow<T extends ConsumeRow>(rows: T[], said: string): ConsumeMatch<T> {
  const newest = (a: T, b: T) => String(b.created_at ?? "").localeCompare(String(a.created_at ?? ""));
  const exact = rows.filter((r) => samePantryItem(r.item_name, said)).sort(newest);
  if (exact.length > 0) return { row: exact.find((r) => Number(r.quantity) > 0) ?? exact[0] };
  const want = words(said);
  if (want.length === 0) return null;
  // نفس الاسم بعد المرادفات («مية» = «مياه») قبل الأسامي الأطول اللي فيها الكلمة.
  const key = [...new Set(want)].sort().join(" ");
  const same = rows.filter((r) => [...new Set(words(r.item_name))].sort().join(" ") === key).sort(newest);
  if (same.length > 0) return { row: same.find((r) => Number(r.quantity) > 0) ?? same[0] };
  const fits = rows.filter((r) => {
    const have = new Set(words(r.item_name));
    return want.every((w) => have.has(w));
  });
  if (fits.length === 0) return null;
  const names = (xs: T[]) => [...new Set(xs.map((r) => r.item_name))];
  if (names(fits).length === 1) return { row: fits.sort(newest).find((r) => Number(r.quantity) > 0) ?? fits[0] };
  const stocked = fits.filter((r) => Number(r.quantity) > 0);
  if (names(stocked).length === 1) return { row: stocked.sort(newest)[0] };
  return { ambiguous: names(stocked.length > 0 ? stocked : fits).slice(0, 5) };
}

/** وحدات بتقول «العبوة كلها» مش «حبة منها». */
const PACK_UNITS = new Set(["كرتونه", "كرتونة", "عبوه", "عبوة", "باكو", "كيس", "شنطه", "شنطة", "علبه", "علبة", "طبق", "pack"]);

/** كام حبة في العبوة من اسمها: «… 6 قطع» = 6، «12 زجاجة» = 12. ١ لو مش مكتوب. */
export function piecesPerPack(name: string): number {
  const m = normalizeItemName(name).match(/(\d+) (قطعه|قطع|حبات|حبه|زجاجات|زجاجه|علب|عبوات|اكياس|بيضات|بيضه|x)(?![؀-ۿa-z])/);
  const n = m ? Number(m[1]) : 1;
  return Number.isFinite(n) && n >= 2 && n <= 100 ? n : 1;
}

/**
 * كام من وحدة الصف اتشال. العميل بيعد بالحبة («٣ مية»)، والصف ممكن يكون كرتونة ٦ زجاجات — فالـ٣ = نص كرتونة.
 * لو قال الوحدة نفسها كرتونة/عبوة، أو الصف مافيهوش عدد حبات، الكمية زي ما هي.
 */
export function usedInRowUnits(amount: number, saidUnit: string | null | undefined, rowName: string): number {
  const per = piecesPerPack(rowName);
  const unit = (saidUnit ?? "").trim().toLowerCase();
  if (per === 1 || PACK_UNITS.has(unit)) return amount;
  return amount / per;
}

/** الكمية الجديدة بعد الاستهلاك: مابتنزلش تحت صفر، ومقرّبة لرقمين. */
export function quantityAfter(current: number | null, used: number): number {
  const q = Math.max(0, Number(current) || 0);
  return Math.round(Math.max(0, q - used) * 100) / 100;
}

/** «٣» / «٠٫٥» زي ما بتتقال. */
function fmt(n: number): string {
  return String(Math.round(n * 100) / 100);
}

/** الرد للعميل بعد الطرح. */
export function consumeReply(name: string, unit: string | null, before: number, after: number, dish?: string | null): string {
  const u = unit ? ` ${unit}` : "";
  const forDish = dish ? ` (${dish})` : "";
  if (after <= 0) return `سجلت إن «${name}» خلص${forDish} — المفروض يتجاب.`;
  return `سجلت الاستهلاك من «${name}»${forDish}: كان ${fmt(before)}${u}، فاضل ${fmt(after)}${u}.`;
}

/** «مفتوح من كام يوم» وكام فاضل من عمره بعد الفتح (20261114220000). null = مش مفتوح. */
export function openedState(
  openedAt: string | null | undefined,
  lifeDays: number | string | null | undefined,
  now: number = Date.now(),
): { daysAgo: number; left: number | null } | null {
  const at = openedAt ? Date.parse(openedAt) : NaN;
  if (!Number.isFinite(at)) return null;
  const ago = Math.max(0, (now - at) / 86_400_000);
  const life = Number(lifeDays);
  return {
    daysAgo: Math.floor(ago),
    left: Number.isFinite(life) && life > 0 ? Math.max(0, Math.round((life - ago) * 10) / 10) : null,
  };
}

/** سطر بعد «فتحنا …»: يفضل كويس قد إيه، لو نوعه بيبوظ بسرعة. */
export function openedNote(name: string, lifeDays: number | null): string {
  return lifeDays ? ` واتسجل إن «${name}» اتفتح النهارده — يفضل كويس حوالي ${lifeDays} أيام في التلاجة.` : ` واتسجل إن «${name}» اتفتح.`;
}
