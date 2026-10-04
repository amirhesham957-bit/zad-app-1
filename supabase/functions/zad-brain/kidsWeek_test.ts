// أسبوع الأولاد: نسبة المهام لكل طفل ⇒ مكافأة جوه الميزانية أو مهمة أصغر، لولي الأمر.
import { assert, assertEquals } from "jsr:@std/assert@1";
import { isoWeekKey, kidsWeekFrom, type StaffInput, staffNotes } from "./staff.ts";

const THURSDAY = new Date("2026-10-08T09:00:00Z");
const day = (d: number) => new Date(THURSDAY.getTime() - d * 86_400_000).toISOString();

const kids = [{ id: "omar", alias: "عمر" }, { id: "salma", alias: "سلمى" }];
const chores = [
  // عمر: ٤ من ٥ الأسبوع ده، وواحدة قديمة مابتتحسبش.
  ...[1, 2, 3, 4].map((d) => ({ assigned_to: "omar", is_completed: true, completed_at: day(d), due_date: day(d), created_at: day(d + 1), reward_amount: 5 })),
  { assigned_to: "omar", is_completed: false, completed_at: null, due_date: day(1), created_at: day(3), reward_amount: 5 },
  { assigned_to: "omar", is_completed: true, completed_at: day(20), due_date: day(20), created_at: day(21), reward_amount: 5 },
  // سلمى: ١ من ٣ (واحدة من غير ميعاد بتتحسب بتاريخ إنشائها).
  { assigned_to: "salma", is_completed: true, completed_at: day(2), due_date: null, created_at: day(3), reward_amount: 0 },
  { assigned_to: "salma", is_completed: false, completed_at: null, due_date: day(2), created_at: day(4), reward_amount: 0 },
  { assigned_to: "salma", is_completed: false, completed_at: null, due_date: null, created_at: day(5), reward_amount: 0 },
];

Deno.test("kids week: each child's chores due or done in the last seven days", () => {
  assertEquals(kidsWeekFrom(kids, chores, THURSDAY), [
    { alias: "عمر", assigned: 5, completed: 4, reward_total: 20 },
    { alias: "سلمى", assigned: 3, completed: 1, reward_total: 0 },
  ]);
});

function house(kidsWeek: StaffInput["kidsWeek"]): StaffInput {
  return {
    pantry: [{ item_name: "رز", quantity: 2, low_stock_threshold: 1 }], shopping: [],
    pharmacy: [{ name: "فيتامين", remaining_quantity: 30, is_recurring: true, dose_times: "09:00", daily_dose_count: 1, units_per_dose: 1, expiry_date: null }],
    monthlyLimit: 10000, transactionDates: ["2026-10-07T10:00:00Z"], hasPushToken: true, hasTelegram: true,
    pendingShareRequests: [], familyMembers: 3, myOpenChores: [], kidsWeek,
  };
}

Deno.test("kids week: 80% earns a reward suggestion within the budget, under 40% a smaller task, no blame", () => {
  const notes = staffNotes(house({ week: "2026-W41", kids: kidsWeekFrom(kids, chores, THURSDAY) }), THURSDAY)
    .filter((n) => n.subject.startsWith("أسبوع"));
  assertEquals(notes.map((n) => n.subject), ["أسبوع عمر (2026-W41): 4 من 5", "أسبوع سلمى (2026-W41): 1 من 3"]);
  assert(notes[0].detail.includes("مكافأة تشجّعه جوه الميزانية"));
  assert(notes[0].detail.includes("من غير مقارنة"));
  assert(notes[1].detail.includes("مهمة واحدة أصغر بدل اللوم"));
  assert(notes.every((n) => n.sender === "family"));
});

Deno.test("kids week: the middle, a single chore, or no week says nothing", () => {
  const quiet = staffNotes(house({ week: "2026-W41", kids: [
    { alias: "عمر", assigned: 5, completed: 3, reward_total: 0 },
    { alias: "سلمى", assigned: 1, completed: 0, reward_total: 0 },
  ] }), THURSDAY).filter((n) => n.subject.startsWith("أسبوع"));
  assertEquals(quiet, []);
  assertEquals(staffNotes(house(null), THURSDAY).filter((n) => n.subject.startsWith("أسبوع")), []);
});

Deno.test("kids week: the week key is ISO, so each week is said once", () => {
  assertEquals(isoWeekKey(THURSDAY), "2026-W41");
  assertEquals(isoWeekKey(new Date("2027-01-01T09:00:00Z")), "2026-W53");
});
