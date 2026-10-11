// provenance.ts — المعاملة جت منين (zad_transactions.source_type).
//
// فحص ما قبل الإطلاق (٢٠٢٦-١٠-١١): إشعار البنك بس اللي كان بيتعلّم (notification_listener).
// فاتورة متصورة ورقم اتكتب بإيد ورسالة في الشات كانوا كلهم من غير مصدر، فالعقل مايقدرش يفرّق
// بين «الـ٤٨٠ دي من بون كارفور» و«الـ٤٨٠ دي العميل قالها». وبعد كده «سجّل الإيصال ده» و«ده
// إيصال؟» محتاجين يعرفوا.
//
// القيمة من قايمة ثابتة: «receipt» بس لو اللي بينادي قال إنها من فاتورة (تليجرام بعد ما قرا
// صورة)، وإلا القناة اللي الأداة اتنادت منها. الموديل مايقدرش يكتب مصدر بنفسه.

import type { AgentSource } from "./audit.ts";

/** المصادر اللي log_transaction بيكتبها. */
export type TxnSource = "receipt" | "telegram" | "voice" | "chat";

export function txnSourceType(asked: unknown, channel: AgentSource): TxnSource {
  if (asked === "receipt") return "receipt";
  if (channel === "telegram") return "telegram";
  if (channel === "voice") return "voice";
  return "chat";
}
