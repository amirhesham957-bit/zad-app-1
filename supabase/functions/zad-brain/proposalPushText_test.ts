import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { proposalPushText } from "./push.ts";

Deno.test("proposalPushText: amount, currency and merchant in the question", () => {
  assertEquals(
    proposalPushText({ amount: 250, currency: "EGP", merchant_name: "كارفور", txn_kind: "expense" }),
    { title: "اتخصم 250 EGP — إنت؟", body: "كارفور. أكّدها أو قولي مش إنت من هنا." },
  );
});

Deno.test("proposalPushText: income and transfer read as such", () => {
  assertEquals(proposalPushText({ amount: 1000, currency: "EGP", txn_kind: "income" }).title, "دخلك 1000 EGP — إنت؟");
  assertEquals(proposalPushText({ amount: 99.5, txn_kind: "transfer" }).title, "اتحوّل 99.5 — إنت؟");
});

Deno.test("proposalPushText: falls back to the title, then to a generic question", () => {
  assertEquals(proposalPushText({ amount: 12.345, title: "Uber" }).body, "Uber. أكّدها أو قولي مش إنت من هنا.");
  assertEquals(proposalPushText({ amount: 12.345 }).title, "اتخصم 12.35 — إنت؟");
  const empty = proposalPushText({});
  assertEquals(empty.title, "زاد محتاج رأيك 💭");
  assertEquals(empty.body.includes("مستنية تأكيدك"), true);
  assertEquals(proposalPushText({ amount: 0, merchant_name: "x" }).title, "زاد محتاج رأيك 💭");
});
