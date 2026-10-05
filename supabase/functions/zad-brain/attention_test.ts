// منسّق الانتباه: ترتيب، سقف لكل قناة، ومن غير تكرار بين القنوات.
import { assert, assertEquals } from "jsr:@std/assert@1";
import { ALERT_DEFAULT_TTL_MS, cardBudgetRejection, chooseNotes, insightExpiry, isLive, noteScore, OPEN_CARDS_MAX, openCards, recentCardTitles } from "./attention.ts";
import { deliverAgentMail } from "./agentMail.ts";
import { engagementFrom } from "./engagement.ts";
import { freshContext, validateAskUser, validateEmitInsight } from "./validators.ts";

const NOW = Date.parse("2026-10-04T12:00:00Z");
const ago = (h: number) => new Date(NOW - h * 3_600_000).toISOString();
const note = (id: string, sender: string, subject: string, hours = 1, detail: string | null = null) =>
  ({ id, sender, subject, detail, created_at: ago(hours) });

Deno.test("attention: health first, then money; urgency lifts, age lowers, a week old is gone", () => {
  const ctx = { now: NOW };
  const med = noteScore(note("1", "pharmacy", "دوا متجدد خلص خالص: كونكور"), ctx);
  const money = noteScore(note("2", "finance", "مفيش سقف مصروف للشهر"), ctx);
  const setup = noteScore(note("3", "brain", "تليجرام مش مربوط"), ctx);
  assert(med > money && money > setup, `${med} ${money} ${setup}`);
  assert(noteScore(note("4", "finance", "مفيش سقف مصروف للشهر", 72), ctx) < money, "three days old");
  assertEquals(noteScore(note("5", "pharmacy", "دوا خلص", 8 * 24), ctx), 0);
});

Deno.test("attention: a note about what a card said today, or about an ignored topic, is not said again", () => {
  const cards = ["بيتادرم قرب يخلص"];
  assertEquals(noteScore(note("1", "pharmacy", "دوا متجدد فاضله ٣ أيام أو أقل: بيتادرم"), { now: NOW, cardTitles: cards }), 0);
  assert(noteScore(note("2", "pharmacy", "دوا متجدد فاضله ٣ أيام أو أقل: كونكور"), { now: NOW, cardTitles: cards }) > 0);
  const engagement = engagementFrom([1, 2, 3].map((d) => ({
    dedupe_key: `oil_consumption_${d}`, title: "الزيت هيخلص", status: "pending", created_at: ago(24 * (d + 2)),
  })), NOW);
  assertEquals(noteScore(note("3", "pantry", "الزيت قرب يخلص"), { now: NOW, engagement }), 0);
});

Deno.test("attention: two per chat turn, best first; the rest wait, the stale go", () => {
  const notes = [
    note("a", "brain", "تليجرام مش مربوط"),
    note("b", "pharmacy", "دوا متجدد خلص خالص: كونكور"),
    note("c", "family", "طلب متابعة من العيلة مستني رده"),
    note("d", "finance", "مفيش سقف مصروف للشهر", 9 * 24),
    note("e", "research", "أسعار الرز"),
  ];
  const { deliver, drop } = chooseNotes(notes, { now: NOW, budget: 2 });
  assertEquals(deliver.map((n) => n.id), ["b", "c"]);
  assertEquals(drop.map((n) => n.id), ["d"]);
});

Deno.test("attention: delivering marks only what was said or dropped; the rest stay for the next reply", async () => {
  const marked: string[] = [];
  const sb = {
    from: () => ({
      update: () => ({
        eq: () => ({ in: (_col: string, ids: string[]) => { marked.push(...ids); return Promise.resolve({ error: null }); } }),
      }),
    }),
  } as unknown as Parameters<typeof deliverAgentMail>[0];
  const rows = [
    note("a", "brain", "تليجرام مش مربوط"),
    note("b", "pharmacy", "دوا متجدد خلص خالص: كونكور"),
    note("c", "family", "طلب متابعة من العيلة مستني رده"),
    note("d", "finance", "مفيش سقف مصروف للشهر", 9 * 24),
  ];
  const said = await deliverAgentMail(sb, "u", rows, { now: NOW });
  assertEquals(said.map((r) => r.id), ["b", "c"]);
  assertEquals(marked.sort(), ["b", "c", "d"], "«a» waits for another reply");
  assertEquals(await deliverAgentMail(sb, "u", null, { now: NOW }), []);
});

Deno.test("attention: open cards are pending, non-critical, not receipts, last three days", () => {
  const rows = [
    { dedupe_key: "betaderm_low_20261003", status: "pending", priority: "normal", surface: "home_card", created_at: ago(10) },
    { dedupe_key: "budget_pace", status: "pending", priority: null, surface: "bell", created_at: ago(30) },
    { dedupe_key: "netflix_renewal", status: "pending", priority: "normal", surface: "home_card", created_at: ago(60) },
    { dedupe_key: "old", status: "pending", priority: "normal", surface: "home_card", created_at: ago(80) },
    { dedupe_key: "txn_confirmed:1", status: "pending", priority: "normal", surface: "voice", created_at: ago(1) },
    { dedupe_key: "out_of_money", status: "pending", priority: "critical", surface: "home_card", created_at: ago(1) },
    { dedupe_key: "seen_one", status: "seen", priority: "normal", surface: "home_card", created_at: ago(1) },
  ];
  assertEquals(openCards(rows, NOW), 3);
  assertEquals(recentCardTitles([{ dedupe_key: "x", status: "pending", title: "بيتادرم قرب يخلص", created_at: ago(5) },
    { dedupe_key: "y", status: "pending", title: "قديم", created_at: ago(30) }], NOW), ["بيتادرم قرب يخلص"]);
});

Deno.test("attention: three open cards hold back a new one, except what is critical", async () => {
  assert(cardBudgetRejection({}, { open_cards: OPEN_CARDS_MAX })?.includes("هدوء التجربة"));
  assertEquals(cardBudgetRejection({ priority: "critical" }, { open_cards: 9 }), null);
  assertEquals(cardBudgetRejection({}, { open_cards: 2 }), null);
  assertEquals(cardBudgetRejection({}, null), null, "no reading: no silence");
  const snap = { attention: { open_cards: 3 }, available: -5 };
  assertEquals((await validateEmitInsight({ title: "تنبيه", body: "فاضل 50", dedupe_key: "x_1" }, snap, freshContext("u"))).ok, false);
  assertEquals((await validateEmitInsight({ title: "تنبيه", body: "فاضل 50", dedupe_key: "x_1", priority: "critical" }, snap, freshContext("u"))).ok, true);
  assertEquals((await validateAskUser({ title: "؟", body: "كام؟", dedupe_key: "q_1", answer_type: "number" }, snap, freshContext("u"))).ok, false);
});

Deno.test("attention: generic words alone never make two different things the same", () => {
  // «متجدد … فاضله … الشهر» are in both; the medicine differs.
  assert(noteScore(note("1", "pharmacy", "دوا متجدد فاضله ٣ أيام أو أقل: كونكور"), {
    now: NOW, cardTitles: ["دوا متجدد فاضله يومين: بيتادرم"],
  }) > 0);
});

Deno.test("attention: a card about a day ends with that day; an alert with no day ends after 48h", async () => {
  // «تجديد نتفليكس بكرة ٣ أكتوبر» اتكتب ٢ أكتوبر وفضل ظاهر ٥ أكتوبر.
  assertEquals(insightExpiry("alert", "2026-10-03T21:00:00.000Z", NOW), "2026-10-03T21:00:00.000Z");
  assertEquals(insightExpiry("insight", "2026-10-03T21:00:00.000Z", NOW), "2026-10-03T21:00:00.000Z");
  assertEquals(insightExpiry("alert", null, NOW), new Date(NOW + ALERT_DEFAULT_TTL_MS).toISOString());
  assertEquals(insightExpiry("insight", null, NOW), null);
  assertEquals(insightExpiry(undefined, null, NOW), null);

  assert(isLive({ expires_at: null }, NOW));
  assert(isLive({ expires_at: ago(-1) }, NOW));
  assert(!isLive({ expires_at: ago(1) }, NOW));

  // كارت منتهي مابيحجزش مكان في سقف الـ٣ كروت.
  const card = (k: string, expires_at: string | null) =>
    ({ dedupe_key: k, status: "pending", priority: "normal", surface: "home_card", created_at: ago(30), expires_at });
  assertEquals(openCards([card("a", ago(2)), card("b", null), card("c", ago(-5))], NOW), 2);

  // valid_until مش مفهوم ⇒ رفض بسبب، مش كارت من غير نهاية.
  const snap = { now_local: { date: "2026-10-04", time_zone: "Africa/Cairo" } };
  const bad = await validateEmitInsight(
    { title: "تجديد", body: "300 جنيه", dedupe_key: "netflix_1", valid_until: "بكرة" }, snap, freshContext("u"));
  assertEquals(bad.ok, false);
});
