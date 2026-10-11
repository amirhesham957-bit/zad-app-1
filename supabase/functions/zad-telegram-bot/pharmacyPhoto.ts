// pharmacyPhoto.ts — صورة فاتورة صيدلية أو علبة دوا في تليجرام: المعروف يتزوّد، والجديد بتأكيد.
//
// من ٢٠٢٦-٠٨-٠٩ (80ffea33) كل سطر في صورة الصيدلية كان بيتضاف للصيدلية على طول، حتى الدوا الجديد — وده
// بيفتح تذكيرات متكررة على الموبايل من غير ما العميل يقول. ونفس الكومِت شال الكاتب الوحيد لـ
// telegram_pending_pharmacy، فزرار «✅ أكد وفعّل التذكير» (mx:/mc:) فضل في الكود من غير ما حد يوصله
// (حارس اليتامى لقاه، ٢٠٢٦-١٠-١١). قرار المالك: «اتوصله فوراً… معالجة الجرعات والتأكيد أولوية».
//
// القاعدة: دوا موجود بنفس الاسم في صيدلية العميل ⇒ يتزوّد زي الأول (zad-brain add_pharmacy_item بيصحّح الصف
// الموجود). دوا جديد ⇒ صف في telegram_pending_pharmacy ورسالة بزرار التأكيد؛ الإضافة بتحصل بعد الضغطة بس.
// «موجود» بنفس قاعدة zad-brain بالظبط (الاسم بعد trim وlowercase): لو قاعدة هنا أوسع، دوا البوت شايفه معروف
// كان هيتضاف جديد من غير تأكيد.

export interface PhotoMedicine {
  name: string;
  quantity: number;
  unit: string;
}

/** بحد أقصى في الصورة الواحدة — رسالة تأكيد لكل دوا جديد. */
export const NEW_MEDICINES_MAX = 5;

const key = (name: string) => name.trim().toLowerCase();

export function splitPhotoMedicines(
  items: Array<{ name?: string | null; quantity?: number | null; unit?: string | null }>,
  existingNames: string[],
): { known: PhotoMedicine[]; fresh: PhotoMedicine[] } {
  const have = new Set(existingNames.map(key));
  const seen = new Set<string>();
  const known: PhotoMedicine[] = [];
  const fresh: PhotoMedicine[] = [];
  for (const item of items) {
    const name = String(item.name ?? "").trim().slice(0, 80);
    if (!name || seen.has(key(name))) continue;
    seen.add(key(name));
    const quantity = Number.isFinite(item.quantity) && Number(item.quantity) > 0 ? Math.round(Number(item.quantity)) : 1;
    const med = { name, quantity, unit: String(item.unit ?? "").trim().slice(0, 20) || "قرص" };
    if (have.has(key(name))) known.push(med);
    else if (fresh.length < NEW_MEDICINES_MAX) fresh.push(med);
  }
  return { known, fresh };
}
