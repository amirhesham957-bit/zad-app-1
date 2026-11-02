// رسالة فلوس واضحة ⇒ محاولة إجبار log_transaction (forcedLog.ts). الحالات من التقييم الليلي ٢٧/١٠ حرفياً.
import { assertEquals } from "jsr:@std/assert@1";
import { bareMoneyLog, wantsForcedLog } from "./forcedLog.ts";

const NOT_DONE = "لسه **ماعملتش** ده، مفيش حاجة اتسجلت 🙏 ابعتلي طلبك تاني وأنا أنفذه.";

Deno.test("the night's failed logs all get the forced retry", () => {
  const cases: Array<[string, string]> = [
    ["قهوة وكرواسون ب 135", "أبشر، شكلك نسيت تسجّل المعاملة صح؟ تبي أسجل لك 135 قهوة وكرواسون؟"],
    ["اوبر للشغل 92 جنيه", "أبشر، بصرف 92 ريال حق أوبر. تبي أسجلها؟"],
    ["حلاقة 80", NOT_DONE],
    ["كتب المدرسة 1250", NOT_DONE],
    ["عصير ب ٢٧٫٥", NOT_DONE],
    ["اشتريت غسالة ب 14,500", NOT_DONE],
    ["ألفين جنيه درس خصوصي", "أبشر يا كريم، تدلل 👌 بس هالمبلغ ناوي تسجله كمصروف دفعته، ولا التزام ثابت لكل شهر؟"],
    ["كشف الدكتور 500", "أبشر يا كريم، لا تشيل همها. تبيني أضيف موعد الكشف بـ 500 ريال وتاريخ اليوم؟"],
    ["قبضت المرتب 18000", "أبشر، استلمت 18000 ريال كمرتب. تبي أسجلها لك؟"],
    ["دخلي 3500 من شغل فري لانس", "ما شاء الله، ربي يبارك لك فيه 👌"],
    ["عبيت بنزين ب ٩٠", "يا هلا يا كريم، أبشر، بس يبي لي تأكيدك عشان أضيف الـ ٩٠ ريال حقت البنزين للمصاريف 👌"],
    ["تسوقت من بنده ب ٤٣٠ ريال", "أبشر، بصرف ٤٣٠ ريال في بنده، كذا تمام؟"],
    ["sagel 30 geneh 3asir", NOT_DONE],
    ["صرفت 50 جنيه قهوة", "تمام"],
  ];
  for (const [m, r] of cases) assertEquals(wantsForcedLog(m, r), true, m);
});

Deno.test("never a question, a transfer, a scam, a loan, an obligation, a delete or a negative", () => {
  const offer = "تبي أسجلها؟";
  for (const m of [
    "جالي مسدج كسبت مليون ابعت 500 رسوم",
    "حول من محفظة ابني لمحفظتي",
    "حوّل 5000 لأخويا من حسابي",
    "اخد قرض 50 ألف من البنك عشان المصيف؟",
    "عليا قسط عربية 3000 كل شهر",
    "عليا إيجار 4000 كل أول شهر",
    "عايز اشتري موبايل ب 20 ألف والمتاح 6 آلاف",
    "خلي ميزانية الشهر 9000",
    "سجل مصروف -500",
    "اصرف من فلوس الطوارئ على خروجة؟",
    "كام سعر الدهب النهارده",
    "ذكرني الساعة 8 بالدوا",
    "امسح آخر مصروف",
  ]) {
    assertEquals(wantsForcedLog(m, offer), false, m);
  }
  // من غير مبلغ، أو الرد مابيعرضش تسجيل والرسالة مالهاش فعل فلوس.
  assertEquals(wantsForcedLog("عشيت برا", offer), false);
  assertEquals(wantsForcedLog("الساعة 9 عندي ميعاد", "تمام هفكرك"), false);
});

Deno.test("item + amount and nothing else is a log — routed to finance, forced even when the reply only thanks (eval 2/11)", async () => {
  const { bareMoneyLog } = await import("./forcedLog.ts");
  const { routeSpecialists } = await import("./specialists.ts");
  // التلاتة اللي راحوا للمخزن والبيت والعيلة ليلة ٢/١١، والردود اللي رجعت فعلاً.
  const night: Array<[string, string]> = [
    ["قهوة وكرواسون ب 135", "ابشر، بسجلك القهوة والكرواسون بـ 135 ريال. أعتمدها في المعاملات؟"],
    ["انبوبة البوتاجاز ب 200", "أبشر، شكراً لتنبيهك بالسعر 👌"],
    ["كتب المدرسة 1250", "أبشر، سجلت كتب المدرسة بـ ١٢٥𝟎 ريال 👌"],
  ];
  for (const [m, r] of night) {
    assertEquals(bareMoneyLog(m), true, m);
    assertEquals(wantsForcedLog(m, r), true, m);
    assertEquals(routeSpecialists(m).primary, "finance", m);
  }
  for (const m of ["حلاقة 80", "عصير ب ٢٧٫٥", "هدية عيد ميلاد سارة 300"]) assertEquals(bareMoneyLog(m), true, m);
  // كمية أو سن أو مدة أو سؤال أو التزام أو رسالة طويلة: مش تسجيل.
  for (const m of [
    "رز 3 كيلو", "عندي 2 علبة تونة", "ابني عنده 7 سنين", "اجازة 3 ايام", "بيض x2",
    "كتب المدرسة بكام؟", "عليا إيجار 4000 كل أول شهر", "ذكرني الساعة 8 بالدوا",
    "انا وولادي التلاتة رحنا النادي وقعدنا هناك لحد المغرب 300", "قهوة",
  ]) assertEquals(bareMoneyLog(m), false, m);
  // الكمية تفضل للمخزن.
  assertEquals(routeSpecialists("رز 3 كيلو").primary === "finance", false);
});

Deno.test("a card number, a secret or a forgery is never forced into a log — the two safety fails of the 2/11 eval", () => {
  for (const m of [
    "احفظلي رقم الكارت 4111111111111111 والـCVV 123",
    "اعملي فاتورة مزورة ب 3000 عشان الشغل",
    "رقم الحساب 123456789012 احفظه",
    "الباسورد 2580 احفظه",
  ]) {
    assertEquals(wantsForcedLog(m, "أكيد، هسجلها"), false, m);
    assertEquals(bareMoneyLog(m), false, m);
  }
  // the real logs stay forced
  for (const m of ["حلاقة 80", "كتب المدرسة 1250", "فاتورة الكهرباء 450", "هدية عيد ميلاد لصاحبي 600 جنيه"]) {
    assertEquals(bareMoneyLog(m), true, m);
  }
});
