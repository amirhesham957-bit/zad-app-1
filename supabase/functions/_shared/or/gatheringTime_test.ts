import { assert, assertEquals, assertThrows } from "jsr:@std/assert@1";
import { type Busy, bestGatherings, type GatheringRules } from "./gatheringTime.ts";

const DAY = 1440;
const at = (day: number, hour: number): number => day * DAY + hour * 60;

Deno.test("everyone free Friday evening beats evenings when someone is busy", () => {
  const busy: Busy[] = [];
  for (let day = 0; day < 7; day++) {
    if (day !== 5) busy.push({ member: "a", start: at(day, 18), end: at(day, 22) });
  }
  const slots = bestGatherings(busy, {
    members: ["a", "b"],
    minutes: 60,
    earliest: 18 * 60,
    latest: 22 * 60,
    step: 60,
  }, 1);

  assertEquals(slots[0], {
    start: at(5, 18),
    end: at(5, 19),
    present: ["a", "b"],
    missing: [],
    score: 200,
  });
});

Deno.test("best partial gathering has the most present and lists the missing", () => {
  const busy: Busy[] = [{ member: "a", start: at(0, 18), end: at(0, 19) }];
  for (let day = 1; day < 7; day++) busy.push({ member: "b", start: at(day, 18), end: at(day, 19) });
  const slots = bestGatherings(busy, {
    members: ["a", "b"],
    minutes: 60,
    earliest: 18 * 60,
    latest: 19 * 60,
    step: 60,
  }, 1);

  assertEquals(slots[0].score, 100);
  assertEquals(slots[0].present, ["b"]);
  assertEquals(slots[0].missing, ["a"]);
});

Deno.test("preferred window bonus breaks an all-present tie", () => {
  const slots = bestGatherings([], {
    members: ["a", "b"],
    minutes: 60,
    earliest: 18 * 60,
    latest: 20 * 60,
    step: 60,
    preferred: [{ start: at(0, 19), end: at(0, 20), bonus: 40 }],
  }, 2);

  assertEquals(slots.map((slot) => slot.start), [at(0, 19), at(0, 18)]);
  assertEquals(slots.map((slot) => slot.score), [240, 200]);
});

Deno.test("returned slots do not overlap or cross latest or midnight", () => {
  const latest = 24 * 60;
  const slots = bestGatherings([], {
    members: ["a"],
    minutes: 120,
    earliest: 20 * 60,
    latest,
    step: 30,
  }, 20);

  assertEquals(slots.length, 14);
  for (let i = 0; i < slots.length; i++) {
    const slot = slots[i];
    const dayStart = Math.floor(slot.start / DAY) * DAY;
    assert(slot.start >= dayStart);
    assert(slot.end - dayStart <= latest);
    assert(slot.end - dayStart <= DAY);
    if (i > 0) assert(slots[i - 1].end <= slot.start);
  }
});

Deno.test("busy intervals belonging to non-members are ignored", () => {
  const slots = bestGatherings([{ member: "outsider", start: at(0, 17), end: at(0, 19) }], {
    members: ["a"],
    minutes: 60,
    earliest: 18 * 60,
    latest: 19 * 60,
    step: 60,
  }, 1);

  assertEquals(slots[0].start, at(0, 18));
  assertEquals(slots[0].present, ["a"]);
  assertEquals(slots[0].score, 100);
});

Deno.test("a busy interval ending exactly at slot start does not block it", () => {
  const slots = bestGatherings([{ member: "a", start: at(0, 17), end: at(0, 18) }], {
    members: ["a"],
    minutes: 60,
    earliest: 18 * 60,
    latest: 19 * 60,
    step: 60,
  }, 1);

  assertEquals(slots[0].start, at(0, 18));
  assertEquals(slots[0].present, ["a"]);
  assertEquals(slots[0].missing, []);
});

Deno.test("invalid gathering inputs throw RangeError", () => {
  const rules: GatheringRules = { members: ["a"], minutes: 60 };
  assertThrows(() => bestGatherings([], { ...rules, minutes: 14 }), RangeError);
  assertThrows(() => bestGatherings([], { ...rules, minutes: 361 }), RangeError);
  assertThrows(() => bestGatherings([], { ...rules, step: 4 }), RangeError);
  assertThrows(() => bestGatherings([], { ...rules, step: 121 }), RangeError);
  assertThrows(
    () => bestGatherings([], { ...rules, earliest: 20 * 60, latest: 20 * 60 }),
    RangeError,
  );
  assertThrows(() => bestGatherings([{ member: "a", start: 60, end: 60 }], rules), RangeError);
});
