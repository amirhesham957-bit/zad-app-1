import { assert, assertEquals, assertStringIncludes } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { canSeeFamilySpending } from "./familyAccess.ts";
import { executeTool } from "./index.ts";
import { freshContext } from "./validators.ts";

Deno.test("parents see the family's spending", () => {
  for (const role of ["admin", "parent", "owner", "Admin "]) {
    assertEquals(canSeeFamilySpending(role), true, role);
  }
});

Deno.test("a child or a plain member does not", () => {
  for (const role of ["child", "member", "", null, undefined]) {
    assertEquals(canSeeFamilySpending(role), false, String(role));
  }
});

/** A Supabase client that answers from fixed rows and records which tables were read. */
function fakeFamily(role: string, grants: string[] = []) {
  const touched: string[] = [];
  const rows: Record<string, unknown[]> = {
    zad_family_shares: grants.map((owner_id) => ({ owner_id })),
    family_members: [
      { user_id: "me", alias: "سارة", family_id: "f1", role },
      { user_id: "dad", alias: "بابا", family_id: "f1", role: "admin" },
    ],
    zad_transactions: [
      { user_id: "me", amount: 50, category: "بقالة", created_at: "2026-09-20" },
      { user_id: "dad", amount: 400, category: "بقالة", created_at: "2026-09-21" },
    ],
  };
  const from = (table: string) => {
    touched.push(table);
    let filterUser: string | null = null;
    const b: any = {
      select: () => b, gte: () => b, in: () => b, ilike: () => b, limit: () => b, order: () => b,
      eq: (col: string, v: string) => { if (col === "user_id") filterUser = v; return b; },
      maybeSingle: () => Promise.resolve({
        data: (rows[table] ?? []).find((r: any) => r.user_id === filterUser) ?? null, error: null,
      }),
      then: (ok: (v: unknown) => unknown) => Promise.resolve({ data: rows[table] ?? [], error: null }).then(ok),
    };
    return b;
  };
  return { sb: { from } as any, touched };
}

Deno.test("family_mediation refuses a child and never reads the family's transactions", async () => {
  const { sb, touched } = fakeFamily("child");
  const out = await executeTool(sb, "me", "family_mediation", {}, {}, freshContext("me"), {} as any);
  assertStringIncludes(out, "لمدير العيلة");
  assert(!touched.includes("zad_transactions"), touched.join(","));
});

Deno.test("family_mediation works for the admin once the others agreed", async () => {
  const { sb, touched } = fakeFamily("admin", ["dad"]);
  const out = await executeTool(sb, "me", "family_mediation", {}, {}, freshContext("me"), {} as any);
  assert(touched.includes("zad_transactions"));
  assertStringIncludes(out, "بقالة");
});

Deno.test("an admin alone is not enough: nobody agreed, nobody's spending is read (2026-10-01)", async () => {
  const { sb, touched } = fakeFamily("admin");
  const out = await executeTool(sb, "me", "family_mediation", {}, {}, freshContext("me"), {} as any);
  assertStringIncludes(out, "محدش من العيلة وافق");
  assert(!touched.includes("zad_transactions"), touched.join(","));
});

import { visibleSpenders } from "./familyAccess.ts";

Deno.test("family spending shows the viewer and whoever agreed, not every member (2026-10-01)", () => {
  const members = [{ user_id: "dad" }, { user_id: "son" }, { user_id: "daughter" }];
  assertEquals(visibleSpenders("dad", members, []).map((m) => m.user_id), ["dad"]);
  assertEquals(visibleSpenders("dad", members, ["daughter"]).map((m) => m.user_id), ["dad", "daughter"]);
});
