// صف واحد لكل صنف في المخزن (٢٠٢٦-١٠-١٠).
//
// «بلح» كان متسجل مرتين عند المالك: `add_inventory_item` كان بيعمل insert على طول، فكل شرا
// جديد = صف جديد جنب القديم (اللي غالباً كميته صفر). دلوقتي الأداة بتدوّر الأول على نفس الصنف
// في مخزن العميل وتزوّد كميته.
//
// التطبيع هو نفس `normalizeItemName` في التطبيق (والـSQL `zad_inventory_name_key`،
// 20261010140000): الحروف الصغيرة، أشكال الألف، التاء المربوطة، الألف المقصورة، و«ال» من أول كل
// كلمة. المطابقة أضيق من قاعدة فواتير التطبيق عن قصد: نفس الاسم بعد التطبيع، أو نفس الكلمات
// بترتيب تاني («برانش توست» / «توست برانش») — مش «لبن» مع «لبن زبادي»، لأن اسم الشات مقصود.

export function normalizeItemName(name: string): string {
  return name
    .trim()
    .toLowerCase()
    .replace(/[أإآ]/g, "ا")
    .replace(/ة/g, "ه")
    .replace(/ى/g, "ي")
    // رقم لازق في كلمة بيتفصل: «40جم» = «40 جم» (شاي المالك كان صفين عشان مسافة، ١/١١).
    .replace(/(\d)([^\d\s.])/g, "$1 $2")
    .replace(/([^\d\s.])(\d)/g, "$1 $2")
    .split(/\s+/)
    .filter((w) => w.length > 0)
    .map((w) => (w.startsWith("ال") && w.length > 2 ? w.slice(2) : w))
    .join(" ");
}

function wordSet(normalized: string): string {
  return [...new Set(normalized.split(" ").filter((w) => w.length > 0))].sort().join(" ");
}

/** نفس الصنف: نفس الاسم بعد التطبيع، أو نفس الكلمات بأي ترتيب. */
export function samePantryItem(a: string, b: string): boolean {
  const na = normalizeItemName(a);
  const nb = normalizeItemName(b);
  if (!na || !nb) return false;
  return na === nb || wordSet(na) === wordSet(nb);
}

/**
 * الوحدة الواحدة بكل كتاباتها: الفاتورة بتكتب «EA» والشات «قطعة»، ومصدر «كيلو» وتاني «كجم».
 * نفس `unitKey` في التطبيق و`zad_inventory_unit_key` في الـSQL.
 */
export function unitKey(unit: string | null | undefined): string {
  const u = (unit ?? "").trim().toLowerCase();
  if (["", "ea", "pc", "pcs", "piece", "قطعة", "قطعه", "حبة", "حبه", "عدد"].includes(u)) return "piece";
  if (["كجم", "كيلو", "كيلوجرام", "كيلوغرام", "كغ", "kg"].includes(u)) return "kg";
  if (["لتر", "l", "liter", "litre"].includes(u)) return "l";
  return u;
}

/** نفس الوحدة؛ الوحدة الناقصة من أي ناحية بتركب على أي وحدة. «كيلو» قصاد «كيس» صنف تاني. */
export function sameUnit(a: string | null | undefined, b: string | null | undefined): boolean {
  if (!(a ?? "").trim() || !(b ?? "").trim()) return true;
  return unitKey(a) === unitKey(b);
}

export interface PantryRow {
  id: string;
  item_name: string;
  quantity: number | null;
  unit: string | null;
  created_at?: string | null;
}

/**
 * الصف اللي الكمية الجديدة تتزوّد عليه، أو null = صنف جديد. وحدة مختلفة صراحةً («كيلو» قصاد
 * «كيس») = صنف تاني. الاسم المطابق حرفياً بعد التطبيع قبل الكلمات المتبدّلة، والأحدث قبل الأقدم.
 */
export function pickPantryMatch<T extends PantryRow>(rows: T[], name: string, unit?: string | null): T | null {
  const fits = rows.filter((r) => samePantryItem(r.item_name, name) && sameUnit(r.unit, unit));
  if (fits.length === 0) return null;
  const key = normalizeItemName(name);
  const newest = (a: T, b: T) => String(b.created_at ?? "").localeCompare(String(a.created_at ?? ""));
  const exact = fits.filter((r) => normalizeItemName(r.item_name) === key).sort(newest);
  return exact[0] ?? fits.sort(newest)[0];
}
