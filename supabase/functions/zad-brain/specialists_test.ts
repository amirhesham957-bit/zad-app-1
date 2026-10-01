// specialists_test.ts — اختبارات توجيه الوكلاء المتخصصين.
import { assertEquals } from "jsr:@std/assert@1";
import {
  intentToolHints,
  routeSpecialist,
  routeSpecialists,
  scopeToolsForSpecialist,
  SPECIALISTS,
  specialistPromptBlock,
  unbackedReminderClaim,
} from "./specialists.ts";

Deno.test("رسالة مصاريف بتروح لوكيل المال", () => {
  assertEquals(routeSpecialist("صرفت ٥٠ جنيه على البقالة"), "finance");
});

Deno.test("سؤال رصيد بيتوجّه للمال", () => {
  assertEquals(routeSpecialist("فاضل معايا كام النهاردة؟"), "finance");
});

Deno.test("طلب وجبة بيتوجّه للمخزون", () => {
  assertEquals(routeSpecialist("اعمللي اقتراح عشا من اللي في الخزنة"), "pantry");
});

Deno.test("جرعة دوا بيتوجّه للصيدلية", () => {
  assertEquals(routeSpecialist("سجلي جرعة الدوا الساعة 8 الصبح"), "pharmacy");
});

Deno.test("مهمة/موعد بيتوجّه للعائلة", () => {
  assertEquals(routeSpecialist("فكرني بموعد دكتور الأسنان بكرة"), "family");
});

Deno.test("فاتورة/صيانة بتتوجه لوكيل المنزل والدفع", () => {
  assertEquals(routeSpecialist("التكييف محتاج صيانة والضمان قرب يخلص"), "home");
  assertEquals(routeSpecialist("سددت الفاتورة النهاردة"), "home");
  // "دفعت + اسم الخدمة" فيه كلمتين للمال (دفعت/كهربا) فيكسب المال — ده مقصود: سداد فعلي
  // هو شغلانة المال، والمنزل بياخد الصيانة والأعطال والتتبع.
});

Deno.test("كلام عام يفضل general", () => {
  assertEquals(routeSpecialist("ازيك عامل ايه"), "general");
  assertEquals(routeSpecialist("مين انت"), "general");
});

Deno.test("التطبيع: الهمزة والتاء المربوطة مبتغيرش التوجيه", () => {
  assertEquals(routeSpecialist("أنا صرفت فلوس كتير النهاردة"), "finance");
  assertEquals(routeSpecialist("محتاجة أضيف طماطة للقائمة"), "pantry");
});

Deno.test("كل وكيل متخصص له اسم وسطر حالة", () => {
  for (const id of ["finance", "pantry", "pharmacy", "family", "home"] as const) {
    const s = SPECIALISTS[id];
    assertEquals(typeof s.nameAr, "string");
    assertEquals(s.nameAr.length > 0, true);
    assertEquals(s.activeLineAr.length > 0, true);
  }
  assertEquals(SPECIALISTS.general.activeLineAr, "");
});

Deno.test("general ملوش بلوك برومبت، والمتخصصين عندهم", () => {
  assertEquals(specialistPromptBlock("general"), null);
  for (const id of ["finance", "pantry", "pharmacy", "family", "home"] as const) {
    const block = specialistPromptBlock(id) ?? "";
    assertEquals(block.includes("الوكيل المتخصص"), true);
    assertEquals(block.includes(SPECIALISTS[id].nameAr), true);
  }
});

// بند 31.6 — أساسي + استشاري تانٍ

Deno.test("رسالة بتمس مطبخ وفلوس مع بعض بترجّع أساسي مطبخ واستشاري مال", () => {
  const r = routeSpecialists("اعمللي عشا واطبخ حاجة، وكمان قوللي هل الميزانية هتسمح ولا لأ");
  assertEquals(r.primary, "pantry");
  assertEquals(r.secondary, "finance");
});

Deno.test("رسالة أحادية النطاق ملهاش استشاري", () => {
  const r = routeSpecialists("سجلي جرعة الدوا الساعة 8 الصبح");
  assertEquals(r.primary, "pharmacy");
  assertEquals(r.secondary, null);
});

Deno.test("general ملوش استشاري", () => {
  const r = routeSpecialists("ازيك عامل ايه");
  assertEquals(r.primary, "general");
  assertEquals(r.secondary, null);
});

Deno.test("بلوك البرومبت بيتضمن سطر الاستشاري لو موجود", () => {
  const block = specialistPromptBlock("pantry", "finance") ?? "";
  assertEquals(block.includes("استشارة إضافية"), true);
  assertEquals(block.includes(SPECIALISTS.finance.nameAr), true);
});

Deno.test("بلوك البرومبت من غير استشاري مفيهوش سطر الاستشارة", () => {
  const block = specialistPromptBlock("pantry") ?? "";
  assertEquals(block.includes("استشارة إضافية"), false);
});

Deno.test("أدوات الاستشاري بتتضاف لأدوات الأساسي (اتحاد مش استبدال)", () => {
  const tools = [
    { name: "add_inventory_item" }, // pantry
    { name: "log_transaction" }, // finance
    { name: "add_pharmacy_item" }, // pharmacy — مفيش في الاتنين
  ];
  const scoped = scopeToolsForSpecialist(tools, "pantry", "finance");
  const names = scoped.map((t) => t.name);
  assertEquals(names.includes("add_inventory_item"), true);
  assertEquals(names.includes("log_transaction"), true);
  assertEquals(names.includes("add_pharmacy_item"), false);
});

Deno.test("appointment tools survive every specialist's tool scoping", () => {
  const tools = [{ name: "add_appointment" }, { name: "update_appointment" }, { name: "log_transaction" }];
  for (const sp of ["finance", "pantry", "pharmacy", "family", "home"] as const) {
    const names = scopeToolsForSpecialist(tools, sp).map((t) => t.name);
    assertEquals(names.includes("add_appointment"), true, sp);
    assertEquals(names.includes("update_appointment"), true, sp);
  }
});

Deno.test("reminder and self-introduction intents are recognised in feminine/dialect forms (2026-09-14)", () => {
  assertEquals(routeSpecialist("فكّريني بكرة الساعة ٥ العصر أروح البنك") !== "finance", true);
  assertEquals(intentToolHints("فكّريني بكرة الساعة ٥ العصر أروح البنك").includes("add_appointment"), true);
  assertEquals(intentToolHints("عندي ميعاد دكتور الخميس").includes("add_appointment"), true);
  assertEquals(intentToolHints("على فكرة أنا اسمي كريم وبشتغل محاسب").includes("update_customer_profile"), true);
  assertEquals(intentToolHints("أنا أم لتلات عيال").includes("update_customer_profile"), true);
  assertEquals(intentToolHints("صرفت ٥٠ جنيه قهوة"), []);
  assertEquals(intentToolHints("افتكر إني مش باكل تونة خالص").includes("remember"), true);
});

Deno.test("«جاهز، سُجلت!» على طلب تذكير من غير أي أداة بيتكشف — وسؤال عن الوقت مايتكشفش", () => {
  const ask = "طيب فكرني كمان ٥ د من دلوقتي و بعدين كل ساعة اتفقنا";
  assertEquals(unbackedReminderClaim(ask, "خلاص اتفقنا! هفكرك كمان ٥ دقايق من دلوقتي وبعدين كل ساعة. \n\nجاهز، سُجلت! 👌"), true);
  assertEquals(unbackedReminderClaim(ask, "تحب أفكرك الساعة كام بالظبط؟"), false);
  // مش طلب تذكير أصلاً: «سجلت» هنا عن مصروف، والحارس ده مالوش دعوة.
  assertEquals(unbackedReminderClaim("صرفت ٥٠ جنيه قهوة", "سجلت ٥٠ جنيه قهوة"), false);
});

Deno.test("الصحيان تذكير: «الساعة ٢ الظهر عاوز اصحى» بعد سؤال زاد عن الوقت بيطلب أداة الميعاد (2026-09-30)", () => {
  // اللفة الحقيقية: زاد سأل «قولي عايز أصحيك الساعة كام بالظبط»، والعميل رد بالوقت، وزاد قال
  // «ظبطتهالك وهصحيك» ومفيش ولا أداة اتنادت.
  const prior = "يا سيدي أنا مش مسجلة عندي ميعاد صحيان ولا منبه ليك بكرة الصبح، بس لو حابب أصحيك، قولي عايز أصحيك الساعة كام بالظبط وتؤمر أمر! ⏰😊";
  const message = "الساعة 2 الظهر عاوز اصحي";
  assertEquals(intentToolHints(message, prior).includes("add_appointment"), true);
  // الوقت لوحده، رد على سؤال زاد: النية جاية من السؤال مش من الرسالة.
  assertEquals(intentToolHints("الساعة 2 الظهر", prior).includes("add_appointment"), true);
  assertEquals(intentToolHints("الساعة 2 الظهر"), []);
  assertEquals(intentToolHints("صحيني بكرة ٧ الصبح").includes("add_appointment"), true);
  assertEquals(intentToolHints("اظبطلي منبه الساعة ٦").includes("add_appointment"), true);
  assertEquals(intentToolHints("عاوز أصحى بدري بكرة").includes("add_appointment"), true);
  assertEquals(unbackedReminderClaim("صحيني بكرة ٧ الصبح", "حاضر، هصحيك ٧ الصبح"), true);
  assertEquals(unbackedReminderClaim("صحيني بكرة ٧ الصبح", "تحب أصحيك ٧ ولا ٧ ونص؟"), false);
  assertEquals(
    unbackedReminderClaim(message, "ولا يهمك يا أمير، ظبطتهالك وهصحيك بكرة الساعة 2 الظهر بالضبط متخافش!", prior),
    true,
  );
});

Deno.test("الصحيان مايلخبطش الكلام العادي: «أكل صحي» و«قللت المنبهات» مش تذكير", () => {
  assertEquals(intentToolHints("عايز أكل صحي النهارده"), []);
  assertEquals(intentToolHints("بقلل المنبهات والقهوة"), []);
  // ساعة من غير سؤال تذكير قبلها مش طلب تذكير: «اشتريت عيش الساعة ٨ الصبح».
  assertEquals(intentToolHints("اشتريت عيش الساعة ٨ الصبح", "تمام، سجلتلك العيش"), []);
});

Deno.test("priorAssistantText: الرد اللي قبل آخر رسالة، حتى لو بعدها نداءات أدوات", async () => {
  const { priorAssistantText } = await import("./specialists.ts");
  const history = [
    { role: "user", text: "هتصحيني امتي" },
    { role: "assistant", text: "قولي عايز أصحيك الساعة كام بالظبط" },
    { role: "user", text: "الساعة 2 الظهر" },
    { role: "assistant", text: "" },
    { role: "tool" },
  ];
  assertEquals(priorAssistantText(history), "قولي عايز أصحيك الساعة كام بالظبط");
  assertEquals(priorAssistantText([{ role: "user", text: "أهلا" }]), "");
});

Deno.test("a live price question points at web_search, not at the app's tools (2026-10-01)", () => {
  for (const q of ["كم سعر الذهب اليوم", "كام سعر زجاجة المياه في السعودية", "كم سعر زجاجة حليب فيفا في مصر", "أسعار الطماطم النهارده"]) {
    const hints = intentToolHints(q);
    assertEquals(hints.includes("web_search"), true, q);
    assertEquals(hints.includes("add_appointment"), false, q);
  }
  // His own spending is not a web question.
  assertEquals(intentToolHints("صرفت كام على الأكل الشهر ده").includes("web_search"), false);
  assertEquals(intentToolHints("صرفت ٥٠ جنيه قهوة"), []);
});
