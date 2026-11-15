import { assert, assertEquals } from "jsr:@std/assert@1";
import { endsOnProposals, proposalsReply } from "./proposalStop.ts";
import { CONFIRM_REQUIRED_TOOLS } from "./validators.ts";

const base = {
  calledTools: ["log_transaction"], proposedInRound: 1, hintedTools: [] as string[],
  confirmTools: CONFIRM_REQUIRED_TOOLS, totalProposals: 1, message: "صرفت 50 جنيه قهوة",
};

Deno.test("one money log that became a card ends the turn", () => {
  assert(endsOnProposals(base));
});

Deno.test("a rejected proposal goes back to the model to fix it", () => {
  assert(!endsOnProposals({ ...base, proposedInRound: 0, totalProposals: 0 }));
});

Deno.test("a read tool in the same round keeps the loop going", () => {
  assert(!endsOnProposals({ ...base, calledTools: ["gold_price", "log_transaction"] }));
});

Deno.test("a reminder asked in the same message keeps the loop going", () => {
  assert(!endsOnProposals({ ...base, hintedTools: ["add_appointment"], message: "دفعت 300 للدكتور وفكرني بالمتابعة بكرة" }));
});

Deno.test("a second request after «و» keeps the loop going", () => {
  assert(!endsOnProposals({ ...base, message: "صرفت 50 قهوة وضيف عيش للقايمة" }));
});

Deno.test("two amounts with one proposal keep the loop going; two proposals end it", () => {
  const two = { ...base, message: "قهوة 50 وعيش 20" };
  assert(!endsOnProposals(two));
  assert(endsOnProposals({ ...two, calledTools: ["log_transaction", "log_transaction"], proposedInRound: 2, totalProposals: 2 }));
});

Deno.test("a gold log after gold_price ends on the proposal round", () => {
  const gold = { ...base, hintedTools: ["gold_price"], message: "اشتريت 5 جرام ذهب" };
  assert(!endsOnProposals(gold));
  assert(endsOnProposals({ ...gold, calledBefore: ["gold_price"] }));
});

Deno.test("thousands separators count as one amount", () => {
  assert(endsOnProposals({ ...base, message: "قبضت المرتب 14,500" }));
});

Deno.test("the reply is the card's summary", () => {
  assertEquals(proposalsReply(["مصروف 50 EGP قهوة"]), "مصروف 50 EGP قهوة — أكّد من الكارت وأنا أسجّله.");
  assert(proposalsReply(["أ", "ب"]).includes("الكروت"));
});
