// «دي كانت مصروف مش دخل» ⇒ اقتراح update_transaction بالنوع الصح على الحركة الوحيدة اللي تطابق (ZAD_PLAN ١٠.٧).
import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { amountsIn, kindFixCandidate, kindFixReply, kindFixTarget, shouldForceKindFix } from "./forcedKindFix.ts";
import { wantsForcedLog } from "./forcedLog.ts";

Deno.test("kind fix: the customer says which kind it should have been", () => {
  // الرسالة اللي فشلت على الإنتاج ١٥/١١.
  assertEquals(kindFixTarget("الـ500 اللي اتسجلت دخل دي غلط، دي كانت مصروف دفعته للسباك"), "expense");
  assertEquals(kindFixTarget("ده مش دخل، ده مصروف"), "expense");
  assertEquals(kindFixTarget("الإيداع ده مش إيداع"), "expense");
  assertEquals(kindFixTarget("ده كان دخل مش مصروف"), "income");
  assertEquals(kindFixTarget("الالفين اللي اتسجلت مصروف دي مرتبي اللي جالي"), "income");
  assertEquals(kindFixTarget("هذا مو مصروف، هذا راتب"), "income");
  assertEquals(kindFixTarget("الـ٥٠٠ دي مش دخل"), "expense");
});

Deno.test("kind fix: anything else is not a kind fix", () => {
  for (const m of [
    "صرفت 500 على السباك",
    "قبضت المرتب 18000",
    "هل الإيداع ده دخل ولا مصروف؟",
    "المصروف بتاع امبارح مش أكل، ده مواصلات",
    "مش فاهم الدخل والمصروف",
    "",
  ]) assertEquals(kindFixTarget(m), null, m);
  // الاتجاهين في نفس الرسالة = مش واضح.
  assertEquals(kindFixTarget("مش دخل ومش مصروف"), null);
});

const RECENT = [
  { id: "t1", title: "إيداع", amount: 500, kind: "income" },
  { id: "t2", title: "قهوة", amount: 50, kind: "expense" },
  { id: "t3", title: "تحويل", amount: 1200, kind: "income" },
  { id: "t4", title: "سباك", amount: 500, kind: "expense" },
];

Deno.test("kind fix: the amount picks the one row of the wrong kind; no amount needs exactly one", () => {
  assertEquals(amountsIn("الـ٥٠٠ و 12.5"), [500, 12.5]);
  assertEquals(kindFixCandidate("الـ500 اتسجلت دخل وهي مصروف", RECENT, "expense")?.id, "t1");
  assertEquals(kindFixCandidate("الـ1200 مش دخل", RECENT, "expense")?.id, "t3");
  // ٢ دخل ومفيش مبلغ ⇒ مفيش تخمين.
  assertEquals(kindFixCandidate("ده مش دخل", RECENT, "expense"), null);
  // مبلغ مالوش حركة من النوع الغلط.
  assertEquals(kindFixCandidate("الـ50 مش دخل", RECENT, "expense"), null);
  // ناحية الدخل: مصروف واحد بـ٥٠ ⇒ هو.
  assertEquals(kindFixCandidate("الـ50 دي مش مصروف", RECENT, "income")?.id, "t2");
  assertEquals(kindFixCandidate("مش مصروف", [{ id: "x", amount: 9, kind: "expense" }], "income")?.id, "x");
  assertEquals(kindFixCandidate("مش مصروف", [{ id: "x", amount: 9, kind: "transfer" }], "income"), null);
  assertEquals(kindFixCandidate("مش مصروف", undefined, "income"), null);
});

Deno.test("kind fix: only after a turn that wrote and proposed nothing; and the reply names the row", () => {
  const msg = "ده مش دخل، ده مصروف";
  assert(shouldForceKindFix(msg, [], 0));
  assert(!shouldForceKindFix(msg, [], 1));
  assert(!shouldForceKindFix(msg, ["update_transaction"], 0));
  assert(!shouldForceKindFix("صرفت 500", [], 0));
  const r = kindFixReply(RECENT[0], "expense", "EGP");
  assertStringIncludes(r, "«إيداع»");
  assertStringIncludes(r, "500 EGP");
  assertStringIncludes(r, "من دخل لـمصروف");
  assertStringIncludes(r, "أكّد");
});

Deno.test("kind fix: the production message would also have been forced into a NEW expense — that is why it runs first", () => {
  // index.ts skips forcedLog whenever kindFixTarget matches; this test pins why.
  assert(wantsForcedLog("الـ500 اللي اتسجلت دخل دي غلط، دي كانت مصروف دفعته للسباك", WRITE_REPLY));
});
const WRITE_REPLY = "لسه **ماعملتش** ده، مفيش حاجة اتسجلت 🙏 ابعتلي طلبك تاني وأنا أنفذه.";
