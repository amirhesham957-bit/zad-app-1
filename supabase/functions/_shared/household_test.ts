import { assertEquals } from "jsr:@std/assert@1";
import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { householdFamilyId, householdFilter } from "./household.ts";

Deno.test("household filter: the account alone, or the account and its family", () => {
  assertEquals(householdFilter("u1", null), "user_id.eq.u1");
  assertEquals(householdFilter("u1", "f1"), "user_id.eq.u1,family_id.eq.f1");
});

function fakeSb(row: unknown, error: unknown = null): SupabaseClient {
  const chain: Record<string, unknown> = {};
  for (const m of ["select", "eq", "limit"]) chain[m] = () => chain;
  chain.maybeSingle = () => Promise.resolve({ data: row, error });
  return { from: () => chain } as unknown as SupabaseClient;
}

Deno.test("household family: the membership's family, null without one or on a failed read", async () => {
  assertEquals(await householdFamilyId(fakeSb({ family_id: "f1" }), "u1"), "f1");
  assertEquals(await householdFamilyId(fakeSb(null), "u1"), null);
  assertEquals(await householdFamilyId(fakeSb(null, { message: "down" }), "u1"), null);
});
