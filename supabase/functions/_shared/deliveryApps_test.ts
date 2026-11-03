// تطبيقات التوصيل (ZAD_PLAN ٤.١٠): قايمة مقفولة، والرسوم رقم معقول بس.
import { assertEquals } from "jsr:@std/assert@1";
import { deliveryApp, deliveryFee } from "./deliveryApps.ts";

Deno.test("delivery apps: the known apps in Arabic and English, nothing else", () => {
  assertEquals(deliveryApp("Ninja")?.key, "ninja");
  assertEquals(deliveryApp("نينجا")?.name, "نينجا");
  assertEquals(deliveryApp("Keeta KSA")?.key, "keeta");
  assertEquals(deliveryApp("HungerStation")?.key, "hungerstation");
  assertEquals(deliveryApp("هنقرستيشن")?.key, "hungerstation");
  assertEquals(deliveryApp("To You")?.key, "toyou");
  assertEquals(deliveryApp("تطبيق جاهز")?.key, "jahez");
  // مطعم أو محل أو فاضي = مش تطبيق.
  assertEquals(deliveryApp("البيك"), null);
  assertEquals(deliveryApp("كيو"), null);
  assertEquals(deliveryApp(""), null);
  assertEquals(deliveryApp(null), null);
});

Deno.test("delivery fee: a sensible positive number only", () => {
  assertEquals(deliveryFee(9.5), 9.5);
  assertEquals(deliveryFee("12.00 SAR"), 12);
  assertEquals(deliveryFee(0), null);
  assertEquals(deliveryFee(-3), null);
  assertEquals(deliveryFee(5000), null);
  assertEquals(deliveryFee("free"), null);
});
