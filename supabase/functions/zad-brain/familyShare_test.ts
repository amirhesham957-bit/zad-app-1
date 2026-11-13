// ZAD_PLAN ١٠.٢(ج): طبقة العيلة — مين يتسأل، عن أنهي ملاحظة، وإمتى، والجواب بيوصل إزاي.
import { assert, assertEquals } from "jsr:@std/assert@1";
import { askHistory, mayAsk } from "./askedLedger.ts";
import { askedThisMorning } from "./curiosity.ts";
import {
  FAMILY_SHARE_GAP_DAYS, familyShareAskKey, familyShareCandidate, householdFact, type ShareableNote, shareable,
  sharedFromCurrentMembers,
} from "./familyShare.ts";
import { intentToolHints } from "./specialists.ts";
import { freshContext, MUTATING_TOOLS, validateTool } from "./validators.ts";

const DAY = 86_400_000;
const NOW = Date.parse("2026-11-13T08:00:00Z");
const note = (id: string, text: string, extra: Partial<ShareableNote> = {}): ShareableNote => ({
  id, scope: "general", note: text, family_id: null, superseded_by: null, valid_until: null, evidence_count: 1,
  last_seen: "2026-11-10T10:00:00Z", ...extra,
});
const empty = askHistory([]);
const opts = (o: Partial<Parameters<typeof familyShareCandidate>[1]> = {}) => ({
  role: "admin", familySize: 3, history: empty, nowMs: NOW, ...o,
});

Deno.test("household facts are about the house, personal ones are not", () => {
  for (const t of ["بيدفع قسط العربية ٣٠٠٠ كل شهر", "الإيجار بيتدفع يوم ٥", "عيد ميلاد ابني ١٩ أغسطس", "فاتورة النت ٤٥٠", "الأولاد في مدرسة النيل"]) {
    assert(householdFact(t), t);
  }
  for (const t of ["بيحب القهوة من غير سكر", "شغله محاسب", "النتيجة طلعت كويسة"]) assertEquals(householdFact(t), false, t);
});

Deno.test("only live, private, non-sensitive general notes are offered", () => {
  assert(shareable(note("a", "قسط العربية ٣٠٠٠"), NOW));
  assertEquals(shareable(note("b", "قسط العربية ٣٠٠٠", { family_id: "f1" }), NOW), false);
  assertEquals(shareable(note("c", "قسط العربية ٣٠٠٠", { superseded_by: "x" }), NOW), false);
  assertEquals(shareable(note("d", "قسط العربية ٣٠٠٠", { scope: "weekly_synthesis" }), NOW), false);
  assertEquals(shareable(note("e", "قسط العربية ٣٠٠٠", { valid_until: "2026-11-01T00:00:00Z" }), NOW), false);
  // حساس (sensitiveMemory.ts): مابيتعرضش حتى لو كلامه عن البيت.
  assertEquals(shareable(note("f", "مراتي حامل في الشهر الرابع"), NOW), false);
});

Deno.test("a child, or a family of one, is never asked", () => {
  const notes = [note("a", "قسط العربية ٣٠٠٠")];
  assertEquals(familyShareCandidate(notes, opts({ role: "child" })), null);
  assertEquals(familyShareCandidate(notes, opts({ role: null })), null);
  assertEquals(familyShareCandidate(notes, opts({ familySize: 1 })), null);
  assertEquals(familyShareCandidate(notes, opts())?.memory_id, "a");
});

Deno.test("each note is asked about once, and sharing questions come at most weekly", () => {
  const notes = [note("a", "قسط العربية ٣٠٠٠"), note("b", "الإيجار بيتدفع يوم ٥")];
  const askedA = (daysAgo: number) =>
    askHistory([{
      facts: { daily_question: "q", daily_question_kind: "family_share", family_share: { memory_id: "a" } },
      created_at: new Date(NOW - daysAgo * DAY).toISOString(),
    }]);
  // سأل عن a من يومين ⇒ مفيش سؤال الأسبوع ده خالص.
  assertEquals(familyShareCandidate(notes, opts({ history: askedA(2) })), null);
  // بعد أسبوع ⇒ b (مش a تاني، حتى لو قال لأ).
  assertEquals(familyShareCandidate(notes, opts({ history: askedA(FAMILY_SHARE_GAP_DAYS) }))?.memory_id, "b");
  assertEquals(familyShareCandidate([notes[0]], opts({ history: askedA(60) })), null);
  // المفتاح بيتسجل في نفس الدفتر بتاع باقي الأسئلة.
  assertEquals(mayAsk(familyShareAskKey("a"), askedA(2), NOW), false);
});

Deno.test("the most-evidenced household fact goes first", () => {
  const picked = familyShareCandidate([
    note("new", "فاتورة الكهربا ٨٠٠", { last_seen: "2026-11-12T10:00:00Z" }),
    note("strong", "قسط العربية ٣٠٠٠", { evidence_count: 4 }),
    note("me", "بيحب القهوة", { evidence_count: 9 }),
  ], opts());
  assertEquals(picked?.memory_id, "strong");
  assert(picked?.question.includes("قسط العربية"));
});

Deno.test("the morning answer carries the note id to the chat turn", () => {
  const asked = askedThisMorning({
    sent_at: new Date(NOW - 2 * 3_600_000).toISOString(),
    facts: { daily_question: "تحب أشاركها؟", daily_question_kind: "family_share", family_share: { memory_id: "m1", note: "قسط" } },
  }, NOW);
  assertEquals(asked?.kind, "family_share");
  assertEquals(asked?.memory_id, "m1");
});

Deno.test("a shared note disappears once its writer leaves the family, and fails closed", () => {
  const rows = [{ id: "n1", user_id: "mom", note: "x" }, { id: "n2", user_id: "gone", note: "y" }];
  assertEquals(sharedFromCurrentMembers(rows, [{ user_id: "mom", alias: "ماما" }, { user_id: "me" }]), [{ id: "n1", note: "x", shared_by: "ماما" }]);
  // من غير اسم: «فرد في العيلة»، عشان الملاحظة ماتتقريش كأنها عن اللي بيتكلم.
  assertEquals(sharedFromCurrentMembers(rows, [{ user_id: "mom", alias: " " }])[0].shared_by, "فرد في العيلة");
  assertEquals(sharedFromCurrentMembers(rows, null), []);
});

Deno.test("sharing takes one known note and an explicit yes/no", async () => {
  const snap = { memory: [{ id: "m1" }], asked_this_morning: { memory_id: "m2" } };
  assertEquals((await validateTool("share_memory_with_family", { memory_id: "m1", share: true }, snap, freshContext("u1"))).ok, true);
  assertEquals((await validateTool("share_memory_with_family", { memory_id: "m2", share: false }, snap, freshContext("u1"))).ok, true);
  assertEquals((await validateTool("share_memory_with_family", { memory_id: "m9", share: true }, snap, freshContext("u1"))).ok, false);
  assertEquals((await validateTool("share_memory_with_family", { memory_id: "m1" }, snap, freshContext("u1"))).ok, false);
  assertEquals((await validateTool("share_memory_with_family", { memory_id: "m1", share: "yes" }, snap, freshContext("u1"))).ok, false);
  const ctx = freshContext("u1");
  ctx.counts["share_memory_with_family"] = 1;
  assertEquals((await validateTool("share_memory_with_family", { memory_id: "m1", share: true }, snap, ctx)).ok, false);
  assert(MUTATING_TOOLS.includes("share_memory_with_family"));
});

Deno.test("«share it with the family» / «keep it to me» bring the tool, other talk does not", () => {
  for (const msg of ["شاركها مع العيلة", "شارك ده مع مراتي", "خليها ليا", "ماتشاركش الموضوع ده", "شيلها من العيلة"]) {
    assert(intentToolHints(msg).includes("share_memory_with_family"), msg);
  }
  for (const msg of ["شاركت في الجمعية", "العيلة كلها مسافرة"]) {
    assertEquals(intentToolHints(msg).includes("share_memory_with_family"), false, msg);
  }
});
