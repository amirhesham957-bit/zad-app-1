import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { attempts, classifyMessage, consume, lockedReply } from "./entitlement.ts";

// القاعدة اللي الاختبارات دي بتحرسها: التسجيل مجاني للأبد، التفكير هو اللي بيتباع.
// أي تسريب في الاتجاه الأول (تسجيل بيتحاسب كتحليل) بيضرب العادة اللي التطبيق كله قايم
// عليها؛ وأي تسريب في الاتجاه التاني (تحليل بيعدي كشات) بيدي المنتج مجاناً.

Deno.test("تسجيل المصاريف العادي مجاني — مهما كانت الصيغة", () => {
  for (
    const m of [
      "صرفت 50 جنيه قهوة",
      "دفعت 200 كهربا",
      "اشتريت 2 كيلو طماطم",
      "سجل 100 مواصلات",
      "ضيف بنادول للمخزون",
      "قبضت المرتب",
      "اشترك نتفليكس 100 في الشهر",
      "امسح آخر معاملة",
    ]
  ) {
    assertEquals(classifyMessage(m), "routine", m);
  }
});

Deno.test("طلب التحليل العميق بيتحاسب على رصيد العقل", () => {
  for (
    const m of [
      "حلل مصاريفي",
      "إيه رأيك في صرفي الشهر ده",
      "توقعاتك لإيجاري الشهر الجاي",
      "فلوسي راحت فين",
      "وفرلي في المصاريف",
      "اعمللي خطة ادخار",
      "قارن مصاريف الشهر ده بالشهر اللي فات",
      "هل أقدر أشتري تلاجة الشهر ده",
    ]
  ) {
    assertEquals(classifyMessage(m), "brain", m);
  }
});

// الحالة دي بالظبط هي سبب ترتيب الفحص: فعل التسجيل بيكسب على كلمة التحليل، عشان
// جملة فيها الاتنين ماتبقاش باب خلفي بيحاسب على التسجيل.
Deno.test("جملة فيها تسجيل وتحليل مع بعض بتفضل مجانية", () => {
  assertEquals(classifyMessage("سجل 50 قهوة وقوللي رأيك في صرفي"), "routine");
  assertEquals(classifyMessage("دفعت 300 وحلل كده"), "routine");
});

Deno.test("الرسالة الفاضية أو الكلام العادي بيعدي كشات", () => {
  assertEquals(classifyMessage(""), "chat");
  assertEquals(classifyMessage("   "), "chat");
  assertEquals(classifyMessage("صباح الخير"), "chat");
  assertEquals(classifyMessage("شكراً"), "chat");
});

// البوابة بتفشل مفتوحة عن قصد: باج في طبقة الفوترة ميصحش يقفل منتج شغال في وش عميل
// دافع. الاختبار ده بيثبت السلوك ده مش بيتغير من غير ما حد ياخد باله.
Deno.test("فشل الـ RPC بيسيب الطلب يعدي بدل ما يقفل التطبيق", async () => {
  const sbError = { rpc: () => Promise.resolve({ data: null, error: { message: "boom" } }) };
  assertEquals(await consume(sbError, "u1", "brain"), { allowed: true, reason: "gate_unavailable" });

  const sbThrows = { rpc: () => Promise.reject(new Error("network")) };
  assertEquals(await consume(sbThrows, "u1", "brain"), { allowed: true, reason: "gate_unavailable" });
});

Deno.test("القرار الراجع من الـ RPC بيتمرر زي ما هو", async () => {
  const sb = {
    rpc: (_name: string, _args: unknown) =>
      Promise.resolve({ data: { allowed: false, reason: "needs_ads_or_upgrade", tier: "free" }, error: null }),
  };
  assertEquals(await consume(sb, "u1", "brain"), {
    allowed: false,
    reason: "needs_ads_or_upgrade",
    tier: "free",
  });
});

Deno.test("رسالة القفل بتفرق بين مش-مشمول وخلص-رصيدك ومحتاج-إعلانات", () => {
  const premium = lockedReply({ allowed: false, reason: "premium_only" });
  assertEquals(premium.includes("للمشتركين"), true);

  const exhausted = lockedReply({ allowed: false, reason: "quota_exhausted", cycle_reset_at: "2026-09-16T00:00:00Z" });
  assertEquals(exhausted.includes("خلصت محاولات باقتك"), true);

  const needsAds = lockedReply({
    allowed: false,
    reason: "needs_ads_or_upgrade",
    left: 1,
    cost: 3,
    cycle_reset_at: "2026-10-12T15:30:00Z",
    next_weekly_free_at: "2026-10-17T00:00:00Z",
  }, "Africa/Cairo");
  // What it costs, what is left, and when the free 5 come back — on the customer's clock.
  assertEquals(needsAds.includes("محتاج ٣ محاولات وفاضل معاك محاولة واحدة"), true);
  assertEquals(needsAds.includes("بيرجع ٥ محاولات الساعة ٦:٣٠"), true);
  assertEquals(needsAds.includes("إعلان قصير"), true);
  assertEquals(needsAds.includes("الأسبوعية"), true);
  // The old 12-hour ad session is gone; nothing may promise it, or «unlimited».
  assertEquals(needsAds.includes("١٢ ساعة"), false);
  assertEquals(needsAds.includes("حدود"), false);
});

Deno.test("العدد والكلمة متوافقين: محاولة واحدة، محاولتين، ٣ محاولات، ١١ محاولة", () => {
  assertEquals(attempts(0), "ولا محاولة");
  assertEquals(attempts(1), "محاولة واحدة");
  assertEquals(attempts(2), "محاولتين");
  assertEquals(attempts(3), "٣ محاولات");
  assertEquals(attempts(10), "١٠ محاولات");
  assertEquals(attempts(11), "١١ محاولة");
  assertEquals(attempts(300), "٣٠٠ محاولة");
});
