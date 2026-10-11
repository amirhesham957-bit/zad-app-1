// اللي اتقال للمالك فعلاً (٢٠٢٦-١٠-٠٢): «فتحت لك تيكت» من غير تيكت، و«مش بعرف أشيل الأدوية».
import { assert, assertEquals } from "jsr:@std/assert@1";
import { intentToolHints, shouldWidenTools } from "./specialists.ts";

Deno.test("the owner's two failed turns now offer the tool", () => {
  assert(intentToolHints("عاوز اتواصل مع موظف في مشكلة في الصفحة الرئيسية مفهاش مشتريات امازون").includes("open_support_ticket"));
  assert(intentToolHints("لا خلاص مفيش دوة هخدو تآني خلصت كافة ادويتي شلها من الليستة").includes("delete_pharmacy_item"));
  assert(intentToolHints("امسح الكريم من الصيدلية").includes("delete_pharmacy_item"));
});

Deno.test("a reply that sends the customer to a screen, or claims an act, is widened", () => {
  assert(shouldWidenTools("بس عشان أكون أمين معاك، أنا هنا كمساعد مش بعرف أشيل الأدوية من لستتك بنفسي، بس ممكن تدخل على صفحة الصيدلية في التطبيق"));
  assert(shouldWidenTools("ولا يهمك يا أمير، فتحت لك تیکت دعم فني لفريق زاد"));
  assert(shouldWidenTools("مسحت الأدوية من لستتك"));
});

Deno.test("an ordinary answer is not widened", () => {
  assertEquals(shouldWidenTools("عيار 21 النهارده بـ 6,120 جنيه حسب اليوم السابع."), false);
  assertEquals(shouldWidenTools("أهلاً يا أمير، أخبارك إيه؟"), false);
  assertEquals(shouldWidenTools("تحب أسجل لك المصروف ده؟"), false);
});

Deno.test("an expense said in passing brings log_transaction, and «جهزت لك تسجيلها» without it is widened", () => {
  // اختبار القبول بعد نشر الموجات ١–٤ (٢٠٢٦-١٠-١١).
  assert(shouldWidenTools("تمام، جهزت لك تسجيلها بـ50 جنيه قهوة، استنى تأكيدها معاك 👌"));
  assert(shouldWidenTools("حضرتلك المصروف، مستني موافقتك"));
  for (const said of ["صرفت 50 جنيه قهوة", "دفعت ٢٠٠ كهربا", "اشتريت عيش ب15", "50 جنيه على قهوة"]) {
    assert(intentToolHints(said).includes("log_transaction"), said);
  }
  for (const other of ["صرفت كتير الشهر ده؟", "الدولار بكام؟", "عندي ٦ إزايز مية"]) {
    assert(!intentToolHints(other).includes("log_transaction"), other);
  }
  // اقتراح حقيقي بيسأل، مش بيدّعي: «تحب أسجل لك المصروف ده؟» مابيتعادش.
  assertEquals(shouldWidenTools("تحب أسجل لك المصروف ده؟"), false);
});
