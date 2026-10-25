// learnedFormats.ts — استخدام صيغ البنوك اللي زاد اتعلمها من ردود العملاء (ZAD_PLAN ٢.٣،
// migration 20261025213500). صيغة «اتعلمت» = ٣ عملاء مختلفين و٩٠٪ اتفاق، فرسالة شخصية لعميل واحد
// عمرها ما بتوصل هنا. الدوال نقية؛ القراية من zad_bank_formats_learned في index.ts.

import { knownFinancialSender } from "./notificationGate.ts";
import type { BankCase } from "./evals/bankEval.ts";

export interface LearnedFormat {
  sender: string;
  market: string | null;
  template: string;
  users: number;
  money: number;
  not_money: number;
  top_kind: string | null;
  agreed: boolean;
}

/** نفس تطبيع zad_bank_sender لعنوان الإشعار. */
const norm = (s: string) => s.trim().toLowerCase().slice(0, 80);

/** البنوك اللي اتعلمت: عندها صيغة واحدة على الأقل محسومة إنها فلوس. */
export function learnedSenders(rows: LearnedFormat[]): Set<string> {
  return new Set(rows.filter((r) => r.agreed && r.money > r.not_money).map((r) => r.sender));
}

/**
 * المرسل معروف؟ القايمة الثابتة الأول، وبعدين اللي العملاء علّموه. بنك معروف بياخد حد ثقة أقل
 * في decideGate، ولو الموديل وقع رسالته بتتسأل بدل ما تترمي.
 */
export function senderKnown(packageName: string, title: string, learned: Set<string>): string | null {
  const fixed = knownFinancialSender(packageName, title);
  if (fixed) return fixed;
  const t = norm(title);
  return t && learned.has(t) ? t : null;
}

/** أقصى عدد صيغ متعلَّمة بتدخل التقييم في الليلة — مفتاح التقييم واحد و١٥ طلب في الدقيقة. */
export const LEARNED_EVAL_MAX = 40;

/**
 * الصيغ المحسومة كحالات تقييم: {n} رقم، {party} اسم، {link} بيتشال. بيتقاس القرار والاتجاه بس —
 * المبلغ والتاجر مش معروفين من الصيغة. التحويل مالوش اتجاه يتقاس (للكاش أو بين الحسابات).
 */
export function learnedCases(rows: LearnedFormat[], max = LEARNED_EVAL_MAX): BankCase[] {
  return rows.filter((r) => r.agreed).slice(0, max).map((r, i) => {
    const money = r.money > r.not_money;
    const text = r.template
      .replace(/\{n\}/g, () => "125.50")
      .replace(/\{party\}/g, "Store")
      .replace(/\{link\}/g, "")
      .replace(/\s+/g, " ").trim();
    return {
      id: `learned-${r.market ?? "xx"}-${i + 1}`,
      market: r.market ?? "",
      origin: "learned",
      package: "com.google.android.apps.messaging",
      title: r.sender,
      text,
      expect: money ? "money" : "ignore",
      amount: null,
      direction: money && r.top_kind === "expense" ? "out" : money && r.top_kind === "income" ? "in" : null,
      merchant: null,
      knownSender: true,
    };
  });
}
