// الهدف ماشي على جدوله ولا متأخر — وفريق زاد بيقترح خطوة لبكرة للمتأخر بس.
import { assert, assertEquals } from "jsr:@std/assert@1";
import { goalPace } from "./goalPace.ts";
import { type StaffInput, staffNotes } from "./staff.ts";

const NOW = new Date("2026-10-04T09:00:00Z");

Deno.test("goal pace: the owner's weekly goal (2 of 12, the third review due tomorrow) is on track", () => {
  // agent_goals on the live project, 2026-10-04.
  const p = goalPace({ target_value: "12", current_value: "2", deadline_date: "2026-12-13", created_at: "2026-09-14T18:31:09Z" }, NOW)!;
  assertEquals(p.pace, "on_track", "a straight line says 2.6 by now; one review short of a weekly rhythm is not behind");
  assertEquals(p.expected_by_now, 2.6);
  assertEquals(p.days_left, 71);
});

Deno.test("goal pace: a real gap is behind, a passed deadline is overdue, and reaching it is done", () => {
  const save = { target_value: 500, deadline_date: "2026-10-31", created_at: "2026-09-01T00:00:00Z" };
  assertEquals(goalPace({ ...save, current_value: 100 }, NOW)?.pace, "behind"); // ~274 expected by now
  assertEquals(goalPace({ ...save, current_value: 230 }, NOW)?.pace, "on_track"); // short by less than 15% of 500
  assertEquals(goalPace({ ...save, current_value: 500 }, NOW)?.pace, "done");
  assertEquals(goalPace({ ...save, current_value: 300, deadline_date: "2026-09-30" }, NOW)?.pace, "overdue");
  assertEquals(goalPace({ ...save, current_value: 0, created_at: "2026-10-02T00:00:00Z" }, NOW)?.pace, "early");
});

Deno.test("goal pace: a goal with no number or no deadline has no schedule to judge", () => {
  assertEquals(goalPace({ target_value: null, current_value: 0, deadline_date: "2026-12-01", created_at: "2026-09-01" }, NOW), null);
  assertEquals(goalPace({ target_value: 10, current_value: 0, deadline_date: null, created_at: "2026-09-01" }, NOW), null);
  assertEquals(goalPace({ target_value: 10, current_value: 0, deadline_date: "2026-08-01", created_at: "2026-09-01" }, NOW), null);
});

function house(goals: StaffInput["goals"]): StaffInput {
  return {
    pantry: [{ item_name: "رز", quantity: 2, low_stock_threshold: 1 }],
    shopping: [],
    pharmacy: [{ name: "فيتامين", remaining_quantity: 30, is_recurring: true, dose_times: "09:00", daily_dose_count: 1, units_per_dose: 1, expiry_date: null }],
    monthlyLimit: 10000,
    transactionDates: ["2026-10-03T10:00:00Z"],
    hasPushToken: true,
    hasTelegram: true,
    pendingShareRequests: [],
    familyMembers: null,
    myOpenChores: [],
    goals,
  };
}

Deno.test("staff: a lagging goal gets one small step for tomorrow; one on track gets nothing", () => {
  const notes = staffNotes(house([
    { title: "وفّر ٥٠٠ في الشهر", target_value: 500, current_value: 100, deadline_date: "2026-10-31", created_at: "2026-09-01T00:00:00Z" },
    { title: "أسدد ديوني", target_value: 12, current_value: 2, deadline_date: "2026-12-13", created_at: "2026-09-14T18:31:09Z" },
  ]), NOW);
  const goalNotes = notes.filter((n) => n.subject.startsWith("هدف متأخر"));
  assertEquals(goalNotes.map((n) => n.subject), ["هدف متأخر: «وفّر ٥٠٠ في الشهر»"]);
  assertEquals(goalNotes[0].sender, "brain");
  assert(goalNotes[0].detail.includes("خطوة واحدة صغيرة لبكرة"));
  assert(goalNotes[0].detail.includes("وصل 100 من 500"));
  assert(goalNotes[0].detail.length <= 500);
});

Deno.test("staff: no goals, or none with a schedule, says nothing about goals", () => {
  for (const goals of [undefined, [], [{ title: "أقرا أكتر", target_value: null, current_value: 0, deadline_date: null, created_at: "2026-09-01" }]]) {
    assertEquals(staffNotes(house(goals), NOW).filter((n) => n.subject.startsWith("هدف")).length, 0);
  }
});
