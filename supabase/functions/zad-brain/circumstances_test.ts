// حالة البيت (docs/agent/ZAD_LIVING_BRAIN.md الشريحة ٢٩): الظرف الطارئ، والتعافي بعده، وإزاي كل قناة بتسمعهم.
import { assert, assertEquals } from "jsr:@std/assert@1";
import { attentionBudget, circumstanceFrom, type CircumstanceRow, NORMAL } from "./circumstances.ts";
import { cardBudgetRejection, CHAT_NOTES_PER_TURN, chooseNotes, DAILY_NOTES_MAX, OPEN_CARDS_MAX } from "./attention.ts";
import { DAILY_VOICE_ALERT_CAP, momentGate } from "./voiceMoments.ts";

const HOUR = 3_600_000;
const NOW = Date.parse("2026-10-05T10:00:00Z");
const at = (hours: number) => new Date(NOW + hours * HOUR).toISOString();
const row = (kind: string, from: number, to: number, extra: Partial<CircumstanceRow> = {}): CircumstanceRow => ({
  id: `${kind}-${from}`, kind, started_at: at(from), ends_at: at(to), ...extra,
});

Deno.test("circumstance: what the customer declared quiets Zad, and it can be ended", () => {
  const c = circumstanceFrom([row("exceptional", -5, 60)], null, NOW);
  assertEquals(c, { mode: "exceptional", reason: "exceptional", until: at(60), id: "exceptional--5" });
  // طارئ قبل الامتحانات لو الاتنين شغالين.
  assertEquals(circumstanceFrom([row("exams", -5, 100), row("exceptional", -1, 20)], null, NOW).reason, "exceptional");
  // لسه مابدأش.
  assertEquals(circumstanceFrom([row("exams", 2, 100)], null, NOW), NORMAL);
});

Deno.test("circumstance: 48 hours of recovery after it ends — unless the customer ended it", () => {
  assertEquals(circumstanceFrom([row("exams", -200, -10)], null, NOW),
    { mode: "recovery", reason: "after_exams", until: at(38), id: null });
  assertEquals(circumstanceFrom([row("exams", -200, -50)], null, NOW), NORMAL);
  const ended = row("exceptional", -20, -2, { ended_at: at(-2), detail: { ended_by_customer: true } });
  assertEquals(circumstanceFrom([ended], null, NOW), NORMAL, "he asked for the alerts back");
});

Deno.test("circumstance: a trip home, and a family SOS, are objective — no inference", () => {
  assertEquals(circumstanceFrom([row("travel", -120, -10, { ended_at: at(-10) })], null, NOW).reason, "after_travel");
  assertEquals(circumstanceFrom([], at(-3), NOW), { mode: "exceptional", reason: "family_sos", until: at(21), id: null });
  assertEquals(circumstanceFrom([], at(-30), NOW).reason, "after_family_sos");
  assertEquals(circumstanceFrom([], at(-80), NOW), NORMAL);
  // تحول في نمط المعيشة (الشريحة ٣٠) مش ظرف هادي ولا بيجيب تعافي.
  assertEquals(circumstanceFrom([row("shift_spending", -100, 500)], null, NOW), NORMAL);
});

Deno.test("budget: normal is exactly today's caps; a circumstance is less", () => {
  const normal = attentionBudget("normal");
  assertEquals([normal.chatNotes, normal.dailyNotes, normal.openCards, normal.voiceCap],
    [CHAT_NOTES_PER_TURN, DAILY_NOTES_MAX, OPEN_CARDS_MAX, DAILY_VOICE_ALERT_CAP]);
  assertEquals(normal.senders, null);
  const quiet = attentionBudget("exceptional");
  assertEquals([...quiet.senders!].sort(), ["family", "pharmacy"]);
  assertEquals(quiet.curiosity, false);
  const recovery = attentionBudget("recovery");
  assert(recovery.chatNotes < normal.chatNotes && recovery.voiceCap < normal.voiceCap);
  assertEquals(recovery.senders!.has("research") || recovery.senders!.has("brain"), false);
});

Deno.test("budget: a note from a quiet sender waits in the mailbox — not said, not thrown away", () => {
  const notes = [
    { id: "f", sender: "finance", subject: "مفيش سقف للشهر ده", detail: null, created_at: at(-1) },
    { id: "p", sender: "pharmacy", subject: "الأنسولين هيخلص بعد يومين", detail: null, created_at: at(-1) },
  ];
  const b = attentionBudget("exceptional");
  // مكان لاتنين — المحاسب بيستنى عشان الظرف، مش عشان السقف.
  const { deliver, drop } = chooseNotes(notes, { now: NOW, budget: 5, senders: b.senders });
  assertEquals(deliver.map((n) => n.id), ["p"]);
  assertEquals(drop, []);
});

Deno.test("budget: one open card is enough during a circumstance; critical still passes", () => {
  const attention = { open_cards: 1, max_open_cards: attentionBudget("exceptional").openCards };
  assert(cardBudgetRejection({ priority: "normal" }, attention) !== null);
  assertEquals(cardBudgetRejection({ priority: "critical" }, attention), null);
  assertEquals(cardBudgetRejection({ priority: "normal" }, { open_cards: 1 }), null, "normal day: 3");
});

Deno.test("voice: optional moments wait, health and safety do not, and the day's cap shrinks", () => {
  assertEquals(momentGate("weekly_money_story", 12, 0, 0, "exceptional"), "circumstance");
  assertEquals(momentGate("challenge_milestone", 12, 0, 0, "recovery"), "circumstance");
  assertEquals(momentGate("dose_due", 12, 99, 0, "exceptional"), null);
  assertEquals(momentGate("family_zone_exit", 12, 99, 0, "exceptional"), null);
  assertEquals(momentGate("morning_greeting", 9, 1, 0, "exceptional"), null);
  assertEquals(momentGate("morning_greeting", 9, 2, 0, "exceptional"), "daily_cap");
  assertEquals(momentGate("weekly_money_story", 12, 0, 0, "normal"), null);
});
