// سلامة الأدوية والتوقيت (٢٠٢٦-٠٩-١٩).
//
// تلات بلاغات من العميل بتتحوّل هنا لحالات: أدوية وهمية، جرعة بتتسجل على الدوا الغلط،
// وميعاد بيتخزن بتوقيت السيرفر بدل توقيت العميل.

import { assert, assertEquals } from "jsr:@std/assert@1";
import { matchMedicineByName, normalizeMedicineName, resolveLocalIso } from "./shared.ts";
import { mentionsRealMedicine } from "./voiceMoments.ts";

// ── التوقيت: +02:00 / +03:00 مقابل UTC ──────────────────────────────────────

Deno.test("وقت من غير منطقة بيتقري بتوقيت العميل مش بتوقيت السيرفر", () => {
  // ٩ بالليل في القاهرة (+02:00) = ١٩:٠٠ UTC. الكود القديم كان بيخزنها ٢١:٠٠ UTC،
  // يعني ١١ بالليل بتوقيته — ساعتين بعد الميعاد.
  assertEquals(resolveLocalIso("2026-09-19T21:00:00", "+02:00"), "2026-09-19T19:00:00.000Z");
  assertEquals(resolveLocalIso("2026-09-19T21:00:00", "+03:00"), "2026-09-19T18:00:00.000Z");
});

Deno.test("وقت بمنطقة صريحة بيتحترم زي ما هو", () => {
  assertEquals(resolveLocalIso("2026-09-19T21:00:00+03:00", "+02:00"), "2026-09-19T18:00:00.000Z");
  assertEquals(resolveLocalIso("2026-09-19T18:00:00Z", "+02:00"), "2026-09-19T18:00:00.000Z");
});

Deno.test("تاريخ لوحده بيبقى بداية اليوم بتوقيت العميل", () => {
  assertEquals(resolveLocalIso("2026-09-19", "+03:00"), "2026-09-18T21:00:00.000Z");
});

Deno.test("مسافة بدل T، ومن غير ثواني — الشكلين اللي الموديل بيكتبهم", () => {
  assertEquals(resolveLocalIso("2026-09-19 21:00", "+02:00"), "2026-09-19T19:00:00.000Z");
  assertEquals(resolveLocalIso("2026-09-19T21:00", "+02:00"), "2026-09-19T19:00:00.000Z");
});

Deno.test("نص مش وقت بيترفض بدل ما يبقى Invalid Date", () => {
  assertEquals(resolveLocalIso("بكرة الساعة ٥", "+02:00"), null);
  assertEquals(resolveLocalIso("", "+02:00"), null);
  assertEquals(resolveLocalIso(null, "+02:00"), null);
});

Deno.test("إزاحة مكسورة بتتعامل كـUTC بدل ما ترمي", () => {
  assertEquals(resolveLocalIso("2026-09-19T21:00:00", "بتاع مصر"), "2026-09-19T21:00:00.000Z");
});

// ── مطابقة اسم الدوا ────────────────────────────────────────────────────────

const MEDS = [
  { id: "1", name: "بانادول اكسترا" },
  { id: "2", name: "حبة الضغط" },
  { id: "3", name: "حبوب الحديد" },
  { id: "4", name: "أوجمنتين" },
];

Deno.test("الاسم الكامل بيطابق", () => {
  assertEquals(matchMedicineByName(MEDS, "بانادول اكسترا").item?.id, "1");
});

Deno.test("كلمة كاملة من اسم مركّب بتطابق", () => {
  assertEquals(matchMedicineByName(MEDS, "بانادول").item?.id, "1");
});

Deno.test("اسم مش موجود بيترفض — أصل منع الهلوسة", () => {
  const m = matchMedicineByName(MEDS, "كونكور");
  assertEquals(m.item, undefined);
  assertEquals(m.ambiguous, undefined);
});

Deno.test("اسم بيطابق أكتر من دوا بيرجع ambiguous بدل ما يختار واحد", () => {
  // تسجيل الجرعة على الدوا الغلط غلط طبي. المطابقة القديمة كانت بتاخد أول واحد في
  // الليستة، واللي اتاخد فعلاً بيفضل مفتوح فالكرون يفضل يزن عليه.
  const m = matchMedicineByName(
    [{ id: "6", name: "فيتامين د" }, { id: "7", name: "فيتامين ب12" }],
    "فيتامين",
  );
  assertEquals(m.item, undefined);
  assertEquals(m.ambiguous?.length, 2);
});

Deno.test("حرف أو حرفين مش اسم — مايتخمّنش عليه", () => {
  assertEquals(matchMedicineByName(MEDS, "د").item, undefined);
  assertEquals(matchMedicineByName(MEDS, "حب").item, undefined);
});

Deno.test("الهمزة و«ال» التعريف مابيكسروش المطابقة", () => {
  assertEquals(matchMedicineByName(MEDS, "اوجمنتين").item?.id, "4");
  assertEquals(normalizeMedicineName("الأوجمنتين"), normalizeMedicineName("اوجمنتين"));
});

// ── حراسة منع الهلوسة في صياغة التنبيه ──────────────────────────────────────

Deno.test("صياغة فيها الاسم الحقيقي بتعدّي", () => {
  assert(mentionsRealMedicine(
    { title: "💊 ميعاد أوجمنتين", text: "ميعاد أوجمنتين دلوقتي", speech: "خد أوجمنتين" },
    { item_name: "أوجمنتين" },
  ));
});

Deno.test("صياغة باسم دوا مخترع بتترفض — ترجع للقالب الثابت", () => {
  assertEquals(mentionsRealMedicine(
    { title: "💊 ميعاد الدوا", text: "خد أموكسيسيلين دلوقتي", speech: "متنساش الأموكسيسيلين" },
    { item_name: "أوجمنتين" },
  ), false);
});

Deno.test("اختصار اسم مركّب مقبول — «بانادول» بدل «بانادول اكسترا»", () => {
  assert(mentionsRealMedicine(
    { title: "💊 بانادول", text: "ميعاد بانادول دلوقتي", speech: "خد بانادول" },
    { item_name: "بانادول اكسترا" },
  ));
});

Deno.test("تنبيه لأكتر من دوا لازم يسمّيهم كلهم", () => {
  const facts = { item_name: "أوجمنتين وحبة الضغط" };
  assertEquals(mentionsRealMedicine(
    { title: "💊 الدوا", text: "خد أوجمنتين", speech: "خد أوجمنتين" }, facts,
  ), false);
  assert(mentionsRealMedicine(
    { title: "💊 الدوا", text: "خد أوجمنتين وحبة الضغط", speech: "خد الاتنين" }, facts,
  ));
});

Deno.test("مفيش اسم في البيانات أصلاً ⇒ القالب بيقول «الدوا» والحراسة ماتعطلش التنبيه", () => {
  assert(mentionsRealMedicine({ title: "💊", text: "ميعاد الدوا", speech: "خده" }, {}));
});
