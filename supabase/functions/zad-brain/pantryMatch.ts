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
  const wantedUnit = (unit ?? "").trim();
  const fits = rows.filter((r) => {
    if (!samePantryItem(r.item_name, name)) return false;
    const rowUnit = (r.unit ?? "").trim();
    return !wantedUnit || !rowUnit || rowUnit === wantedUnit;
  });
  if (fits.length === 0) return null;
  const key = normalizeItemName(name);
  const newest = (a: T, b: T) => String(b.created_at ?? "").localeCompare(String(a.created_at ?? ""));
  const exact = fits.filter((r) => normalizeItemName(r.item_name) === key).sort(newest);
  return exact[0] ?? fits.sort(newest)[0];
}
