// proposalStop.ts — لفة كل أدواتها اقتراحات فلوس ⇒ مفيش نداء موديل تاني لمجرد «أكّد من الكارت» (ZAD_PLAN ٣.٢).
//
// المقاس ١٥/١١ (٧ أيام، ١٩٦٢ لفة شات): ~٤٥٠ لفة فيها log_transaction، وفي كل واحدة النداء التاني بيبعت البرومبت
// كله تاني (~١٣ ألف توكن) عشان نتيجة الأداة كانت `status=awaiting_user_confirmation` والقاعدة بتقول «قول إنك
// محتاج موافقته». الكارت هو الموافقة نفسها، فالرد بيتكتب من الاقتراح زي forcedLogReply بالظبط.
//
// بنقف بس لما مفيش حاجة تانية مطلوبة في نفس الرسالة: كل نداءات اللفة اتحوّلت لاقتراح، ومفيش نية لأداة تانية
// لسه ماتندهتش، والمبالغ في الرسالة مش أكتر من الاقتراحات («قهوة 50 وعيش 20» باقتراح واحد ⇒ نكمّل)، ومفيش
// طلب تاني بعد «و» («وفكرني»، «وضيف»).

import { forcedLogReply } from "./forcedLog.ts";

const normalize = (text: string) =>
  text.replace(/[ً-ٰٟـ]/g, "").replace(/[أإآ]/g, "ا").replace(/ى/g, "ي").replace(/ة/g, "ه").toLowerCase();

/** كل رقم لوحده (١٤٫٥٠٠ أو 14,500 رقم واحد). */
const NUMBER = /[0-9٠-٩]+(?:[.,٫٬][0-9٠-٩]+)*/g;

/** طلب تاني في نفس الرسالة: «… وفكرني بكرة»، «… وكمان ضيف عيش». */
const SECOND_REQUEST =
  /(^|\s)(و|وكمان|كمان|وبعدين|بعدين|ثم)\s?(ضيف|زود|زوّد|اضف|فكرني|ذكرني|احجز|شيل|امسح|احذف|الغي|عدل|غير|ابعت|قولي|قلي|اعمل|حط|افتكر)/;

export interface ProposalRound {
  /** أسماء الأدوات اللي الموديل نداها في اللفة دي. */
  calledTools: readonly string[];
  /** كام نداء منهم بقى اقتراح متحقق منه (مش مرفوض). */
  proposedInRound: number;
  /** نية الأدوات من الرسالة (intentToolHints). */
  hintedTools: readonly string[];
  /** الأدوات اللي اتندهت في اللفات اللي قبل كده (gold_price قبل log_transaction مثلاً) — نيتها اتقضت. */
  calledBefore?: readonly string[];
  /** الأدوات اللي محتاجة تأكيد (CONFIRM_REQUIRED_TOOLS). */
  confirmTools: readonly string[];
  /** كل الاقتراحات لحد دلوقتي في اللفة كلها. */
  totalProposals: number;
  message: string;
}

/** اللفة تقف هنا والرد يتكتب من الاقتراحات؟ */
export function endsOnProposals(r: ProposalRound): boolean {
  if (r.calledTools.length === 0 || r.proposedInRound !== r.calledTools.length) return false;
  if (!r.calledTools.every((t) => r.confirmTools.includes(t))) return false;
  const done = new Set([...(r.calledBefore ?? []), ...r.calledTools]);
  if (r.hintedTools.some((t) => !r.confirmTools.includes(t) && !done.has(t))) return false;
  const m = normalize(r.message ?? "");
  if (SECOND_REQUEST.test(m)) return false;
  const amounts = (m.match(NUMBER) ?? []).length;
  return amounts <= r.totalProposals;
}

/** الرد من الاقتراحات بدل نداء الموديل. */
export function proposalsReply(summaries: readonly string[], tools: readonly string[] = []): string {
  // «رجع في» اتقال على التليجرام ٢١/١١ والكارت قال «وأنا أسجّله» وهو بيمسح.
  if (summaries.length === 1) return forcedLogReply(summaries[0], proposalVerb(tools[0]));
  return `${summaries.join("، و")} — أكّد من الكروت وأنا أسجّلهم.`;
}

/** الفعل اللي بعد «أكّد من الكارت وأنا …» حسب الأداة. */
export function proposalVerb(tool: string | undefined): string {
  if (tool === "delete_transaction") return "أمسحها";
  if (tool === "update_transaction") return "أعدّلها";
  return "أسجّله";
}
