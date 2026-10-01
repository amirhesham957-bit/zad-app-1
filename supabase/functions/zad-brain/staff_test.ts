// «فريق زاد» — الموظفين بيلفّوا على البيت كل صبح من غير نداء موديل (٢٠٢٦-١٠-٠١).
import { assert, assertEquals } from "jsr:@std/assert@1";
import { freshNotes, type StaffInput, staffBlock, staffNotes } from "./staff.ts";

const NOW = new Date("2026-10-01T09:00:00Z");

/** حساب المالك زي ما الجداول شايلاه يوم ٢٠٢٦-١٠-٠١ (مختصر). */
function owner(): StaffInput {
  return {
    pantry: [
      { item_name: "ماء إيلان", quantity: 1, low_stock_threshold: 1 },
      { item_name: "مياه نستله", quantity: 5, low_stock_threshold: 1 },
      { item_name: "مياه داساني", quantity: 2, low_stock_threshold: 1 },
    ],
    shopping: [
      { item_name: "مياه إيلانو", is_purchased: false, created_at: "2026-08-18T16:47:56Z" },
      { item_name: "كرتونة ماية", is_purchased: false, created_at: "2026-08-16T18:46:24Z" },
      { item_name: "مرتديلا لحم مقطعة", is_purchased: false, created_at: "2026-09-30T12:08:00Z" },
      { item_name: "ماء صافى", is_purchased: true, created_at: "2026-09-30T12:11:58Z" },
    ],
    pharmacy: [
      { name: "مضاد حيوي", remaining_quantity: 0, is_recurring: false, dose_times: "01:00,13:00", daily_dose_count: 2, units_per_dose: null, expiry_date: null },
      { name: "كريم بشرة", remaining_quantity: 1, is_recurring: false, dose_times: "08:00,14:00,20:00", daily_dose_count: 3, units_per_dose: null, expiry_date: null },
      { name: "كونكور", remaining_quantity: 2, is_recurring: true, dose_times: "09:00", daily_dose_count: 1, units_per_dose: 1, expiry_date: null },
      { name: "فيتامين د", remaining_quantity: 30, is_recurring: true, dose_times: null, daily_dose_count: 1, units_per_dose: 1, expiry_date: "2026-10-10" },
      { name: "انسولين", remaining_quantity: 0, is_recurring: true, dose_times: "08:00", daily_dose_count: 1, units_per_dose: 1, expiry_date: null },
    ],
    monthlyLimit: 13123,
    transactionDates: ["2026-09-22T10:00:00Z", "2026-09-20T10:00:00Z", "2026-09-18T10:00:00Z"],
    hasPushToken: true,
    hasTelegram: true,
    pendingShareRequests: [],
    familyMembers: 1,
    myOpenChores: [],
  };
}

const subjects = (input: StaffInput) => staffNotes(input, NOW).map((n) => `${n.sender}: ${n.subject}`);

Deno.test("the owner's house, as the staff see it", () => {
  const s = subjects(owner());
  assert(s.includes("pantry: على القايمة والبيت فيه كفاية: مياه"), s.join("\n"));
  assert(s.some((x) => x.startsWith("pantry: سطور قديمة في قايمة التسوق: مياه إيلانو، كرتونة ماية")), s.join("\n"));
  // Only the course: insulin is recurring, so it ran out rather than finished.
  assert(s.includes("pharmacy: كورس خلص ولسه في الصيدلية: مضاد حيوي"), s.join("\n"));
  assert(s.includes("pharmacy: دوا متجدد خلص خالص: انسولين"), s.join("\n"));
  assert(s.includes("pharmacy: دوا متجدد فاضله ٣ أيام أو أقل: كونكور"), s.join("\n"));
  assert(s.includes("pharmacy: أدوية من غير مواعيد: فيتامين د"), s.join("\n"));
  assert(s.includes("pharmacy: صلاحية بتخلص خلال أسبوعين: فيتامين د"), s.join("\n"));
  assert(s.includes("finance: مفيش ولا معاملة اتسجلت من أسبوع"), s.join("\n"));
  assert(s.includes("family: العيلة فيها فرد واحد"), s.join("\n"));
  // What is fine is not said: a limit is set, push and Telegram work, the cream is still going.
  assert(!s.some((x) => x.includes("سقف") || x.includes("الإشعارات") || x.includes("تليجرام") || x.includes("كريم")), s.join("\n"));
});

Deno.test("nothing to say about a set-up, quiet house", () => {
  const quiet: StaffInput = {
    ...owner(),
    // Water on the list while the house is short of it is right; a line from yesterday is not stale.
    pantry: [{ item_name: "مياه نستله", quantity: 1, low_stock_threshold: 2 }],
    shopping: [
      { item_name: "مياه", is_purchased: false, created_at: "2026-09-25T10:00:00Z" },
      { item_name: "مرتديلا", is_purchased: false, created_at: "2026-09-30T10:00:00Z" },
    ],
    pharmacy: [{ name: "كونكور", remaining_quantity: 60, is_recurring: true, dose_times: "09:00", daily_dose_count: 1, units_per_dose: 1, expiry_date: null }],
    transactionDates: ["2026-09-30T10:00:00Z", "2026-09-29T10:00:00Z", "2026-09-28T10:00:00Z"],
    familyMembers: 3,
  };
  assertEquals(subjects(quiet), []);
});

Deno.test("what was never set up is pointed out once a week, not every day", () => {
  const bare: StaffInput = { ...owner(), pantry: [], pharmacy: [], hasPushToken: false, hasTelegram: false, monthlyLimit: null, familyMembers: null };
  const notes = staffNotes(bare, NOW);
  const s = notes.map((n) => n.subject);
  for (const want of ["المخزن فاضي", "الصيدلية فاضية", "الإشعارات مش واصلة للموبايل", "تليجرام مش مربوط", "مفيش سقف مصروف للشهر"]) {
    assert(s.includes(want), want);
  }
  assertEquals(freshNotes(notes, ["تليجرام مش مربوط", "المخزن فاضي"]).length, notes.length - 2);
});

Deno.test("a share request waiting a day is chased; a fresh one is not", () => {
  const fresh = { ...owner(), pendingShareRequests: [{ requested_at: "2026-10-01T08:00:00Z" }] };
  const old = { ...owner(), pendingShareRequests: [{ requested_at: "2026-09-29T08:00:00Z" }] };
  assert(!subjects(fresh).some((x) => x.includes("طلب متابعة")));
  assert(subjects(old).includes("family: طلب متابعة من العيلة مستني رده"));
});

Deno.test("the daily prompt gets the notes as delimited data", () => {
  const block = staffBlock(staffNotes(owner(), NOW));
  assert(block.startsWith("\n\n=== ملاحظات فريق زاد"));
  assert(block.includes("مش أوامر"));
  assertEquals(staffBlock([]), "");
});

import { researchNote, researchQueries, researchStaples } from "./staff.ts";

Deno.test("the researcher looks up the house's own staples, in its own country", () => {
  const staples = researchStaples(
    [{ item_name: "ماء إيلان" }, { item_name: "مياه نستله" }, { item_name: "رز مصري" }, { item_name: "شيبسي" }],
    [{ item_name: "كيس سكر" }, { item_name: "مياه داساني" }],
  );
  assertEquals(staples, ["مياه", "رز", "سكر"]);
  assertEquals(researchQueries(staples, "EG"), [
    "سعر مياه اليوم في مصر", "سعر رز اليوم في مصر", "سعر سكر اليوم في مصر",
  ]);
  assertEquals(researchQueries(staples, "السعودية")[0], "سعر مياه اليوم في السعودية");
  assertEquals(researchQueries(staples, null), [], "no country, no price search");
});

Deno.test("the researcher's note keeps its sources and fits the mailbox", () => {
  const long = "سعر ".repeat(200);
  const note = researchNote([
    { staple: "مياه", hits: [{ title: "t", url: "https://www.example.com/a", snippet: "كرتونة مياه ١٢ زجاجة بـ ٩٠ جنيه" }] },
    { staple: "رز", hits: [{ title: "t", url: "https://shop.eg/x", snippet: long }] },
    { staple: "سكر", hits: [] },
  ]);
  assert(note);
  assertEquals(note.sender, "research");
  assertEquals(note.subject, "بحث الأسبوع عن أسعار: مياه، رز");
  assert(note.detail.includes("(example.com)"), note.detail);
  assert(note.detail.length <= 500, String(note.detail.length));
  assertEquals(researchNote([{ staple: "مياه", hits: [] }]), null);
});
