// The support email: what the inbox receives for one ticket, and sending it.

/** Where complaints go unless SUPPORT_INBOX says otherwise. */
export const DEFAULT_SUPPORT_INBOX = "astralabs.supp@gmail.com";

export interface SupportTicket {
  id: string;
  userId: string;
  contactEmail: string | null;
  subject: string;
  message: string;
  conversation: Array<{ text: string; isUser: boolean }> | null;
  crashLog: string | null;
  appVersion: string | null;
  device: string | null;
  createdAt: string;
}

export interface SupportEmail {
  subject: string;
  text: string;
  replyTo: string | null;
}

const clip = (s: string, n: number) => (s.length > n ? `${s.slice(0, n)}…` : s);

/** The email for [t]: the complaint first, then who and what to answer with. */
export function buildSupportEmail(t: SupportTicket): SupportEmail {
  const lines: string[] = [
    t.message.trim(),
    "",
    "───────────────",
    `التذكرة: ${t.id}`,
    `العميل: ${t.contactEmail ?? "(بدون إيميل)"} — ${t.userId}`,
    `الوقت: ${t.createdAt}`,
  ];
  if (t.appVersion) lines.push(`نسخة التطبيق: ${t.appVersion}`);
  if (t.device) lines.push(`الجهاز: ${t.device}`);
  if (t.conversation?.length) {
    lines.push("", "── محادثة الدعم ──");
    for (const m of t.conversation.slice(-20)) lines.push(`${m.isUser ? "العميل" : "المساعد"}: ${clip(m.text, 1000)}`);
  }
  if (t.crashLog?.trim()) lines.push("", "── سجل الأعطال ──", clip(t.crashLog.trim(), 20000));
  return {
    subject: `[زاد – دعم] ${clip(t.subject.trim(), 120)}`,
    text: lines.join("\n"),
    replyTo: t.contactEmail,
  };
}

/**
 * Sends [email] to [inbox] through Resend. False when there is no key or
 * Resend refused — the ticket is saved either way, and the app offers the
 * customer their own mail app instead.
 */
export async function sendSupportEmail(
  email: SupportEmail,
  inbox: string,
  apiKey: string | undefined,
  from: string,
  fetcher: typeof fetch = fetch,
): Promise<boolean> {
  if (!apiKey) return false;
  try {
    const res = await fetcher("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        from,
        to: [inbox],
        subject: email.subject,
        text: email.text,
        ...(email.replyTo ? { reply_to: email.replyTo } : {}),
      }),
      signal: AbortSignal.timeout(10_000),
    });
    if (!res.ok) console.error(`[Support] Resend HTTP ${res.status}: ${(await res.text()).slice(0, 300)}`);
    return res.ok;
  } catch (e) {
    console.error(`[Support] Resend threw: ${String((e as Error)?.message ?? e).slice(0, 200)}`);
    return false;
  }
}
