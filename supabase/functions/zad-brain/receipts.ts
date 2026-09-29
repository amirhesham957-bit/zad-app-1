// إيصالات اللفة — `executed` في رد zad-brain هو اللي العميل **بيشوفه**: سطر «✅ …» في
// تليجرام وشيب تحت الرد في شات التطبيق. نتيجة الأداة نفسها مكتوبة للموديل مش للعميل.
//
// ٢٠٢٦-٠٩-٢٩ (تليجرام): «اسمي مو شريف» رجّع للعميل حرفياً «✅ اتسجل في ملفه:
// preferred_name. متقولهوش إنك سجلت — كمّل الكلام عادي…» — تعليمة داخلية للموديل.
// والسبب مش الأداة دي بس: كل نداء أداة ناجح كان بيدخل `executed`، يعني web_search كان
// هيبعت JSON نتايج البحث الخام، وfind_nearby_stores «قوله يفعّل تنبيهات الأماكن».
// الإيصال دلوقتي للكتابة الحقيقية بس، ومش لكتابة العميل المفروض مايحسش بيها.

/** كتابات حقيقية بس مالهاش إيصال: الرد نفسه هو اللي بيبيّنها (هناديك باسمك). */
export const SILENT_WRITE_TOOLS: ReadonlySet<string> = new Set(["update_customer_profile", "learn_skill"]);

/** كتابة حقيقية مابتزوّدش ctx.mutationCount (قايمة التسوق — idempotent بالاسم). */
export const WRITES_WITHOUT_COUNTER: ReadonlySet<string> = new Set(["add_shopping_item"]);

/**
 * «مرفوض:» هي الاتفاقية، بس أدوات قديمة بترجع «فشل الإضافة: …» — ودي كانت بتطلع
 * للعميل «✅ فشل الإضافة» كأنها نجحت.
 */
export function isToolFailure(result: string): boolean {
  return /^\s*(مرفوض|فشل)/.test(result);
}

/** هل النداء ده كتب حاجة فعلاً ويستاهل يدخل `executed` (حتى لو صامت)؟ */
export function isWrite(tool: string, result: string, mutated: boolean): boolean {
  if (isToolFailure(result)) return false;
  return mutated || WRITES_WITHOUT_COUNTER.has(tool);
}

/** اللي يطلع للعميل من `executed` — من غير الكتابات الصامتة. */
export function visibleReceipts<T extends { tool: string }>(executed: readonly T[]): T[] {
  return executed.filter((e) => !SILENT_WRITE_TOOLS.has(e.tool));
}

/**
 * لفة كتبت حاجة صامتة والموديل مارد بحاجة: تليجرام كان هيعاملها كلفة فاضية ويرد
 * بخطأ. رد قصير بدل الصمت — «تمام» مفهومة في كل اللهجات.
 */
export function silentWriteFallback(reply: string, executed: readonly { tool: string }[], proposals: number): string {
  if (reply.trim() || proposals > 0) return reply;
  if (executed.length === 0 || visibleReceipts(executed).length > 0) return reply;
  return "تمام 👍";
}
