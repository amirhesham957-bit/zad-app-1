import { assert, assertEquals } from "jsr:@std/assert@1";
import { extendCallback, formatExtend, formatLookup, parseExtendCallback, parseSupportCommand } from "./supportDesk.ts";

const ID = "fb9bd2ac-38c1-46a3-8e3e-e5b24c7092d4";

Deno.test("/support takes an id or an email, nothing else", () => {
  assertEquals(parseSupportCommand("support", ID), { kind: "lookup", query: ID });
  assertEquals(parseSupportCommand("support", " Someone@Mail.com "), { kind: "lookup", query: "someone@mail.com" });
  assertEquals(parseSupportCommand("support", "ميرو").kind, "usage");
  assertEquals(parseSupportCommand("support", "").kind, "usage");
});

Deno.test("/extend: an id, 1–90 days, an optional paid tier", () => {
  assertEquals(parseSupportCommand("extend", `${ID} 30`), { kind: "extend", userId: ID, days: 30, tier: null });
  assertEquals(parseSupportCommand("extend", `${ID} 7 plus`), { kind: "extend", userId: ID, days: 7, tier: "plus" });
  for (const bad of [`${ID} 0`, `${ID} 91`, `${ID} 3.5`, `${ID} 7 free`, `abc 7`, ID]) {
    assertEquals(parseSupportCommand("extend", bad).kind, "usage", bad);
  }
});

Deno.test("the confirm button round-trips and fits Telegram's 64 bytes", () => {
  const cb = extendCallback(ID, 30, "plus");
  assert(new TextEncoder().encode(cb).length <= 64);
  assertEquals(parseExtendCallback(cb), { userId: ID, days: 30, tier: "plus" });
  assertEquals(parseExtendCallback(extendCallback(ID, 7, null))?.tier, null);
  assertEquals(parseExtendCallback(`sx:${ID}:500:-`), null);
  assertEquals(parseExtendCallback("sx:cancel"), null);
});

Deno.test("the lookup reply is technical state only", () => {
  const text = formatLookup({
    found: true, user_id: ID, created_at: "2026-10-01T10:00:00Z", country: "EG", tier: "free",
    chat_left: 3, scan_left: 1, last_open: "2026-11-06T09:00:00Z", bank_last: "bank.off",
    bank_last_at: "2026-11-05T09:00:00Z", telegram: true, brain_runs_7d: 12,
    brain_failed_7d: { "الذكاء مش متاح (الكوتة المجانية خلصت)": 2 },
    tickets: [{ at: "2026-11-04T00:00:00Z", subject: "البنك", status: "open" }],
    // Fields a careless change might add: they must never be printed.
    transactions: [{ amount: 500, merchant_name: "كارفور" }], balance: 1234,
  });
  assert(text.includes("اتقفلت"));
  assert(text.includes("×2"));
  assert(!text.includes("كارفور") && !text.includes("500") && !text.includes("1234"));
  assertEquals(formatLookup({ found: false }), "مالقيتش حساب بالـID أو الإيميل ده.");
});

Deno.test("the renewal reply says what happened", () => {
  assert(formatExtend({ ok: true, applied: true, tier: "pro", until: "2026-12-07T00:00:00Z" }).includes("2026-12-07"));
  assert(formatExtend({ ok: true, applied: false, reason: "higher_plan_active" }).includes("باقة أعلى"));
  assert(formatExtend({ ok: false, reason: "no_such_user" }).includes("مش موجود"));
});
