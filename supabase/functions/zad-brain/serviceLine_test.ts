// سطر خدمة مش دوا (serviceLine.ts): «توصيل منزلي داخل 600» اتسجل دوا عند المالك ٢٨/١٠.
import { assertEquals } from "jsr:@std/assert@1";
import { isServiceLine } from "./serviceLine.ts";

Deno.test("fees, delivery, tax and totals are not items; medicines are", () => {
  for (const s of ["توصيل منزلي داخل 600", "رسوم خدمة", "ضريبة القيمة المضافة 14%", "الإجمالي", "Delivery fee", "VAT", "خصم العضوية"]) {
    assertEquals(isServiceLine(s), true, s);
  }
  for (const s of ["Diosmin Plus 30 Tabs", "LIMITLESS ALLZYME MAX 20 TAB", "Tavanic 500 Mg", "بنادول اكسترا", "مستخدم", "شراب كحة", null]) {
    assertEquals(isServiceLine(s), false, String(s));
  }
});
