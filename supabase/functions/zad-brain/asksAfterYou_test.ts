// «زاد يسأل عليك» (ZAD_PLAN ١٠.١٢): لحظة ignored_days بتتعمل من zad_enqueue_ignored_days (20261113110000).
import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { buildMomentPrompt, cameBackSince, isStillRelevant, momentFallback } from "./voiceMoments.ts";
import { emotionRangeForMoment, situationalEmotion } from "../_shared/zadVoice.ts";

const BLAME = /(ليه|نسيتني|زعلان|زعلانة|سايبني|مش بتسأل|عتاب)/;

Deno.test("asking after him is caring, never sulky or reproachful", () => {
  const range = emotionRangeForMoment("ignored_days");
  assert(!range.includes("sulky") && !range.includes("reproachful") && !range.includes("sad"), range.join(","));
  assertEquals(situationalEmotion("ignored_days", {}), "caring");
});

Deno.test("the fallback asks how he is, without blame; the second ask is the last and calmer", () => {
  const first = momentFallback("ignored_days", { step: 1, days_away: 5 });
  assert(first.text.includes("كويس") && first.speech.length > 0);
  assert(!BLAME.test(first.text + first.speech));
  const second = momentFallback("ignored_days", { step: 2, days_away: 14 });
  assert(second.text !== first.text && !BLAME.test(second.text + second.speech));
});

Deno.test("the prompt carries the no-blame, no-selling rule and the facts stay data", () => {
  const { system, user } = buildMomentPrompt(
    { moment: "ignored_days", facts: { days_away: 6, step: 1, expenses_recorded_while_away: 3, time_zone: "Africa/Cairo" } },
    "EG", "أمير",
  );
  assert(system.includes("من غير لوم") && system.includes("من غير فلوس"));
  assert(user.includes("\"days_away\":6") && user.includes("=== بيانات"));
});

/** Fake client: `rows[table]` = rows returned for any filtered select; `fail` makes that table error. */
function fakeSb(rows: Record<string, unknown[]>, fail: string[] = []): SupabaseClient {
  return {
    from(table: string) {
      const q = {
        select: () => q, eq: () => q, gt: () => q,
        limit: () => Promise.resolve(fail.includes(table) ? { data: null, error: { message: "boom" } } : { data: rows[table] ?? [], error: null }),
      };
      return q;
    },
  } as unknown as SupabaseClient;
}

Deno.test("came back by opening the app or by a message, and a failed read counts as back", async () => {
  const at = "2026-11-15T17:00:00.000Z";
  assertEquals(await cameBackSince(fakeSb({}), "u", at), false);
  assertEquals(await cameBackSince(fakeSb({ zad_product_events: [{ id: 1 }] }), "u", at), true);
  assertEquals(await cameBackSince(fakeSb({ zad_chat_turns: [{ id: 1 }] }), "u", at), true);
  assertEquals(await cameBackSince(fakeSb({}, ["zad_chat_turns"]), "u", at), true);
  assertEquals(await cameBackSince(fakeSb({}), "u", ""), true);
});

Deno.test("an ask whose customer came back is no longer relevant", async () => {
  const row = { id: "m", user_id: "u", moment: "ignored_days", facts: { last_seen_at: "2026-11-15T17:00:00.000Z" }, attempts: 0, created_at: "" };
  assertEquals(await isStillRelevant(fakeSb({}), row as never), true);
  assertEquals(await isStillRelevant(fakeSb({ zad_product_events: [{ id: 1 }] }), row as never), false);
});
