import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { inventoryOwnerFilter, pickInventoryRow } from "./inventoryRow.ts";

const me = "u1";
const fam = "f1";

Deno.test("two rows with the same name: the newest of the customer's own wins", () => {
  const rows = [
    { id: "old", user_id: me, family_id: fam, created_at: "2026-09-01T10:00:00Z" },
    { id: "new", user_id: me, family_id: fam, created_at: "2026-09-20T10:00:00Z" },
  ];
  assertEquals(pickInventoryRow(rows, me, fam)?.id, "new");
});

Deno.test("the customer's own row beats a family member's newer one", () => {
  const rows = [
    { id: "mine", user_id: me, family_id: null, created_at: "2026-09-01T10:00:00Z" },
    { id: "theirs", user_id: "u2", family_id: fam, created_at: "2026-09-25T10:00:00Z" },
  ];
  assertEquals(pickInventoryRow(rows, me, fam)?.id, "mine");
});

Deno.test("a row of the customer's with no family_id is still found while in a family", () => {
  const rows = [{ id: "mine", user_id: me, family_id: null, created_at: "2026-09-01T10:00:00Z" }];
  assertEquals(pickInventoryRow(rows, me, fam)?.id, "mine");
});

Deno.test("only a family member's row: it is the one", () => {
  const rows = [{ id: "theirs", user_id: "u2", family_id: fam, created_at: "2026-09-25T10:00:00Z" }];
  assertEquals(pickInventoryRow(rows, me, fam)?.id, "theirs");
});

Deno.test("another household's row is never picked", () => {
  const rows = [{ id: "stranger", user_id: "u9", family_id: "f9", created_at: "2026-09-25T10:00:00Z" }];
  assertEquals(pickInventoryRow(rows, me, fam), null);
  assertEquals(pickInventoryRow(rows, me, null), null);
});

Deno.test("no rows: null", () => {
  assertEquals(pickInventoryRow([], me, fam), null);
  assertEquals(pickInventoryRow(null, me, null), null);
});

Deno.test("owner filter: own rows, plus the family's when there is one", () => {
  assertEquals(inventoryOwnerFilter(me, null), "user_id.eq.u1");
  assertEquals(inventoryOwnerFilter(me, fam), "user_id.eq.u1,family_id.eq.f1");
});
