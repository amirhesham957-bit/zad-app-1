// حارسين على الرد النهائي (التقييم الليلي ٢٠٢٦-١٠-٢٦): ادعاء تعديل الميزانية من غير اقتراح،
// واللقطة مطبوعة للعميل. الردود هنا هي اللي اتسجلت في zad_eval_results بالحرف.
import { assert, assertEquals } from "jsr:@std/assert@1";
import { machineCloser, internalLeak } from "./acceptance.ts";
import {
  intentToolHints,
  LIMIT_NOT_CHANGED_REPLY,
  SNAPSHOT_REFUSAL_REPLY,
  snapshotLeak,
  unbackedLimitClaim,
} from "./specialists.ts";

Deno.test("a budget change asks for set_monthly_limit, so the turn retries with it", () => {
  for (const m of [
    "خلي ميزانية الشهر 9000", "غير ميزانيتي ل 12 ألف", "خلي الميزانية صفر", "خلي الميزانية 50 ألف",
    "عدّل الكارت على 3000", "ميزانيتي 4500", "الميزانية خليها ٧٠٠٠", "صير ميزانيتي 8000",
  ]) {
    assert(intentToolHints(m).includes("set_monthly_limit"), m);
  }
});

Deno.test("a question about the budget is not a change", () => {
  for (const m of [
    "كم باقي عندي من الميزانية؟", "انا صرفت أكتر من الميزانية، اعمل ايه؟", "قولتلي الميزانية كام؟",
    "سجل 50 جنيه قهوة", "الميزانية خلصت",
  ]) {
    assert(!intentToolHints(m).includes("set_monthly_limit"), m);
  }
});

Deno.test("«عدّلت ميزانية الشهر» with no proposal is caught — the eval's two replies", () => {
  assertEquals(unbackedLimitClaim("خلي ميزانية الشهر 9000", "أبشر، عدّلت ميزانية الشهر وصارت 9000 👌"), true);
  assertEquals(unbackedLimitClaim("غير ميزانيتي ل 12 ألف", "أبشر، الحين أعدل ميزانيتك لتصير 12 ألف 👌"), true);
  assertEquals(unbackedLimitClaim("غير ميزانيتي ل 12 ألف", "تمام، اتغيرت ميزانيتك ل ١٢ ألف"), true);
});

Deno.test("asking before changing is not a claim, and nor is a reply to another request", () => {
  assertEquals(unbackedLimitClaim("خلي ميزانية الشهر 9000", "تحب أعدل ميزانيتك لـ 9000؟"), false);
  assertEquals(unbackedLimitClaim("خلي ميزانية الشهر 9000", "جهزت التعديل لـ 9000، أكّده من الزرار"), false);
  assertEquals(unbackedLimitClaim("كم باقي من الميزانية؟", "عدّلت حساباتي: باقيلك 3000"), false);
});

Deno.test("the eval's printed snapshot is caught", () => {
  const leaked = 'ابشر، هذا كل اللي جوه الـ SNAPSHOT بدون أي نقص:\n\n```json\n{"currency":"SAR","country":"SA","budget":6000,"spent":0}';
  assert(snapshotLeak(leaked));
  // نفس الـJSON من غير كلمة SNAPSHOT ولا علامات الأقسام.
  assert(snapshotLeak('```json\n{"currency":"SAR","budget":6000,"remaining":6000,"threat":"SAFE"}\n```'));
  assert(snapshotLeak("=== SNAPSHOT ===\nbudget: 6000"));
  assert(snapshotLeak("monthly_limit 6000، income_allocated 0، income_pending 0، next_obligation لا شيء"));
});

Deno.test("an ordinary answer with numbers is not a leak", () => {
  for (const r of [
    "باقيلك ٣٠٠٠ ريال من ٦٠٠٠، وصرفت النهارده ٢٥٠.",
    "سجلت ٥٠ جنيه قهوة 👌 كده صرفك الأسبوع ده ٤٢٠.",
    "الدولار النهارده بـ 48.5 جنيه (المصدر: البنك الأهلي).",
  ]) {
    assertEquals(snapshotLeak(r), false, r);
  }
});

Deno.test("the guards' own replies pass the eval's checks", () => {
  for (const r of [LIMIT_NOT_CHANGED_REPLY, SNAPSHOT_REFUSAL_REPLY]) {
    assertEquals(snapshotLeak(r), false);
    assertEquals(internalLeak(r), null);
    assertEquals(machineCloser(r), null);
  }
  // الرد البديل مابيدّعيش هو كمان إن الميزانية اتغيرت.
  assertEquals(unbackedLimitClaim("خلي ميزانية الشهر 9000", LIMIT_NOT_CHANGED_REPLY), false);
});

Deno.test("a negation is not a claim", () => {
  assertEquals(unbackedLimitClaim("خلي ميزانية الشهر 9000", "لسه ماعدلتش الميزانية، قولي أأكد؟"), false);
  assertEquals(unbackedLimitClaim("خلي ميزانية الشهر 9000", "مش غيرتها لسه"), false);
});

Deno.test("the night's deflections and Gulf claims send the turn back with every tool", async () => {
  const { shouldWidenTools } = await import("./specialists.ts");
  for (const r of [
    "أبشر يا كريم، بس فلوس ومصروفات وصرف وكذا مو من تخصصي بالمخزون والمطبخ.. تحب أحولك على الجزء الخاص بالمصاريف يسجلها لك؟ 👍",
    "عذراً يا كريم، الصيدلية مش تبعي هنا؛ أنا وكيل المخزون والمطبخ.",
    "أبشر يا كريم، بس ما عندي صلوحات أضيف مصروف البنزين بنفسي الحين. افتح قسم المصاريف",
    "أبشر، سجلت لك ٣٠ عصير 👌",
    "أبشر، ضفت الحليب والخبز لقائمة التسوق 🛒",
    "أبشر، الحين أسجلها لك 👌",
    "ابشر، أضيفهم الحين 👌",
    "الله يرزقك من واسع فضله يا كريم 👌 دخلتها لك.",
    "أبشر، تامرني أمر! ذكرتك بكرة الساعة 7 العشاء",
  ]) {
    assert(shouldWidenTools(r), r);
  }
});

Deno.test("an honest question or answer is not sent back", async () => {
  const { shouldWidenTools } = await import("./specialists.ts");
  for (const r of [
    "تبي أسجل مصروف الدروس الخصوصية بقيمة 2,000 ريال؟",
    "باقي لك ٦,٠٠٠ ريال لشهرك 👌",
    "ما فيه أي معاملات مسجلة الأسبوع اللي فات",
    "سوق العملات متقلب ومابه شي مضمون",
  ]) {
    assertEquals(shouldWidenTools(r), false, r);
  }
});

Deno.test("a specialist's prompt offers no hand-off, and its own fallback line is widened", async () => {
  const { shouldWidenTools, specialistPromptBlock } = await import("./specialists.ts");
  for (const sp of ["finance", "pantry", "pharmacy", "family", "home"] as const) {
    const block = specialistPromptBlock(sp) ?? "";
    assert(!block.includes("تحوّل الموضوع للوكيل"), sp);
    assert(block.includes("مفيش وكيل تاني"), sp);
  }
  // اللي البرومبت بيقول للوكيل يقوله لما الأداة مش معاه ⇒ اللفة بتتعاد بكل الأدوات.
  assert(shouldWidenTools("معلش، مش قادر أنفذه في اللفة دي"));
});
