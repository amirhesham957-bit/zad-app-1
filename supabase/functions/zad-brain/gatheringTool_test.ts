import { assert, assertEquals } from "jsr:@std/assert@1";
import { dayLabel, describeGatherings, findGatherings, parseClock, parseGatheringInput } from "./gatheringTool.ts";
import { guardEngineReply } from "./engineGuard.ts";
import { intentToolHints, scopeToolsForSpecialist } from "./specialists.ts";

const base = { members: ["أنا", "ماما", "أحمد"], minutes: 120 };

Deno.test("parseClock: Western and Arabic-Indic digits, bounds", () => {
  assertEquals(parseClock("19:30"), 1170);
  assertEquals(parseClock("٧:٣٠"), 450);
  assertEquals(parseClock("24:00"), 1440);
  for (const bad of ["25:00", "7", "12:60", "", null, "ab:cd"]) assertEquals(parseClock(bad), null);
});

Deno.test("parse: a good request", () => {
  const p = parseGatheringInput({ ...base, earliest: "10:00", latest: "22:00", busy: [{ member: "ماما", day: 0, from: "10:00", to: "20:00" }] });
  assert("value" in p);
  assertEquals(p.value.busy, [{ member: "ماما", start: 600, end: 1200 }]);
  assertEquals(p.value.earliest, 600);
});

Deno.test("parse: refusals are Arabic and specific", () => {
  const cases: Array<Record<string, unknown> | undefined> = [
    undefined, { ...base, members: ["أنا"] }, { ...base, minutes: 10 }, { ...base, minutes: 90.5 },
    { ...base, earliest: "xx" }, { ...base, earliest: "22:00", latest: "10:00" },
    { ...base, busy: "x" }, { ...base, busy: [{ member: "غريب", day: 0, from: "10:00", to: "11:00" }] },
    { ...base, busy: [{ member: "ماما", day: 7, from: "10:00", to: "11:00" }] },
    { ...base, busy: [{ member: "ماما", day: 0, from: "11:00", to: "10:00" }] },
  ];
  for (const c of cases) {
    const p = parseGatheringInput(c);
    assert("error" in p, JSON.stringify(c));
    assert(p.error.startsWith("مرفوض"));
  }
});

Deno.test("everyone free: the first slot has all present", () => {
  const p = parseGatheringInput(base);
  assert("value" in p);
  const slots = findGatherings(p.value);
  assertEquals(slots[0].missing, []);
  assertEquals(slots.length, 3);
});

Deno.test("a busy member is missing from the slot that overlaps, present elsewhere", () => {
  const p = parseGatheringInput({
    ...base, earliest: "10:00", latest: "14:00",
    busy: Array.from({ length: 7 }, (_, d) => ({ member: "ماما", day: d, from: "10:00", to: "12:00" })),
  });
  assert("value" in p);
  const best = findGatherings(p.value)[0];
  assertEquals(best.missing, []);
  assertEquals(best.start % 1440, 12 * 60);
});

Deno.test("no time fits: honest message", () => {
  const p = parseGatheringInput({ ...base, earliest: "10:00", latest: "11:00" });
  assert("value" in p);
  assertEquals(describeGatherings(findGatherings(p.value), p.value, "2026-11-22").startsWith("مفيش وقت"), true);
});

Deno.test("dayLabel: 2026-11-22 is a Sunday", () => {
  assertEquals(dayLabel("2026-11-22", 0), "الأحد 22/11");
  assertEquals(dayLabel("2026-11-22", 3), "الأربع 25/11");
  assertEquals(dayLabel("2026-12-30", 3), "السبت 2/1");
});

Deno.test("describe: weekday, window, who is missing", () => {
  const p = parseGatheringInput({ ...base, earliest: "19:00", latest: "21:00", busy: [{ member: "أحمد", day: 0, from: "19:00", to: "21:00" }] });
  assert("value" in p);
  const text = describeGatherings(findGatherings(p.value), p.value, "2026-11-22");
  assert(text.includes("الأحد 22/11") === false || text.includes("ناقص: أحمد"));
  assert(text.includes("الاتنين 23/11 من 19:00 لـ21:00 — الكل موجود"));
});

Deno.test("an invented time in the model's reply is caught by the guard only for engine tools it is registered on", () => {
  const out = [{ tool: "plan_gathering_time", content: "1. الاتنين 23/11 من 19:00 لـ21:00 — الكل موجود" }];
  assertEquals(guardEngineReply("الاتنين 23/11 من 19:00 لـ21:00", "؟", out).replaced, false);
  assertEquals(guardEngineReply("الاتنين 23/11 من 18:00 لـ20:00", "؟", out).replaced, true);
});

Deno.test("«امتى نتجمع» reaches plan_gathering_time; the pantry/family scope carries it", () => {
  assertEquals(intentToolHints("امتى نتجمع كلنا الاسبوع ده").includes("plan_gathering_time"), true);
  assertEquals(intentToolHints("وقت اللمه المناسب").includes("plan_gathering_time"), true);
  assertEquals(intentToolHints("صباح الخير").includes("plan_gathering_time"), false);
  const tools = scopeToolsForSpecialist([{ name: "plan_gathering_time" } as never, { name: "log_transaction" } as never], "pantry", null, []);
  assertEquals(tools.some((t: { name: string }) => t.name === "plan_gathering_time"), true);
});
