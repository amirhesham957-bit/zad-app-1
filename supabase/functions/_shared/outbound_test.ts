// منسّق الرسايل: ذاكرة واحدة لكل اللي طلع للعميل، من التلات مصادر.
import { assertEquals } from "jsr:@std/assert@1";
import { latestOutboundMs, recentOutbound } from "./outbound.ts";

function fakeSb(tables: Record<string, Array<Record<string, unknown>>>) {
  return {
    from(table: string) {
      let rows = [...(tables[table] ?? [])];
      const q = {
        select: () => q,
        eq: (c: string, v: unknown) => { rows = rows.filter((r) => r[c] === v); return q; },
        in: (c: string, vs: unknown[]) => { rows = rows.filter((r) => vs.includes(r[c])); return q; },
        gte: (c: string, v: string) => { rows = rows.filter((r) => typeof r[c] === "string" && (r[c] as string) >= v); return q; },
        then: (res: (x: { data: unknown[] }) => unknown) => Promise.resolve({ data: rows }).then(res),
      };
      return q;
    },
  };
}

const U = "u1";
const SINCE = "2026-10-17T17:40:00Z";

Deno.test("a dose at 21:00 and the check-in are one memory: both are seen, whoever sent them", async () => {
  const sb = fakeSb({
    zad_voice_moments: [
      { user_id: U, status: "sent", moment: "good_night", sent_at: "2026-10-17T17:55:00Z" },
      { user_id: U, status: "sent", moment: "chat_voice_reply", sent_at: "2026-10-17T17:59:00Z" },
      { user_id: U, status: "pending", moment: "morning_greeting", sent_at: null },
      { user_id: "other", status: "sent", moment: "good_night", sent_at: "2026-10-17T17:58:00Z" },
    ],
    agent_tasks: [
      { user_id: U, status: "done", kind: "spending_ahead", updated_at: "2026-10-17T17:50:00Z" },
      { user_id: U, status: "done", kind: "reminder", updated_at: "2026-10-17T17:57:00Z" },
      { user_id: U, status: "pending", kind: "spend_forecast", updated_at: "2026-10-17T17:56:00Z" },
      { user_id: U, status: "done", kind: "bill_reminder", updated_at: "2026-10-17T10:00:00Z" },
    ],
    telegram_checkin_prompts: [{ user_id: U, sent_at: "2026-10-17T17:45:00Z" }],
  });
  const rows = await recentOutbound(sb, U, SINCE, ["chat_voice_reply"]);
  assertEquals(rows.map((r) => r.kind).sort(), ["checkin", "moment:good_night", "spending_ahead"]);
  assertEquals(latestOutboundMs(rows), Date.parse("2026-10-17T17:55:00Z"));
});

Deno.test("nothing sent is no last message, and a broken read holds nothing back", async () => {
  assertEquals(latestOutboundMs(await recentOutbound(fakeSb({}), U, SINCE)), null);
  const broken = { from: () => { throw new Error("down"); } };
  assertEquals(await recentOutbound(broken, U, SINCE), []);
});
