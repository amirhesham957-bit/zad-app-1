// forcedKindFix.ts — «الـ500 اللي اتسجلت دخل دي غلط، دي كانت مصروف» والموديل رد «هظبطها» من غير أداة (ZAD_PLAN ١٠.٧).
//
// فحص ١٥/١١ على الإنتاج (حساب تجربة، `gemini-3.5-flash-lite`): إيداع ٥٠٠ ورسالة التصحيح دي ⇒ مفيش ولا نداء أداة،
// والحارس بدّل الرد بـ«لسه ماعملتش ده». الموديل محتاج خطوتين (read_house للحركات بمعرّفاتها، وبعدين
// update_transaction) وماعملش ولا واحدة. ونفس الشكل من بوت تليجرام ١٢/١١.
//
// هنا من غير موديل: الرسالة بتقول صراحة إن النوع غلط ⇒ الحركة من آخر ٢٠ (اللي نوعها عكس المطلوب، وبالمبلغ لو
// اتقال) — لو واحدة بس، اقتراح update_transaction بالنوع الصح، بكارت «أكّد؟» زي أي تعديل فلوس. أكتر من واحدة
// أو ولا واحدة ⇒ مفيش تخمين.

const normalize = (text: string) =>
  text.replace(/[ً-ٰٟـ]/g, "").replace(/[أإآ]/g, "ا").replace(/ى/g, "ي").replace(/ة/g, "ه")
    .replace(/[٠-٩]/g, (d) => String("٠١٢٣٤٥٦٧٨٩".indexOf(d))).toLowerCase();

const NOT = "و?(مش|مو|ماهو|مهوش|موب|مب|ليس|ليست|مهيش|ماهي)";
const INCOME = "(ال)?(دخل|ايداع|مرتب|راتب)";
const EXPENSE = "(ال)?(مصروف|مصاريف|صرف)";
/** «دي مش دخل»، «مش إيداع» ⇒ مصروف. */
const NOT_INCOME = new RegExp(`(^|\\s)${NOT}\\s+${INCOME}(\\s|$|[،,.])`);
/** «ده دخل مش مصروف» ⇒ دخل. */
const NOT_EXPENSE = new RegExp(`(^|\\s)${NOT}\\s+${EXPENSE}(\\s|$|[،,.])`);
/** «اتسجلت دخل … كانت مصروف». */
const RECORDED_AS_INCOME = new RegExp(`(اتسجلت|اتسجل|سجلتها|سجلته|حسبتها|حسبته|نزلت|نزلتها)\\s+(ك)?${INCOME}`);
const RECORDED_AS_EXPENSE = new RegExp(`(اتسجلت|اتسجل|سجلتها|سجلته|حسبتها|حسبته|نزلت|نزلتها)\\s+(ك)?${EXPENSE}`);
const SAYS_EXPENSE = /(مصروف|مصاريف|دفعته|دفعتها|دفعت|صرفته|صرفتها)/;
const SAYS_INCOME = /(دخل|ايداع|مرتب|راتب|قبضته|قبضتها|جالي|استلمته|استلمتها)/;
const QUESTION = /[؟?]|(^|\s)(هل|ازاي|ليه|ايه|كام|كم)(\s|$)/;

/** النوع اللي العميل بيقول إن الحركة المفروض تبقاه، أو null لو الرسالة مش تصحيح نوع. */
export function kindFixTarget(message: string): "expense" | "income" | null {
  const m = normalize(message ?? "").trim();
  if (!m || m.length > 200 || QUESTION.test(m)) return null;
  const toExpense = NOT_INCOME.test(m) || (RECORDED_AS_INCOME.test(m) && SAYS_EXPENSE.test(m.replace(RECORDED_AS_INCOME, "")));
  const toIncome = NOT_EXPENSE.test(m) || (RECORDED_AS_EXPENSE.test(m) && SAYS_INCOME.test(m.replace(RECORDED_AS_EXPENSE, "")));
  if (toExpense === toIncome) return null; // ولا حاجة، أو الاتنين (مش واضح)
  return toExpense ? "expense" : "income";
}

/** الأرقام اللي في الرسالة (مبالغ محتملة). */
export function amountsIn(message: string): number[] {
  return [...normalize(message ?? "").matchAll(/[0-9]+(?:[.,٫][0-9]+)?/g)]
    .map((x) => Number(x[0].replace(/[,٫]/g, "."))).filter((n) => Number.isFinite(n) && n > 0);
}

export interface RecentTxn { id: string; title?: string | null; amount: number; kind?: string | null }

/** الحركة الوحيدة اللي التصحيح بيقصدها، أو null. */
export function kindFixCandidate(message: string, recent: readonly RecentTxn[] | null | undefined, target: "expense" | "income"): RecentTxn | null {
  const wrong = (recent ?? []).filter((t) => (t.kind === "income" || t.kind === "expense") && t.kind !== target);
  const said = amountsIn(message);
  const pool = said.length ? wrong.filter((t) => said.some((n) => Math.abs(Number(t.amount) - n) < 0.01)) : wrong;
  return pool.length === 1 ? pool[0] : null;
}

/** بعد اللفة: مفيش اقتراح ولا كتابة، والرسالة تصحيح نوع. */
export function shouldForceKindFix(message: string, executedTools: readonly string[], proposals: number): boolean {
  return proposals === 0 && executedTools.length === 0 && kindFixTarget(message) !== null;
}

export function kindFixReply(t: RecentTxn, target: "expense" | "income", currency: string): string {
  const money = currency && currency !== "غير معروف" ? `${t.amount} ${currency}` : `${t.amount}`;
  const from = target === "expense" ? "دخل" : "مصروف";
  const to = target === "expense" ? "مصروف" : "دخل";
  return `«${t.title || "الحركة"}» بـ${money} هتتعدّل من ${from} لـ${to} — أكّد من الكارت وأنا أعدّلها.`;
}
