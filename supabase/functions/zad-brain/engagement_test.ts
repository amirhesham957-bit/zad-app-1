// زاد بيتعلم من التجاهل الصامت: ٣ مرات ورا بعض في نفس الموضوع ⇒ يسكت فيه إلا الحرج.
import { assert, assertEquals } from "jsr:@std/assert@1";
import { engagementFrom, insightTopic, quietTopicRejection } from "./engagement.ts";
import { validateAskUser, validateEmitInsight } from "./validators.ts";
import { freshContext } from "./validators.ts";

const NOW = Date.parse("2026-10-04T12:00:00Z");
const at = (iso: string) => new Date(iso).toISOString();

Deno.test("topic: the model's daily keys for one subject collapse to one topic", () => {
  // Keys on the live project, 2026-10-04.
  for (const k of ["betaderm_low_2026_09_29", "betaderm_low_stock_2026_09_30", "betaderm_low_stock_20261001", "betaderm_low_20261003"]) {
    assertEquals(insightTopic(k), "betaderm_low", k);
  }
  assertEquals(insightTopic("cash_reconciliation_2026_w40"), "cash_reconciliation");
  assertEquals(insightTopic("netflix_renewal_oct3"), "netflix_renewal");
  assertEquals(insightTopic("netflix_renewal_2026_10_03"), "netflix_renewal");
  assertEquals(insightTopic("notif_ambiguous_7bdca5b2e52040f402f2744f"), "notif_ambiguous");
  assertEquals(insightTopic("cycle_start_confirm_16"), "cycle_start_confirm");
  assertEquals(insightTopic(""), "other");
});

// The five Betaderm alerts on the live project — every one still pending, each shown on Home a minute
// after it was written (seen_at, 20261011293145).
const shown = (iso: string) => ({ created_at: at(iso), seen_at: new Date(Date.parse(iso) + 60_000).toISOString() });
const betaderm = [
  { dedupe_key: "betaderm_low_20261003", title: "بيتادرم قرب يخلص", status: "pending", ...shown("2026-10-03T06:00:00Z") },
  { dedupe_key: "betaderm_low_stock_2026_10_02", title: "بيتادرم قرب يخلص", status: "pending", ...shown("2026-10-02T06:00:00Z") },
  { dedupe_key: "betaderm_low_stock_20261001", title: "بيتادرم قرب يخلص", status: "pending", ...shown("2026-10-01T06:00:00Z") },
  { dedupe_key: "betaderm_low_stock_2026_09_30", title: "بيتادرم قرب يخلص", status: "pending", ...shown("2026-09-30T06:00:00Z") },
  { dedupe_key: "betaderm_low_2026_09_29", title: "بيتادرم قرب يخلص", status: "pending", ...shown("2026-09-29T06:00:00Z") },
];
const unseen = betaderm.map(({ seen_at: _, ...r }) => r);

Deno.test("engagement: five ignored Betaderm alerts make the topic quiet; the newest is still in its grace", () => {
  const e = engagementFrom(betaderm, NOW);
  assertEquals(e.quiet_topics, [{ topic: "betaderm_low", ignored_in_a_row: 4, last_title: "بيتادرم قرب يخلص" }]);
});

Deno.test("engagement: acting on one breaks the run; two ignored is not yet quiet", () => {
  const acted = betaderm.map((r, i) => (i === 2 ? { ...r, status: "acted" } : r));
  assertEquals(engagementFrom(acted, NOW).quiet_topics, [], "only one ignored after the grace, then acted");
  assertEquals(engagementFrom(betaderm.slice(0, 3), NOW).quiet_topics, [], "two past the grace");
});

Deno.test("engagement: a card nobody saw is not ignored, and does not break the run", () => {
  // ٣ من ٦ حسابات على الحي مالهمش إشعارات ولا تليجرام: كارت ماظهرش في التطبيق مااتجاهلش.
  assertEquals(engagementFrom(unseen, NOW).quiet_topics, [], "five unseen alerts silence nothing");
  // Shown, unseen, shown, shown: the unseen one in the middle neither counts nor resets.
  const mixed = betaderm.map((r, i) => (i === 2 ? unseen[2] : r));
  assertEquals(engagementFrom(mixed, NOW).quiet_topics, [{ topic: "betaderm_low", ignored_in_a_row: 3, last_title: "بيتادرم قرب يخلص" }]);
});

Deno.test("engagement: the reply window starts when the card was shown, not when it was written", () => {
  // Written four days ago, opened an hour ago: still inside its 48 hours.
  const late = betaderm.slice(1, 4).map((r) => ({ ...r, seen_at: at("2026-10-04T11:00:00Z") }));
  assertEquals(engagementFrom(late, NOW).quiet_topics, []);
});

Deno.test("engagement: on a Telegram-linked account a question or critical card was shown when written", () => {
  const sent = (kind: string, priority: string) => unseen.map((r) => ({ ...r, kind, priority }));
  assertEquals(engagementFrom(sent("question", "normal"), NOW, { telegram: true }).quiet_topics.length, 1);
  assertEquals(engagementFrom(sent("alert", "critical"), NOW, { telegram: true }).quiet_topics.length, 1);
  // The trigger sends neither a plain insight nor anything to an unlinked account.
  assertEquals(engagementFrom(sent("alert", "normal"), NOW, { telegram: true }).quiet_topics, []);
  assertEquals(engagementFrom(sent("question", "normal"), NOW, { telegram: false }).quiet_topics, []);
});

Deno.test("engagement: system receipts and old history do not count", () => {
  const receipts = [1, 2, 3, 4].map((d) => ({ dedupe_key: `txn_confirmed:${d}`, title: "مصروف جديد", status: "pending", created_at: at(`2026-09-2${d}T06:00:00Z`) }));
  const old = betaderm.map((r) => ({ ...r, created_at: at("2026-08-01T06:00:00Z") }));
  assertEquals(engagementFrom([...receipts, ...old], NOW).quiet_topics, []);
});

Deno.test("engagement: what the customer keeps acting on is welcomed", () => {
  const rows = ["w38", "w39", "w40"].map((w, i) => ({
    dedupe_key: `cash_reconciliation_2026_${w}`, title: "تسوية الكاش", status: i === 1 ? "seen" : "acted",
    created_at: at(`2026-09-${15 + i * 7}T06:00:00Z`),
  }));
  assertEquals(engagementFrom(rows, NOW).welcomed_topics, ["cash_reconciliation"]);
});

Deno.test("engagement: the insight tools refuse a quiet topic, except what is critical", async () => {
  const engagement = engagementFrom(betaderm, NOW);
  assert(quietTopicRejection({ dedupe_key: "betaderm_low_2026_10_04" }, engagement)?.includes("تجاهل آخر 4"));
  assertEquals(quietTopicRejection({ dedupe_key: "betaderm_low_2026_10_04", priority: "critical" }, engagement), null);
  assertEquals(quietTopicRejection({ dedupe_key: "milk_low_2026_10_04" }, engagement), null, "another subject");
  assertEquals(quietTopicRejection({ dedupe_key: "betaderm_low" }, null), null, "no history read: no silence");

  const snap = { engagement, upcoming: [{ type: "medication_low" }] };
  const emit = await validateEmitInsight({ title: "بيتادرم", body: "فاضل 1", dedupe_key: "betaderm_low_2026_10_04" }, snap, freshContext("u"));
  assertEquals(emit.ok, false);
  const critical = await validateEmitInsight({ title: "بيتادرم", body: "فاضل 1", dedupe_key: "betaderm_low_2026_10_04", priority: "critical" }, snap, freshContext("u"));
  assertEquals(critical.ok, true);
  const ask = await validateAskUser({ title: "بيتادرم", body: "فاضل كام؟", dedupe_key: "betaderm_low_20261004", answer_type: "number" }, snap, freshContext("u"));
  assertEquals(ask.ok, false);
});
