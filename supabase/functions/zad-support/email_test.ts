import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { buildSupportEmail, DEFAULT_SUPPORT_INBOX, sendSupportEmail } from "./email.ts";

const ticket = {
  id: "t1", userId: "u1", contactEmail: "c@x.com", subject: "الصيدلية فاضية",
  message: "صفحة الصيدلية مش بتعرض حاجة", conversation: [{ text: "مش شغالة", isUser: true }],
  crashLog: "Null check operator", appVersion: "1.0.0+1", device: "Xiaomi", createdAt: "2026-09-30T12:00:00Z",
};

Deno.test("the email carries the complaint, who to answer, and the crash log", () => {
  const e = buildSupportEmail(ticket);
  assertEquals(e.subject, "[زاد – دعم] الصيدلية فاضية");
  assertEquals(e.replyTo, "c@x.com");
  assertStringIncludes(e.text, "صفحة الصيدلية مش بتعرض حاجة");
  assertStringIncludes(e.text, "c@x.com");
  assertStringIncludes(e.text, "Null check operator");
  assertStringIncludes(e.text, "العميل: مش شغالة");
});

Deno.test("the inbox is the owner's", () => {
  assertEquals(DEFAULT_SUPPORT_INBOX, "astralabs.supp@gmail.com");
});

Deno.test("no key: not sent, nothing thrown", async () => {
  assertEquals(await sendSupportEmail(buildSupportEmail(ticket), DEFAULT_SUPPORT_INBOX, undefined, "x"), false);
});

Deno.test("sends to the inbox through Resend with reply-to", async () => {
  let sent: Record<string, unknown> | null = null;
  const fake = ((_u: string, init: RequestInit) => {
    sent = JSON.parse(init.body as string);
    return Promise.resolve(new Response("{}", { status: 200 }));
  }) as unknown as typeof fetch;
  assertEquals(await sendSupportEmail(buildSupportEmail(ticket), DEFAULT_SUPPORT_INBOX, "k", "Zad <a@b>", fake), true);
  assertEquals((sent as unknown as { to: string[] }).to, ["astralabs.supp@gmail.com"]);
  assertEquals((sent as unknown as { reply_to: string }).reply_to, "c@x.com");
});

Deno.test("Resend refusing is false, not an exception", async () => {
  const fake = (() => Promise.resolve(new Response("bad", { status: 422 }))) as unknown as typeof fetch;
  assertEquals(await sendSupportEmail(buildSupportEmail(ticket), DEFAULT_SUPPORT_INBOX, "k", "x", fake), false);
});
