// م٥.١: ميزانية الانتباه اليومية — الأعلى قيمة ياخد الخانتين، مش أول اتنين مستحقين.
import { assertEquals } from "jsr:@std/assert@1";
import { attentionDecisions } from "./shared.ts";
import type { Stance } from "./outcomeLearning.ts";

const TZ = "Africa/Cairo"; // +03:00 في أكتوبر ٢٠٢٦
const NOW = Date.parse("2026-10-18T15:00:00Z");
const t = (id: string, kind: string, stance: Stance = "normal") => ({ id, kind, stance });

Deno.test("two slots, three proactive: the two most valuable send, whatever the input order", () => {
  const due = [t("pet", "pet_call"), t("bill", "bill_reminder"), t("short", "predicted_shortage")];
  const d = attentionDecisions(due, [], TZ, NOW);
  assertEquals(d.get("bill"), "send");
  assertEquals(d.get("short"), "send");
  assertEquals(d.get("pet"), "defer");
  const rev = attentionDecisions([...due].reverse(), [], TZ, NOW);
  assertEquals(rev.get("pet"), "defer");
  assertEquals(rev.get("bill"), "send");
});

Deno.test("a welcomed stance beats a quiet one at equal base priority", () => {
  const d = attentionDecisions(
    [t("a", "predicted_shortage", "quiet"), t("b", "restock_link", "quiet"), t("c", "habit_budget", "welcomed")],
    [], TZ, NOW,
  );
  assertEquals(d.get("c"), "send");
  assertEquals(d.get("a"), "send"); // التعادل: الأقدم
  assertEquals(d.get("b"), "defer");
});

Deno.test("one already delivered today leaves one slot", () => {
  const sent = [{ kind: "spending_ahead", at: "2026-10-18T06:00:00Z" }];
  const d = attentionDecisions([t("a", "bill_reminder"), t("b", "predicted_shortage")], sent, TZ, NOW);
  assertEquals(d.get("a"), "send");
  assertEquals(d.get("b"), "defer");
});

Deno.test("critical kinds always send and take no slot", () => {
  const due = [
    t("l", "listener_gap_alert"), t("m", "med_followup"), t("s", "store_arrival"), t("r", "reminder"),
    t("a", "bill_reminder"), t("b", "predicted_shortage"), t("c", "pet_call"),
  ];
  const d = attentionDecisions(due, [], TZ, NOW);
  for (const id of ["l", "m", "s", "r"]) assertEquals(d.get(id), "send", id);
  assertEquals(d.get("a"), "send");
  assertEquals(d.get("b"), "send");
  assertEquals(d.get("c"), "defer");
});

Deno.test("yesterday's deliveries (by the account's clock) don't count", () => {
  // ١١:٣٠ بالليل القاهرة يوم ١٧ = ٢٠:٣٠ UTC
  const sent = [
    { kind: "spending_ahead", at: "2026-10-17T20:30:00Z" },
    { kind: "bill_reminder", at: "2026-10-17T18:00:00Z" },
  ];
  const d = attentionDecisions([t("a", "bill_reminder"), t("b", "predicted_shortage"), t("c", "pet_call")], sent, TZ, NOW);
  assertEquals(d.get("a"), "send");
  assertEquals(d.get("b"), "send");
  assertEquals(d.get("c"), "defer");
});
