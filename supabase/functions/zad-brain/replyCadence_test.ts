import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { replyCadence, replyCadenceMomentLine, replyCadenceRule } from "./replyCadence.ts";

const TZ = "Asia/Riyadh"; // +03:00 all year
const at = (local: string) => Date.parse(`${local}+03:00`);
const iso = (local: string) => new Date(at(local)).toISOString();

Deno.test("an appointment now or within the next hour and a half makes replies brief", () => {
  const appts = [{ title: "دكتور الأسنان", starts_at: iso("2026-10-06T17:00:00") }];
  assertEquals(replyCadence({ appointments: appts, nowMs: at("2026-10-06T16:00:00"), timeZone: TZ }).mode, "brief");
  assertEquals(replyCadence({ appointments: appts, nowMs: at("2026-10-06T17:40:00"), timeZone: TZ }).mode, "brief", "in it");
  assertEquals(replyCadence({ appointments: appts, nowMs: at("2026-10-06T14:00:00"), timeZone: TZ }).mode, "normal", "three hours out");
  const r = replyCadence({ appointments: appts, nowMs: at("2026-10-06T16:00:00"), timeZone: TZ });
  assertStringIncludes(r.reason, "«دكتور الأسنان»");
});

Deno.test("a busy day or a high household load is brief all day", () => {
  assertEquals(replyCadence({ appointments: [], appointmentsToday: 3, nowMs: at("2026-10-06T20:00:00"), timeZone: TZ }).mode, "brief");
  assertEquals(replyCadence({ appointments: [], householdLevel: "high", nowMs: at("2026-10-06T20:00:00"), timeZone: TZ }).mode, "brief");
});

Deno.test("an evening with nothing in the next three hours is roomy; morning is normal", () => {
  assertEquals(replyCadence({ appointments: [], nowMs: at("2026-10-06T20:00:00"), timeZone: TZ }).mode, "roomy");
  assertEquals(replyCadence({ appointments: [], nowMs: at("2026-10-06T10:00:00"), timeZone: TZ }).mode, "normal");
  assertEquals(replyCadence({ appointments: [], nowMs: at("2026-10-06T23:30:00"), timeZone: TZ }).mode, "normal", "late is not roomy");
  const later = [{ title: "مكالمة", starts_at: iso("2026-10-06T22:30:00") }];
  assertEquals(replyCadence({ appointments: later, nowMs: at("2026-10-06T20:00:00"), timeZone: TZ }).mode, "normal", "something at 22:30");
});

Deno.test("cancelled appointments and hourly reminders do not make anyone busy", () => {
  const appts = [
    { title: "النادي", starts_at: iso("2026-10-06T20:30:00"), status: "cancelled" },
    { title: "اشرب مية", starts_at: iso("2026-10-06T20:00:00"), recurrence: "hourly" },
  ];
  assertEquals(replyCadence({ appointments: appts, nowMs: at("2026-10-06T20:00:00"), timeZone: TZ }).mode, "roomy");
});

Deno.test("the rules: brief caps at two sentences and never says «busy»; roomy allows one extra idea; normal says nothing", () => {
  const brief = replyCadenceRule({ reply_cadence: { mode: "brief", reason: "x" } });
  assertStringIncludes(brief, "جملتين بالكتير");
  assertStringIncludes(brief, "ماتقولش له إنه مشغول");
  assertStringIncludes(replyCadenceRule({ reply_cadence: { mode: "roomy", reason: "x" } }), "فكرة زيادة واحدة");
  assertEquals(replyCadenceRule({ reply_cadence: { mode: "normal", reason: "" } }), "");
  assertStringIncludes(replyCadenceMomentLine("brief"), "جملة واحدة");
  assertEquals(replyCadenceMomentLine("normal"), "");
});

Deno.test("the moment prompt carries the cadence line, and nothing when normal", async () => {
  const { buildMomentPrompt } = await import("./voiceMoments.ts");
  const brief = buildMomentPrompt({ moment: "morning_greeting", facts: {} }, "EG", null, { cadence: "brief" }).system;
  assertStringIncludes(brief, replyCadenceMomentLine("brief"));
  const normal = buildMomentPrompt({ moment: "morning_greeting", facts: {} }, "EG", null, {}).system;
  assertEquals(normal.includes(replyCadenceMomentLine("roomy")), false);
  assertEquals(normal.includes(replyCadenceMomentLine("brief")), false);
});
