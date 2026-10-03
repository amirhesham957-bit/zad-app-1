// نطاقات الأولاد بالموافقة (20261003110000، docs/agent/ZAD_LIVING_BRAIN.md الشريحة ٢).
import { assert, assertEquals } from "jsr:@std/assert@1";
import { kidsPlaces } from "./index.ts";
import { FAMILY_ZONE_MOMENTS, momentFallback, momentGate, tooSoonAfterLast } from "./voiceMoments.ts";
import { emotionForMoment } from "../_shared/zadVoice.ts";

const facts = { member_alias: "يوسف", zone_label: "المدرسة", local_time: "11:20", time_zone: "Africa/Cairo" };

Deno.test("خرج من المدرسة: القالب الاحتياطي فيه مين وفين وإمتى، من غير ما يدّعي مكانه دلوقتي", () => {
  const out = momentFallback("family_zone_exit", facts);
  assert(out.title.includes("يوسف") && out.title.includes("المدرسة"));
  assert(out.text.includes("11:20"));
  assert(out.speech.length > 0);
  assert(!out.text.includes("موجود في"));
});

Deno.test("رجع المدرسة: قالب مطمّن", () => {
  const out = momentFallback("family_zone_back", facts);
  assert(out.title.includes("رجع"));
  assert(out.text.includes("المدرسة"));
});

Deno.test("تنبيه الأولاد مابيستناش ساعات الهدوء ولا السقف ولا المسافة بين اللحظات", () => {
  for (const moment of FAMILY_ZONE_MOMENTS) {
    assertEquals(momentGate(moment, 23, 99), null);
    assertEquals(momentGate(moment, 3, 0), null);
    assertEquals(tooSoonAfterLast(moment, Date.now() - 1000, Date.now()), false);
  }
  // لحظة عادية بتستنى، عشان المقارنة تبقى ليها معنى.
  assertEquals(momentGate("place_reminder", 23, 0), "quiet_hours");
});

Deno.test("إحساس اللحظتين: هدوء مش قلق", () => {
  assertEquals(emotionForMoment("family_zone_exit"), "caring");
  assertEquals(emotionForMoment("family_zone_back"), "warm");
});

Deno.test("kids_places في السناب شوت: الحالة ومن إمتى بس، ومفيش حاجة لو مفيش نطاق أو القراية فشلت", () => {
  const out = kidsPlaces({
    data: [{
      member_id: "c1", member_alias: "يوسف", zone_id: "z1", zone: "المدرسة", kind: "school",
      radius_m: 150, state: "left", since: "2026-10-03T08:20:00Z",
    }],
  });
  assertEquals(out.kids_places, [{ child: "يوسف", place: "المدرسة", state: "left", since: "2026-10-03T08:20:00Z" }]);
  assertEquals(JSON.stringify(out).includes("radius"), false);
  assertEquals(kidsPlaces({ data: [] }), {});
  assertEquals(kidsPlaces({ data: null, error: { message: "function does not exist" } }), {});
});
