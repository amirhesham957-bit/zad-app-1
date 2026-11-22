import { assertEquals } from "jsr:@std/assert@1";
import { conflictAction, memberIdFor, memoryTimeRefusal, temporalFields } from "./memoryTime.ts";
import { memoryForSnapshot } from "./index.ts";
import { validateRemember } from "./validators.ts";

const members = [
  { id: "self-1", display_name: "أنا", kind: "self" },
  { id: "m-ahmed", display_name: "أحمد", kind: "adult" },
  { id: "m-mama", display_name: "ماما", kind: "elder" },
];

Deno.test("memberIdFor matches the household name loosely, and «أنا» is the self row", () => {
  assertEquals(memberIdFor("احمد", members), "m-ahmed");
  assertEquals(memberIdFor(" أحمد ", members), "m-ahmed");
  assertEquals(memberIdFor("ماما", members), "m-mama");
  assertEquals(memberIdFor("انا", members), "self-1");
  assertEquals(memberIdFor("نفسي", members), "self-1");
  assertEquals(memberIdFor("يوسف", members), null);
  assertEquals(memberIdFor("", members), null);
  assertEquals(memberIdFor(undefined, members), null);
});

Deno.test("م٩.١: the customer's own words close the old fact; without them we ask", () => {
  assertEquals(conflictAction("بطلت القهوة خلاص"), "supersede");
  assertEquals(conflictAction(""), "ask");
  assertEquals(conflictAction(undefined), "ask");
  assertEquals(conflictAction("   "), "ask");
});

Deno.test("the snapshot shows a pause and the member only when they exist", () => {
  const base = { id: "n1", scope: "general", note: "أحمد بيروح الجيم", confidence: 0.8, evidence_count: 1, last_seen: null };
  assertEquals("paused_until" in memoryForSnapshot(base), false);
  assertEquals("member" in memoryForSnapshot(base), false);
  const paused = memoryForSnapshot({ ...base, paused_until: "2026-11-29T21:59:59+00:00", member: "أحمد" });
  assertEquals((paused as Record<string, unknown>).paused_until, "2026-11-29");
  assertEquals((paused as Record<string, unknown>).member, "أحمد");
  assertEquals(temporalFields({ paused_until: null, member: null }), {});
});

Deno.test("every refusal code from the SQL functions reads as Arabic", () => {
  for (const code of ["unknown_note", "note_not_live", "pause_end_passed", "pause_too_long", "pause_reason_length", "not_paused", "member_not_in_household"]) {
    const text = memoryTimeRefusal(code);
    assertEquals(text.includes(code), false, code);
  }
});

Deno.test("remember: a resume (pause_note_id without an end day) needs only the id; a pause still needs its reason", async () => {
  const snap = { now_local: { time_zone: "Africa/Cairo", date: "2026-11-22" } };
  const ctx = { counts: {} } as never;
  assertEquals((await validateRemember({ pause_note_id: "n1" }, snap, ctx)).ok, true);
  assertEquals((await validateRemember({ pause_note_id: "n1", valid_until: "2026-11-29", note: "قصير" }, snap, ctx)).ok, false);
  assertEquals((await validateRemember({ pause_note_id: "n1", valid_until: "2026-11-29", note: "أحمد وقف الجيم أسبوع عشان السفر" }, snap, ctx)).ok, true);
  assertEquals((await validateRemember({ pause_note_id: "n1", valid_until: "امبارح", note: "أحمد وقف الجيم أسبوع عشان السفر" }, snap, ctx)).ok, false);
});
