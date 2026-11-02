// bankTwin.ts — «إيجار شقة 3500» بعد إشعار البنك بـ3500 هو نفس الدفعة (ZAD_PLAN ٣.٣، ٢٠٢٦-١١-٠٢).
//
// حساب المالك ١/١١: الإيجار اتحسب مرتين (BDC من البنك و«إيجار شقة» من تليجرام بعد ١٨ دقيقة)، ومصروف
// العطار مرتين (البنك والفاتورة بعد ٣٣ دقيقة). صف البنك اللي لسه من غير فئة بياخد الاسم والفئة بدل ما
// يتكتب صف تاني (20261102060000 zad_bank_twin). الرد بيقول إيه اللي حصل، عشان العميل مايدوّرش على صفين.

/** الرد بعد الدمج. [bankTitle] اسم صف البنك قبلها، [at] وقت الإشعار. */
export function bankTwinMergedReply(bankTitle: string, amount: number, title: string, at: string, now = Date.now()): string {
  const mins = Math.max(1, Math.round((now - Date.parse(at)) / 60_000));
  const ago = mins < 60 ? `من ${mins} دقيقة` : `من ${Math.round(mins / 60)} ساعة`;
  const bank = bankTitle.trim() ? ` «${bankTitle.trim()}»` : "";
  return `اتسجلت المعاملة: ${title} — ${amount}. دي نفس حركة البنك${bank} اللي وصلت ${ago}، ` +
    "فسمّيتها بدل ما الدفعة تتحسب مرتين.";
}
