import { assertEquals, assertStrictEquals } from "jsr:@std/assert@1";
import {
  dietaryConstraints,
  daysOfSupplyLeft,
  hasHealthConsent,
  isAdEligible,
  refillReminders,
  scopedForMember,
  wipeHealthProfile,
  type HealthMed,
  type HealthProfile,
} from "./health.ts";

const NOW = new Date("2026-11-22T10:00:00Z");
const CONSENTED = "2026-11-01T08:00:00Z";

function profile(over: Partial<HealthProfile> = {}): HealthProfile {
  return {
    consent: true,
    consentedAt: CONSENTED,
    memberId: "m-me",
    conditions: [],
    meds: [],
    ...over,
  };
}

function med(id: string, name: string, dosesPerDay: number, unitsLeft: number): HealthMed {
  return { id, name, dosesPerDay, unitsLeft };
}

Deno.test("من غير موافقة صريحة ⇒ مافيش موافقة", () => {
  assertStrictEquals(hasHealthConsent(profile({ consent: false })), false);
});

Deno.test("consent=true من غير consentedAt ⇒ مش موافقة (لازم الاتنين)", () => {
  assertStrictEquals(hasHealthConsent(profile({ consentedAt: undefined })), false);
  assertStrictEquals(hasHealthConsent(profile({ consentedAt: "" })), false);
});

Deno.test("consent + consentedAt ⇒ موافقة", () => {
  assertStrictEquals(hasHealthConsent(profile()), true);
});

Deno.test("من غير موافقة: النصايح الغذائية بترجع فاضية حتى لو فيه حالات", () => {
  const p = profile({ consent: false, conditions: ["سكر", "أنيميا"] });
  assertEquals(dietaryConstraints(p), []);
});

Deno.test("الحالات المعلنة بتتحول لنصايح من الجدول الثابت، من غير تكرار", () => {
  const p = profile({ conditions: ["سكر", "أنيميا", "سكر"] });
  assertEquals(dietaryConstraints(p), ["قلّل السكر المضاف", "زوّد الأكل الغني بالحديد"]);
});

Deno.test("حالة مش في الجدول أو اسم غريب (زي prototype) ⇒ مافيش نصيحة", () => {
  const p = profile({ conditions: ["صداع", "constructor", "__proto__", "toString"] });
  assertEquals(dietaryConstraints(p), []);
});

Deno.test("لا يوجد مسار استنتاج: الأدوية أو الشراء مايولّدوش نصيحة حمل/سكر", () => {
  // الدالة بتقرأ conditions بس. الأدوية مابتأثرش على النصايح، والمشتريات ماتدخلش خالص.
  // لو حد ضاف دوا اسمه "حمل" أو "سكر" من غير حالة معلنة، المخرج لازم يفضل فاضي.
  const p = profile({ conditions: [], meds: [med("x", "فيتامين حمل", 1, 30), med("y", "أنسولين", 2, 20)] });
  assertEquals(dietaryConstraints(p), []);
});

Deno.test("daysOfSupplyLeft: الكمية ÷ الجرعات في اليوم", () => {
  assertEquals(daysOfSupplyLeft(med("a", "دوا", 2, 10)), 5);
});

Deno.test("daysOfSupplyLeft: جرعات صفر أو سالب أو NaN ⇒ null", () => {
  assertStrictEquals(daysOfSupplyLeft(med("a", "دوا", 0, 10)), null);
  assertStrictEquals(daysOfSupplyLeft(med("a", "دوا", -1, 10)), null);
  assertStrictEquals(daysOfSupplyLeft(med("a", "دوا", Number.NaN, 10)), null);
});

Deno.test("refillReminders من غير موافقة ⇒ فاضية", () => {
  const p = profile({ consent: false, meds: [med("a", "دوا", 1, 1)] });
  assertEquals(refillReminders(p, NOW), []);
});

Deno.test("refillReminders: حد الـleadDays شامل، والأكتر منه بيتشال", () => {
  const p = profile({
    meds: [
      med("in", "أ", 1, 5), // ٥ أيام ⇒ يدخل (الافتراضي ٥)
      med("out", "ب", 1, 6), // ٦ أيام ⇒ لأ
    ],
  });
  assertEquals(refillReminders(p, NOW).map((r) => r.medId), ["in"]);
});

Deno.test("refillReminders: leadDays مخصص", () => {
  const p = profile({ meds: [med("a", "أ", 1, 3), med("b", "ب", 1, 8)] });
  assertEquals(refillReminders(p, NOW, 10).map((r) => r.medId), ["a", "b"]);
});

Deno.test("refillReminders: مرتّبة من الأقرب للخلاص", () => {
  const p = profile({
    meds: [med("c", "ج", 1, 4), med("a", "أ", 1, 1), med("b", "ب", 1, 3)],
  });
  const out = refillReminders(p, NOW);
  assertEquals(out.map((r) => r.medId), ["a", "b", "c"]);
  assertEquals(out.map((r) => r.daysLeft), [1, 3, 4]);
});

Deno.test("refillReminders: الرسالة عامية مصرية وفيها اسم الدوا والأيام", () => {
  const p = profile({ meds: [med("a", "كونجستال", 1, 2), med("b", "بروفين", 1, 0)] });
  const out = refillReminders(p, NOW);
  assertEquals(out[0].message, "بروفين قربت تخلص، فكّر تجيب الكمية الجاية النهارده.");
  assertEquals(out[1].message, "باقي 2 أيام على كونجستال، فكّر تجيب الكمية الجاية.");
});

Deno.test("scopedForMember: الطالب يشوف ملفه هو بس، وصحة الفرد التاني مابتتعرضش", () => {
  const me = profile({ memberId: "m-me" });
  const kid = profile({ memberId: "m-kid", conditions: ["سكر"] });
  assertEquals(scopedForMember([me, kid], "m-me").map((p) => p.memberId), ["m-me"]);
  assertEquals(scopedForMember([me, kid], "m-kid").map((p) => p.memberId), ["m-kid"]);
});

Deno.test("scopedForMember: requester فاضي أو مش موجود ⇒ مافيش", () => {
  const me = profile({ memberId: "m-me" });
  assertEquals(scopedForMember([me], ""), []);
  assertEquals(scopedForMember([me], "m-unknown"), []);
});

Deno.test("isAdEligible: سطح الصحة ممنوع، والباقي مسموح", () => {
  assertStrictEquals(isAdEligible({ surface: "health" }), false);
  assertStrictEquals(isAdEligible({ surface: "home" }), true);
  assertStrictEquals(isAdEligible({ surface: "shopping" }), true);
});

Deno.test("wipeHealthProfile: يفضّي كل حاجة ويسيب memberId", () => {
  const p = profile({ conditions: ["سكر"], meds: [med("a", "أ", 1, 1)] });
  const w = wipeHealthProfile(p);
  assertEquals(w, { consent: false, memberId: "m-me", conditions: [], meds: [] });
  assertStrictEquals(hasHealthConsent(w), false);
});

Deno.test("wipeHealthProfile: مايعدّلش الأصل (immutable)", () => {
  const p = profile({ conditions: ["سكر"] });
  wipeHealthProfile(p);
  assertEquals(p.conditions, ["سكر"]);
  assertStrictEquals(p.consent, true);
});
