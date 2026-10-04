// تصويت العيلة في العقل: ملخص بالأرقام، بموافقة الكاتب، وشكل تصويت جديد بنفس حدود السيرفر.
import { assert, assertEquals } from "jsr:@std/assert@1";
import { newPollMetadata, pollSummaries } from "./familyPolls.ts";
import { familyPushText } from "./familyPush.ts";
import { buildChatSystemPrompt } from "./index.ts";

const members = [
  { id: "m-dad", alias: "بابا", user_id: "u-dad", role: "admin" },
  { id: "m-mum", alias: "ماما", user_id: "u-mum", role: "member" },
  { id: "m-omar", alias: "عمر", user_id: "u-omar", role: "child" },
];
const poll = (id: string, sender: string, meta: Record<string, unknown>) =>
  ({ id, sender_id: sender, metadata: JSON.stringify(meta), created_at: "2026-10-04T10:00:00Z" });

Deno.test("polls: counts, my vote and who has not voted yet", () => {
  const [p] = pollSummaries({
    rows: [poll("p1", "zad_ai", { question: "نسافر فين؟", options: ["الساحل", "الأقصر"], votes: { "m-dad": 1, "m-omar": 0 } })],
    members, me: "u-dad", consentingUserIds: new Set(),
  });
  assertEquals(p.by, "زاد");
  assertEquals(p.options, [{ text: "الساحل", votes: 1 }, { text: "الأقصر", votes: 1 }]);
  assertEquals(p.my_vote, 1);
  assertEquals(p.waiting_for, ["ماما"]);
  assertEquals(p.closed, false);
});

Deno.test("polls: a member's poll reaches the brain only with that member's yes", () => {
  const rows = [poll("p2", "m-mum", { question: "أكل الجمعة؟", options: ["مشويات", "بيتزا"], votes: {} })];
  assertEquals(pollSummaries({ rows, members, me: "u-dad", consentingUserIds: new Set() }), []);
  assertEquals(pollSummaries({ rows, members, me: "u-dad", consentingUserIds: new Set(["u-mum"]) }).length, 1);
});

Deno.test("polls: a closed poll carries its winner and whether the adults agree", () => {
  const [p] = pollSummaries({
    rows: [poll("p3", "zad_ai", {
      question: "نسافر فين؟", options: ["الساحل", "الأقصر"], votes: { "m-dad": 1, "m-mum": 1 },
      closed: true, result: { winner: 1, consensus: true },
    })],
    members, me: "u-mum", consentingUserIds: new Set(),
  });
  assertEquals(p.winner, "الأقصر");
  assertEquals(p.consensus, true);
  assertEquals(p.waiting_for, [], "nobody waits on a closed poll");
});

Deno.test("polls: votes from people no longer in the family, and broken rows, are ignored", () => {
  const out = pollSummaries({
    rows: [
      poll("p4", "zad_ai", { question: "؟", options: ["أ", "ب"], votes: { "m-gone": 0, "m-dad": 5 } }),
      { id: "p5", sender_id: "zad_ai", metadata: "{not json", created_at: "2026-10-04T10:00:00Z" },
      poll("p6", "zad_ai", { question: "سؤال", options: ["واحد"] }),
    ],
    members, me: "u-dad", consentingUserIds: new Set(),
  });
  assertEquals(out.map((p) => p.id), ["p4"]);
  assertEquals(out[0].options.map((o) => o.votes), [0, 0]);
});

Deno.test("polls: a new poll has the server's shape — 2 to 6 distinct options, a closing time", () => {
  const now = Date.parse("2026-10-04T12:00:00Z");
  const m = newPollMetadata({ question: "  نسافر   فين؟ ", options: ["الساحل", "الأقصر", "الساحل", " "] }, now)!;
  assertEquals(m.question, "نسافر فين؟");
  assertEquals(m.options, ["الساحل", "الأقصر"]);
  assertEquals(m.votes, {});
  assertEquals(m.closes_at, "2026-10-06T12:00:00.000Z", "48 hours by default");
  assertEquals(newPollMetadata({ question: "؟", options: ["واحد"] }), null);
  assertEquals(newPollMetadata({ question: "", options: ["أ", "ب"] }), null);
  assertEquals(newPollMetadata({ question: "؟", options: ["1", "2", "3", "4", "5", "6", "7"] }), null);
  assertEquals(newPollMetadata({ question: "؟", options: ["أ", "ب"], closes_in_hours: 10_000 }, now)!.closes_at,
    "2026-10-18T12:00:00.000Z", "two weeks at most");
});

Deno.test("polls: Zad's own poll and the result reach the whole family; its other chat replies do not", () => {
  assertEquals(familyPushText({ sender_id: "zad_ai", message_type: "POLL", message: "📊 نسافر فين؟", alias: "" })?.title, "زاد بيسأل العيلة");
  assertEquals(familyPushText({
    sender_id: "zad_ai", message_type: "TEXT", message: "📊 نتيجة «نسافر فين؟»: الأقصر",
    metadata: JSON.stringify({ kind: "poll_result" }), alias: "",
  })?.title, "نتيجة تصويت العيلة");
  assertEquals(familyPushText({ sender_id: "zad_ai", message_type: "TEXT", message: "ضفت العيش", alias: "" }), null);
});

Deno.test("polls: the chat rule shows only when the family has polls", () => {
  const withPolls = buildChatSystemPrompt({ family: { polls: [] } });
  assert(withPolls.includes("**family.polls**"));
  assertEquals(buildChatSystemPrompt({ family: {} }).includes("**family.polls**"), false);
});
