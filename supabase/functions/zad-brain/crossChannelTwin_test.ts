// ٣ إشعارات لنفس الدفعة (البنك + SMS + InstaPay) ← اقتراح واحد وسؤال واحد (٢٠٢٦-٠٩-٢٥).
import { assertEquals } from "jsr:@std/assert@1";
import { pickCrossChannelTwin } from "./shared.ts";

const NOW = Date.parse("2026-09-25T12:00:00Z");
const ago = (s: number) => new Date(NOW - s * 1000).toISOString();
const sib = (over: Partial<Parameters<typeof pickCrossChannelTwin>[0][number]> = {}) => ({
  id: "p1", status: "awaiting_confirmation", txn_kind: "expense", currency: "EGP",
  transaction_id: null, created_at: ago(60), package_name: "com.google.android.apps.messaging", ...over,
});
const insta = { packageName: "com.egyptianbanks.instapay", currency: "EGP", txnKind: "expense" };

Deno.test("SMS البنك وInstaPay لنفس المبلغ خلال دقيقة = نفس الدفعة", () => {
  assertEquals(pickCrossChannelTwin([sib()], insta, NOW), { id: "p1", status: "awaiting_confirmation" });
});

Deno.test("التالت بيتدمج في الأول، مش في التاني", () => {
  const got = pickCrossChannelTwin([
    sib({ id: "second", created_at: ago(30), package_name: "com.cib.mobile" }),
    sib({ id: "first", created_at: ago(90) }),
  ], insta, NOW);
  assertEquals(got?.id, "first");
});

Deno.test("إشعارين من نفس التطبيق مابيتدمجوش — ممكن يبقوا دفعتين فعلاً", () => {
  assertEquals(pickCrossChannelTwin([sib()], { ...insta, packageName: "com.google.android.apps.messaging" }, NOW), null);
});

Deno.test("بعد ٥ دقايق، أو عملة تانية، أو اتجاه عكسي = مش دمج", () => {
  assertEquals(pickCrossChannelTwin([sib({ created_at: ago(6 * 60) })], insta, NOW), null);
  assertEquals(pickCrossChannelTwin([sib({ currency: "USD" })], insta, NOW), null);
  assertEquals(pickCrossChannelTwin([sib({ txn_kind: "income" })], insta, NOW), null);
});

Deno.test("اقتراح متقيد بيدمج اللي بعده (مايتحسبش مرتين)، والمرفوض لأ", () => {
  assertEquals(pickCrossChannelTwin([sib({ status: "posted", transaction_id: "t1" })], insta, NOW)?.id, "p1");
  assertEquals(pickCrossChannelTwin([sib({ status: "rejected" })], insta, NOW), null);
});

Deno.test("عملة ناقصة في طرف أو اتجاه مش معروف = لسه ممكن يتدمج", () => {
  assertEquals(pickCrossChannelTwin([sib({ currency: null, txn_kind: null })], insta, NOW)?.id, "p1");
});
