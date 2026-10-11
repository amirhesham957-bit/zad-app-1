// «دول نفس الحاجة؟» in the morning greeting: the day's one question, carrying its answer tool to
// the chat (asked_this_morning.tool), ahead of ordinary curiosity.
import { assertEquals } from "jsr:@std/assert@1";
import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { askedThisMorning } from "./curiosity.ts";
import { morningFacts } from "./voiceMoments.ts";
import { weatherSource } from "./weather.ts";
import { dealSource } from "./tasteDeals.ts";

weatherSource.fetch = () => Promise.reject(new Error("no network in unit tests"));
dealSource.search = () => Promise.reject(new Error("no network in unit tests"));

function fakeSb(tables: Record<string, unknown[]>, rpcs: Record<string, unknown>): SupabaseClient {
  const chain = (data: unknown): unknown =>
    new Proxy({}, {
      get(_t, prop) {
        if (prop === "then") {
          return (res: (v: unknown) => unknown, rej: (e: unknown) => unknown) =>
            Promise.resolve({ data, error: null }).then(res, rej);
        }
        if (prop === "maybeSingle" || prop === "single") return () => chain(Array.isArray(data) ? data[0] ?? null : data);
        return () => chain(data);
      },
    });
  return { from: (t: string) => chain(tables[t] ?? []), rpc: (fn: string) => chain(rpcs[fn] ?? null) } as unknown as SupabaseClient;
}

// An odd day: the occasion question does not take the slot (it alternates with curiosity).
const LOCAL = { date: "2026-10-05", time_zone: "Africa/Cairo", utc_offset: "+03:00" };
const FULL_PROFILE = {
  preferred_name: "سارة", gender: "female", household_role: "أم", pay_day: 25, cares_for: "ولدين", occupation: "مدرسة",
};
const BASE = {
  zad_customer_profile: [FULL_PROFILE],
  zad_users: [{ id: "u", country: "EG", created_at: "2025-01-01T00:00:00Z" }],
};

Deno.test("milk under two names: the morning asks once, and the chat gets the tool", async () => {
  const sb = fakeSb({ ...BASE, zad_inventory: [{ item_name: "لبن" }, { item_name: "حليب" }] }, { zad_budget_state: {} });
  const facts = await morningFacts(sb, "u", LOCAL);
  assertEquals(facts.daily_question_kind, "curiosity");
  const c = facts.curiosity as { kind: string; tool?: string; key: string };
  assertEquals([c.kind, c.tool], ["same_product", "answer_same_product"]);
  assertEquals(String(facts.daily_question).includes("«لبن»"), true);

  const asked = askedThisMorning({ facts, sent_at: "2026-10-05T06:00:00Z" }, Date.parse("2026-10-05T09:00:00Z"));
  assertEquals(asked?.tool, "answer_same_product");
});

Deno.test("an answered pair is not asked: the slot goes back to ordinary curiosity", async () => {
  const sb = fakeSb({
    ...BASE,
    zad_inventory: [{ item_name: "لبن" }, { item_name: "حليب" }],
    zad_product_pairs: [{ a_key: "حليب", b_key: "لبن" }],
  }, { zad_budget_state: {} });
  const facts = await morningFacts(sb, "u", LOCAL);
  assertEquals((facts.curiosity as { kind?: string } | undefined)?.kind === "same_product", false);
});
