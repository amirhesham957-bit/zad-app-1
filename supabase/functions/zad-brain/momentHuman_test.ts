// لحظات زاد أقل «أتمتة» (بلاغ المالك ٢٨/١٠): الساعة بتوقيته، و«اقفل يومك» مش نفس الجملة كل ليلة ومابيزنّش لو اتجاهل.
import { assert, assertEquals, assertNotEquals } from "jsr:@std/assert@1";
import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { closeDayAskToday, closeDayIgnored, factsForModel, momentFallback } from "./voiceMoments.ts";

Deno.test("the model gets the dose hour in the customer's zone, never UTC (21:00 Cairo is not «ستة»)", () => {
  const facts = {
    item_name: "Diosmin Plus 30 Tabs",
    time_zone: "Africa/Cairo",
    scheduled_at: "2026-10-27T18:00:00+00:00",
    slots: [{ item_id: "x", scheduled_at: "2026-10-27T18:00:00+00:00" }],
  };
  const out = factsForModel(facts) as { scheduled_at: string; slots: Array<{ scheduled_at: string; item_id: string }> };
  assert(out.scheduled_at.includes("٩:٠٠"), out.scheduled_at);
  assert(!out.scheduled_at.includes("T18"), out.scheduled_at);
  assertEquals(out.slots[0].scheduled_at, out.scheduled_at);
  assertEquals(out.slots[0].item_id, "x");
  // الأصل مااتلمسش.
  assertEquals(facts.scheduled_at, "2026-10-27T18:00:00+00:00");
});

Deno.test("«اقفل يومك» reads differently on consecutive nights", () => {
  const texts = new Set<string>();
  for (const d of ["2026-10-24", "2026-10-25", "2026-10-26", "2026-10-27", "2026-10-28"]) {
    texts.add(momentFallback("close_day", { local_date: d, seen: [], seen_count: 0 }).text);
  }
  assertEquals(texts.size, 5);
  const a = momentFallback("close_day", { local_date: "2026-10-27", seen: [{ name: "قهوة", amount: 50 }], seen_count: 1, currency: "EGP" }).text;
  const b = momentFallback("close_day", { local_date: "2026-10-28", seen: [{ name: "قهوة", amount: 50 }], seen_count: 1, currency: "EGP" }).text;
  assertNotEquals(a, b);
  assert(a.includes("قهوة 50 EGP") && b.includes("قهوة 50 EGP"));
});

Deno.test("ignored three nights running ⇒ asked every third night", () => {
  const asked = ["2026-10-27", "2026-10-28", "2026-10-29", "2026-10-30", "2026-10-31", "2026-11-01"].filter(closeDayAskToday);
  assertEquals(asked.length, 2);
});

function fakeSb(tables: Record<string, unknown[]>): SupabaseClient {
  const chain = (data: unknown): unknown =>
    new Proxy({}, {
      get(_t, prop) {
        if (prop === "then") return (res: (v: unknown) => unknown) => Promise.resolve({ data, error: null }).then(res);
        return () => chain(data);
      },
    });
  return { from: (t: string) => chain(tables[t] ?? []) } as unknown as SupabaseClient;
}

const SENT = [
  { created_at: "2026-10-27T18:30:00Z", facts: { local_date: "2026-10-27" } },
  { created_at: "2026-10-26T18:30:00Z", facts: { local_date: "2026-10-26" } },
  { created_at: "2026-10-25T18:30:00Z", facts: { local_date: "2026-10-25" } },
];

Deno.test("ignored = three sent, no day closed, no reply within three hours", async () => {
  assertEquals(await closeDayIgnored(fakeSb({ zad_voice_moments: SENT }), "u"), true);
  assertEquals(await closeDayIgnored(fakeSb({ zad_voice_moments: SENT, zad_day_closes: [{ local_date: "2026-10-26" }] }), "u"), false);
  assertEquals(await closeDayIgnored(fakeSb({ zad_voice_moments: SENT, zad_chat_turns: [{ created_at: "2026-10-25T19:00:00Z" }] }), "u"), false);
  // رد بعدها بيوم مايتحسبش رد عليها.
  assertEquals(await closeDayIgnored(fakeSb({ zad_voice_moments: SENT, zad_chat_turns: [{ created_at: "2026-10-26T12:00:00Z" }] }), "u"), true);
  assertEquals(await closeDayIgnored(fakeSb({ zad_voice_moments: SENT.slice(0, 2) }), "u"), false);
});
