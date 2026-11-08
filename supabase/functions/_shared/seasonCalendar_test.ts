import { assert, assertEquals } from "jsr:@std/assert@1";
import { seasonDueToday, seasonPlanInstruction, seasonsOfYear, shamNessim, upcomingCalendarSeasons, whiteFriday } from "./seasonCalendar.ts";

Deno.test("computed dates match the published ones", () => {
  assertEquals(whiteFriday(2026), "2026-11-27");
  assertEquals(whiteFriday(2027), "2027-11-26");
  assertEquals(shamNessim(2026), "2026-04-13");
  assertEquals(shamNessim(2027), "2027-05-03");
  const on = (key: string) => seasonsOfYear("SA", 2027).find((s) => s.key === key)?.on;
  assertEquals(on("eid_fitr"), "2027-03-09");
  assertEquals(on("eid_adha"), "2027-05-16");
  assertEquals(on("ahlan_ramadan"), "2027-01-18");
  assertEquals(on("founding_day"), "2027-02-22");
});

Deno.test("each country gets its own days", () => {
  const keys = (c: string) => seasonsOfYear(c, 2027).map((s) => s.key);
  assert(keys("SA").includes("founding_day"));
  assert(keys("SA").includes("national_day"));
  assert(!keys("EG").includes("national_day"));
  assert(keys("EG").includes("sham_nessim"));
  assert(!keys("SA").includes("sham_nessim"));
  assert(!keys("AE").includes("founding_day"));
  assertEquals(seasonsOfYear("AE", 2027).find((s) => s.key === "national_day")?.name, "عيد الاتحاد");
});

Deno.test("upcoming crosses the year and is nearest first", () => {
  const u = upcomingCalendarSeasons("AE", "2026-11-20", 14);
  assertEquals(u.map((s) => [s.key, s.in_days]), [["white_friday", 7], ["national_day", 12]]);
  assertEquals(upcomingCalendarSeasons("SA", "2026-12-28", 20).map((s) => s.key), []);
  assertEquals(upcomingCalendarSeasons("SA", "2026-12-28", 21).map((s) => s.key), ["ahlan_ramadan"]);
});

Deno.test("school in Egypt is for homes with children, and says approximately", () => {
  assertEquals(upcomingCalendarSeasons("EG", "2027-09-10", 14, 0).map((s) => s.key), []);
  const [s] = upcomingCalendarSeasons("EG", "2027-09-10", 14, 2);
  assertEquals(s.key, "back_to_school_eg");
  assert(seasonPlanInstruction([s]).includes("حوالي"));
});

Deno.test("the morning asks exactly 14 days before, once, and leaves Ramadan to its own question", () => {
  assertEquals(seasonDueToday("SA", "2027-02-08")?.key, "founding_day");
  assertEquals(seasonDueToday("SA", "2027-02-07"), null);
  assertEquals(seasonDueToday("SA", "2027-02-09"), null);
  assertEquals(seasonDueToday("SA", "2027-01-04"), null); // أهلاً رمضان بعد ١٤ يوم
});

Deno.test("bad input is no season", () => {
  assertEquals(upcomingCalendarSeasons(null, "2027-02-08"), []);
  assertEquals(upcomingCalendarSeasons("SA", "garbage"), []);
  assertEquals(seasonPlanInstruction([]), "");
});
