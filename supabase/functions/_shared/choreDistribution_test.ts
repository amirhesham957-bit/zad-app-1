import { assertEquals } from "jsr:@std/assert@1";
import { choreKey, DEFAULT_CHORE_MINUTES, distributeChores, type MemberRow } from "./choreDistribution.ts";

const m = (id: string, minutesPerWeek: number | null, dislikes: string[] = [], likes: string[] = []): MemberRow =>
  ({ id, name: id, minutesPerWeek, dislikes, likes });

Deno.test("every chore lands on someone when there's time, and the load spreads instead of piling up", () => {
  const chores = [
    { id: "dishes", title: "غسيل المواعين", minutes: 30 },
    { id: "sweep", title: "كنس الصالة", minutes: 20 },
    { id: "trash", title: "رمي الزبالة", minutes: 5 },
    { id: "laundry", title: "نشر الغسيل", minutes: 25 },
  ];
  const r = distributeChores(chores, [m("dad", 120), m("sara", 120)]);
  assertEquals(r.unassigned, []);
  assertEquals(r.assignments.length, 4);
  // ٨٠ دقيقة على اتنين: محدش بياخد أكتر من ٥٥.
  assertEquals(Math.max(r.load.dad, r.load.sara) <= 55, true, JSON.stringify(r.load));
});

Deno.test("a disliked chore goes to someone else; a liked one comes to you", () => {
  const chores = [{ id: "dishes", title: "غسيل المواعين", minutes: 30 }, { id: "sweep", title: "كنس الصالة", minutes: 30 }];
  const r = distributeChores(chores, [m("dad", 120, ["غسيل المواعين"]), m("sara", 120, [], ["غسيل  المواعين"])]);
  const who = Object.fromEntries(r.assignments.map((a) => [a.choreId, a.memberId]));
  assertEquals(who.dishes, "sara");
  assertEquals(who.sweep, "dad");
});

Deno.test("nobody is given more than their week; what doesn't fit is left unassigned, not forced", () => {
  const chores = [{ id: "big", title: "تنضيف المطبخ", minutes: 90 }, { id: "small", title: "رمي الزبالة", minutes: 5 }];
  const r = distributeChores(chores, [m("sara", 60)]);
  assertEquals(r.assignments.map((a) => a.choreId), ["small"]);
  assertEquals(r.unassigned, ["big"]);
  assertEquals(r.load.sara, 5);
});

Deno.test("unknown duration counts as the default; nobody in the family = nothing assigned", () => {
  const r = distributeChores([{ id: "x", title: "حاجة", minutes: null }], [m("dad", null)]);
  assertEquals(r.assignments, [{ choreId: "x", memberId: "dad", minutes: DEFAULT_CHORE_MINUTES }]);
  assertEquals(distributeChores([{ id: "x", title: "حاجة", minutes: 10 }], []).unassigned, ["x"]);
});

Deno.test("choreKey ignores spacing, diacritics and hamza", () => {
  assertEquals(choreKey(" غسيل   المواعين "), choreKey("غسيل المواعين"));
  assertEquals(choreKey("ترتيب الأوضة"), choreKey("ترتيب الاوضه"));
});
