import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { redactNotificationText, redactForModel } from "./redact.ts";

// النقطة اللي التنقية دي موجودة عشانها: التطبيق سقط إذن قراءة الرسايل وبقى بيقرا رسايل
// البنك من إشعار تطبيق الرسايل، فتطبيقات المراسلة مستثناة من التجاهل عن قصد. يعني رسالة
// شخصية فيها كلمة فلوس ورقم بتوصل السيرفر وبتترسّب في جدولين.

Deno.test("المبلغ بيفضل زي ما هو — هو سبب الرسالة وهو نص السؤال للعميل", () => {
  assertEquals(
    redactNotificationText("خصم 250.75 ريال من حسابك"),
    "خصم 250.75 ريال من حسابك",
  );
  assertEquals(redactNotificationText("تم دفع 1500 جنيه"), "تم دفع 1500 جنيه");
});

Deno.test("أرقام الحسابات والبطاقات والآيبان بتتحجب", () => {
  assertEquals(
    redactNotificationText("مدى 4531 2200 1122 3344 خصم 99"),
    "مدى [بطاقة] خصم 99",
  );
  assertEquals(
    redactNotificationText("حساب SA0380000000608010167519 رصيد 500"),
    "حساب [حساب] رصيد 500",
  );
  assertEquals(
    redactNotificationText("مرجع العملية 987654321"),
    "مرجع العملية [رقم]",
  );
});

Deno.test("التليفون والبريد بيتحجبوا", () => {
  assertEquals(
    redactNotificationText("كلمني +201234567890"),
    "كلمني [تليفون]",
  );
  assertEquals(
    redactNotificationText("ابعت على ahmed.hassan@example.com"),
    "ابعت على [بريد]",
  );
});

Deno.test("رسالة شخصية بتفضل مقروءة من غير المعرّفات", () => {
  // مش المطلوب نخفي إن حد اتكلم عن فلوس — المطلوب إن اللي يترسّب مايبقاش فيه معرّف.
  assertEquals(
    redactNotificationText("ابعتلي 200 جنيه على المحفظة 01012345678"),
    "ابعتلي 200 جنيه على المحفظة [رقم]",
  );
});

Deno.test("مدخل فاضي أو null بيرجع نص فاضي مش استثناء", () => {
  assertEquals(redactNotificationText(""), "");
  assertEquals(redactNotificationText(null), "");
  assertEquals(redactNotificationText(undefined), "");
});

Deno.test("redactForModel keeps amounts up to seven digits and the card's last four, masks accounts and phones", () => {
  const out = redactForModel("تم إيداع 125000.00 جنيه في حسابك 1234567890123 من 01012345678 بطاقة ****4321 IBAN SA4420000001234567891234");
  assertEquals(out.includes("125000.00"), true);
  assertEquals(out.includes("****4321"), true);
  assertEquals(out.includes("1234567890123"), false);
  assertEquals(out.includes("01012345678"), false);
  assertEquals(out.includes("SA4420000001234567891234"), false);
});
