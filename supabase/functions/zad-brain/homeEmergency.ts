// homeEmergency.ts — حارس الطوارئ المنزلية (ZAD_LIVING_BRAIN.md الشريحة ٤٣).
//
// الفنيين اللي العميل بيثق فيهم (`zad_trusted_technicians`). العقل بيشوف **الاسم والصنعة بس** — الأرقام بتفضل في
// التطبيق (كارت فوق خانة الكتابة بيفتح القايمة بنقرة ويتصل). رقم تليفون حد تالت مالوش لازمة في برومبت موديل.
// كشف الكلمات نفسه في التطبيق (`shared/household/domain/home_emergency.dart`)؛ هنا الموديل بيفهم الطوارئ من الكلام.

export interface TechnicianLite {
  name: string;
  trade: string;
}

const TRADE_AR: Record<string, string> = {
  plumber: "سباك", electrician: "كهربائي", gas: "فني غاز", ac: "تكييف", carpenter: "نجار",
  locksmith: "كوالين ومفاتيح", appliances: "أجهزة", other: "تاني",
};

/** الصفوف ⇒ اسم وصنعة بالعربي بس. أي عمود تاني (الرقم، الملاحظة) بيتشال هنا. */
export function techniciansForSnapshot(rows: ReadonlyArray<Record<string, unknown>>): TechnicianLite[] {
  return rows.slice(0, 20).map((r) => ({
    name: String(r.name ?? "").trim(),
    trade: TRADE_AR[String(r.trade ?? "")] ?? "تاني",
  })).filter((t) => t.name.length > 0);
}

/** قاعدة البرومبت — دايماً موجودة لأن الطوارئ بتيجي من غير مقدمات. */
export function homeEmergencyRule(snap: { trusted_technicians?: TechnicianLite[] | null } | null | undefined): string {
  const list = snap?.trusted_technicians ?? [];
  const who = list.length > 0
    ? `فنيينه (trusted_technicians): ${list.map((t) => `${t.name} (${t.trade})`).join("، ")}.`
    : "مالوش فنيين متسجلين.";
  return "**طوارئ البيت** (مية بتنزل، ماس كهربا، ريحة غاز، باب اتقفل، جهاز عطل فجأة): رد قصير جداً. " +
    "ريحة غاز ⇒ أول جملة: يقفل المحبس ويفتح الشبابيك وماايشغّلش ولا يطفّي أي كهربا، وبعدين يتصل. ماس أو حريق ⇒ يفصل السكينة لو آمن. " +
    `${who} سمّي اللي صنعته مناسبة بالاسم وقوله إن رقمه في الكارت اللي ظهر فوق خانة الكتابة (أو «الصيانة» ← «فنيين بثق فيهم»). ` +
    "**ماتألّفش رقم تليفون أبداً** ولا تقترح فني من عندك. مفيش فني مناسب ⇒ بعد ما الطوارئ تعدّي اقترح يضيفه هناك.";
}
