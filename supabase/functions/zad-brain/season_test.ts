// المواسم (رمضان/العيدين) بتقويم أم القرى + تذكير الفطار.
import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { seasonFor, seasonInstruction } from "../_shared/season.ts";
import { emotionForMoment } from "../_shared/zadVoice.ts";
import { momentFallback } from "./voiceMoments.ts";

Deno.test("Umm al-Qura: 8 Feb 2027 is 1 Ramadan, 9 Mar 2027 is Eid al-Fitr, 27 May 2026 is Eid al-Adha", () => {
  assertEquals(seasonFor(new Date("2027-02-08T12:00:00Z"), "Africa/Cairo")?.kind, "ramadan");
  assertEquals(seasonFor(new Date("2027-02-08T12:00:00Z"), "Africa/Cairo")?.hijri_day, 1);
  assertEquals(seasonFor(new Date("2027-03-09T12:00:00Z"), "Asia/Riyadh")?.kind, "eid_fitr");
  assertEquals(seasonFor(new Date("2026-05-27T12:00:00Z"), "Asia/Riyadh")?.kind, "eid_adha");
  assertEquals(seasonFor(new Date("2026-09-14T12:00:00Z"), "Africa/Cairo")?.kind, null);
});

Deno.test("the local date decides: just after midnight in Riyadh is already the next Hijri day", () => {
  // 21:30Z يوم ٧ فبراير = ٠٠:٣٠ الرياض يوم ٨ = ١ رمضان
  assertEquals(seasonFor(new Date("2027-02-07T21:30:00Z"), "Asia/Riyadh")?.kind, "ramadan");
  assertEquals(seasonFor(new Date("2027-02-07T21:30:00Z"), "America/New_York")?.kind, null);
});

Deno.test("Ramadan instruction forbids daytime meals and mentions Eid near the end", () => {
  const early = seasonInstruction(seasonFor(new Date("2027-02-10T12:00:00Z"), "Africa/Cairo"));
  assertStringIncludes(early, "سحور");
  assert(!early.includes("العيدية"));
  assertStringIncludes(seasonInstruction(seasonFor(new Date("2027-03-01T12:00:00Z"), "Africa/Cairo")), "العيدية");
  assertEquals(seasonInstruction(null), "");
});

Deno.test("iftar reminder is warm, names the minutes and what's missing for iftar", () => {
  assertEquals(emotionForMoment("iftar_soon"), "warm");
  const m = momentFallback("iftar_soon", { minutes_to_iftar: 15, shopping_preview: ["تمر", "لبن"] });
  assertStringIncludes(m.title, "15");
  assertStringIncludes(m.text, "تمر");
  assertStringIncludes(m.speech, "المغرب");
});
