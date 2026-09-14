// تذكيرات المكان (20260914007000): «فكّريني لما أروح الصيدلية أجيب بنادول».
import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { placeReminderDedupeKey, placesMatchingArrival } from "./shared.ts";
import { freshContext, validateAddPlaceReminder, validateCancelPlaceReminder } from "./validators.ts";
import { momentFallback } from "./voiceMoments.ts";
import { emotionForMoment } from "../_shared/zadVoice.ts";

Deno.test("a pharmacy arrival fires pharmacy and any-place reminders, never supermarket ones", () => {
  assertEquals(placesMatchingArrival("pharmacy").sort(), ["any", "pharmacy"]);
  assert(!placesMatchingArrival("pharmacy").includes("supermarket" as never));
});

Deno.test("the same reminders give the same dedupe key whatever order the rows came back in", () => {
  assertEquals(placeReminderDedupeKey(["b", "a"]), placeReminderDedupeKey(["a", "b"]));
  assert(placeReminderDedupeKey(["a"]) !== placeReminderDedupeKey(["a", "b"]));
});

Deno.test("add_place_reminder needs a real note and a known place", async () => {
  const snap = {};
  assert((await validateAddPlaceReminder({ note: "أجيب بنادول", place: "pharmacy" }, snap, freshContext("u1"))).ok);
  assert(!(await validateAddPlaceReminder({ note: "ا", place: "pharmacy" }, snap, freshContext("u1"))).ok);
  assert(!(await validateAddPlaceReminder({ note: "أجيب بنادول", place: "gym" }, snap, freshContext("u1"))).ok);
  const ctx = freshContext("u1");
  ctx.counts["add_place_reminder"] = 5;
  assert(!(await validateAddPlaceReminder({ note: "أجيب بنادول", place: "any" }, snap, ctx)).ok);
});

Deno.test("cancel_place_reminder needs an id from the snapshot", async () => {
  assert(!(await validateCancelPlaceReminder({}, {}, freshContext("u1"))).ok);
  assert((await validateCancelPlaceReminder({ reminder_id: "3f1c2a9e-0000-4000-8000-000000000000" }, {}, freshContext("u1"))).ok);
});

Deno.test("with the model down, the reminder is still said out loud with the note and the store", () => {
  const m = momentFallback("place_reminder", { store_name: "صيدلية العزبي", notes: ["أجيب بنادول"] });
  assertStringIncludes(m.text, "أجيب بنادول");
  assertStringIncludes(m.speech, "صيدلية العزبي");
  assert(m.speech.length > 0, "place reminders are voice moments");
  assertEquals(emotionForMoment("place_reminder"), "playful");
});
