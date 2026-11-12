// ZAD_PLAN ١٠.٢(أ) شريحة ٢: القواعد الصافية للأدوات الجديدة — نفس التطبيق بالظبط.
import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  afterInstalmentPaid, categoryForCharge, dismissalNote, doseSlotToSnooze, doseTimesOf, matchInsight, paidRenewal,
} from "./appByVoice.ts";
import { intentToolHints } from "./specialists.ts";
import { CHILD_BLOCKED_TOOLS, CONFIRM_REQUIRED_TOOLS, freshContext, MUTATING_TOOLS, validateTool } from "./validators.ts";

Deno.test("a paid instalment counts down, and the last one ends the plan", () => {
  assertEquals(afterInstalmentPaid("موبايل (3 أقساط)"), { title: "موبايل (2 أقساط)", stillRunning: true });
  assertEquals(afterInstalmentPaid("موبايل (1 قسط)"), { title: "موبايل", stillRunning: false });
  assertEquals(afterInstalmentPaid("Laptop (2 installments)"), { title: "Laptop (1 أقساط)", stillRunning: true });
  assertEquals(afterInstalmentPaid("نتفليكس"), { title: "نتفليكس", stillRunning: true });
});

Deno.test("paying moves the renewal one cycle past the payment that was due", () => {
  // Due on the 5th; paid on the 3rd ⇒ the 5th was paid, the next is the 5th of next month.
  assertEquals(
    paidRenewal({ title: "نت", renewal_date: "2026-11-05", billing_cycle: "MONTHLY" }, "2026-11-03"),
    { paidFor: "2026-11-05", next: "2026-12-05", title: "نت", stillRunning: true },
  );
  // A stale date from months ago still pays the one that is due now, not the old one.
  assertEquals(paidRenewal({ title: "نت", renewal_date: "2026-08-05", billing_cycle: "MONTHLY" }, "2026-11-10").paidFor, "2026-12-05");
  assertEquals(paidRenewal({ title: "تأمين", renewal_date: "2026-11-20", billing_cycle: "YEARLY" }, "2026-11-12").next, "2027-11-20");
  // Day 31 in a short month keeps its anchor.
  assertEquals(paidRenewal({ title: "إيجار", renewal_date: null, due_day: 31, billing_cycle: "MONTHLY" }, "2026-11-12"),
    { paidFor: "2026-11-30", next: "2026-12-31", title: "إيجار", stillRunning: true });
  // Nothing to count from: the payment is still the customer's, the date stays unknown.
  assertEquals(paidRenewal({ title: "جيم", renewal_date: null, billing_cycle: "MONTHLY" }, "2026-11-12").next, null);
});

Deno.test("a subscription's payment is booked like the app books it", () => {
  assertEquals(categoryForCharge({ category: "الترفيه", type: "subscription" }), "الترفيه");
  assertEquals(categoryForCharge({ category: "نتفليكس", type: "subscription" }), "الاشتراكات");
  assertEquals(categoryForCharge({ type: "rent" }), "الفواتير");
  assertEquals(categoryForCharge({ type: "installment" }), "الأقساط");
});

Deno.test("the dose put off is the one that just rang, in the customer's own zone", () => {
  const cairo = { date: "2026-11-12", time: "21:10", utc_offset: "+02:00" };
  assertEquals(doseTimesOf("08:00, 21:00,24:00,x"), ["08:00", "21:00"]);
  // 21:00 Cairo = 19:00 UTC.
  assertEquals(doseSlotToSnooze("08:00,21:00", cairo), "2026-11-12T19:00:00.000Z");
  assertEquals(doseSlotToSnooze("08:00,21:00", cairo, "08:00"), "2026-11-12T06:00:00.000Z");
  // A time that is not one of the medicine's is not a dose.
  assertEquals(doseSlotToSnooze("08:00,21:00", cairo, "15:00"), null);
  // Nothing near now: no dose to put off.
  assertEquals(doseSlotToSnooze("08:00", cairo), null);
  assertEquals(doseSlotToSnooze(null, cairo), null);
});

Deno.test("a dismissal leaves the brain the same note the card's buttons leave", () => {
  assertEquals(dismissalNote("not_relevant", "الكهربا"), { scope: "dismissal", note: 'مش مهتم بتنبيهات زي "الكهربا"', confidence: 0.5 });
  assertEquals(dismissalNote("wrong_data", "الكهربا").scope, "data_quality");
  assertEquals(dismissalNote("timing", "الكهربا").confidence, 0.3);
});

Deno.test("the insight closed is one the customer can see, named, never guessed", () => {
  const rows = [
    { id: "a", title: "فاتورة الكهربا أعلى من العادة", about_item: null },
    { id: "b", title: "اللبن هيخلص بكرة", about_item: "لبن" },
    { id: "c", title: "اللبن أرخص في كارفور", about_item: "لبن" },
  ];
  assertEquals(matchInsight(rows, "الكهرباء").row?.id, undefined); // ء ≠ ا: spelled differently, no guess
  assertEquals(matchInsight(rows, "فاتورة الكهربا").row?.id, "a");
  assertEquals(matchInsight(rows, "اللبن").ambiguous?.length, 2);
  assertEquals(matchInsight(rows, "الغاز"), {});
  assertEquals(matchInsight(rows, "ا"), {});
});

Deno.test("paying a subscription books money, so it waits for the customer's yes and a child cannot", () => {
  assert(CONFIRM_REQUIRED_TOOLS.includes("mark_subscription_paid"));
  assert(CHILD_BLOCKED_TOOLS.includes("mark_subscription_paid"));
  for (const t of ["add_shortages_to_shopping", "snooze_pharmacy_dose", "report_price", "clear_place_visits", "rate_recipe", "dismiss_insight"]) {
    assert(MUTATING_TOOLS.includes(t), t);
    assert(!CONFIRM_REQUIRED_TOOLS.includes(t), t);
  }
});

Deno.test("the new tools refuse what the screens would refuse", async () => {
  const v = (tool: string, input: Record<string, unknown>) => validateTool(tool, input, {}, freshContext("u1"));
  assertEquals((await v("mark_subscription_paid", { title: "نت" })).ok, true);
  assertEquals((await v("mark_subscription_paid", {})).ok, false);
  assertEquals((await v("snooze_pharmacy_dose", { name: "بنادول" })).ok, true);
  assertEquals((await v("snooze_pharmacy_dose", { name: "بنادول", minutes: 600 })).ok, false);
  assertEquals((await v("snooze_pharmacy_dose", { name: "بنادول", dose_time: "25:00" })).ok, false);
  assertEquals((await v("report_price", { item: "زيت", price: 85, store: "كارفور" })).ok, true);
  assertEquals((await v("report_price", { item: "زيت", price: 0 })).ok, false);
  assertEquals((await v("report_price", { item: "", price: 10 })).ok, false);
  assertEquals((await v("rate_recipe", { recipe_name: "كشري", liked: false })).ok, true);
  assertEquals((await v("rate_recipe", { recipe_name: "كشري" })).ok, false);
  assertEquals((await v("dismiss_insight", { about: "الكهربا", reason: "not_relevant" })).ok, true);
  assertEquals((await v("dismiss_insight", { about: "الكهربا", reason: "bored" })).ok, false);
  assertEquals((await v("clear_place_visits", {})).ok, true);
  assertEquals((await v("add_shortages_to_shopping", {})).ok, true);
});

Deno.test("each new action comes with the words a customer uses for it", () => {
  const cases: Array<[string, string]> = [
    ["دفعت اشتراك النت", "mark_subscription_paid"],
    ["سددت قسط الموبايل", "mark_subscription_paid"],
    ["ضيف النواقص كلها للقايمة", "add_shortages_to_shopping"],
    ["نزّل الناقص على قايمة المشتريات", "add_shortages_to_shopping"],
    ["أجّل جرعة البنادول ربع ساعة", "snooze_pharmacy_dose"],
    ["فكرني بالدوا بعد نص ساعة", "snooze_pharmacy_dose"],
    ["الزيت في كارفور بقى ب 85", "report_price"],
    ["امسح الأماكن اللي رحتها", "clear_place_visits"],
    ["الكشري اللي اقترحته ماعجبنيش", "rate_recipe"],
    ["الوصفة دي حلوة اوي", "rate_recipe"],
    ["مش عايز أشوف تنبيه الكهربا ده تاني", "dismiss_insight"],
  ];
  for (const [msg, tool] of cases) assert(intentToolHints(msg).includes(tool), `${msg} ⇒ ${tool}: ${intentToolHints(msg)}`);
  assertEquals(intentToolHints("دفعت 50 قهوة").includes("mark_subscription_paid"), false);
});
