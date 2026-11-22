import { assertEquals } from "jsr:@std/assert@1";
import { chorePlan } from "./chorePlan.ts";

const FAM = "f0000000-0000-0000-0000-00000000000f";
/** عميل وهمي: كل جدول بيرجع صفوفه بعد فلترة eq البسيطة. */
function fake(tables: Record<string, Array<Record<string, unknown>>>) {
  return {
    from(t: string) {
      let rows = [...(tables[t] ?? [])];
      const q = {
        select: () => q,
        eq: (k: string, v: unknown) => { rows = rows.filter((r) => r[k] === v); return q; },
        limit: () => q,
        then: (res: (x: { data: unknown; error: null }) => unknown) => res({ data: rows, error: null }),
      };
      return q;
    },
  } as never;
}
const tables = {
  family_members: [
    { id: "m-dad", user_id: "u-dad", alias: "بابا", role: "admin", family_id: FAM },
    { id: "m-sara", user_id: "u-sara", alias: "سارة", role: "member", family_id: FAM },
  ],
  family_chores: [
    { id: "c1", title: "غسيل المواعين", minutes: 30, family_id: FAM, is_completed: false },
    { id: "c2", title: "كنس الصالة", minutes: 20, family_id: FAM, is_completed: false },
    { id: "c3", title: "خلصت", minutes: 20, family_id: FAM, is_completed: true },
  ],
  family_chore_preferences: [{ member_id: "m-dad", family_id: FAM, minutes_per_week: 60, dislikes: ["غسيل المواعين"], likes: [] }],
};

Deno.test("chore_plan: only a member of that family gets a plan, whatever family_id the client sends", async () => {
  assertEquals((await chorePlan(fake(tables), "u-stranger", FAM)).status, 403);
  assertEquals((await chorePlan(fake(tables), "u-dad", "not-a-uuid")).status, 400);
});

Deno.test("chore_plan: open chores only, preferences applied, names attached", async () => {
  const out = await chorePlan(fake(tables), "u-sara", FAM);
  assertEquals(out.status, 200);
  const a = out.body.assignments as Array<{ chore_id: string; member_id: string; member_name: string }>;
  assertEquals(a.length, 2);
  assertEquals(a.find((x) => x.chore_id === "c1")?.member_name, "سارة");
  assertEquals(a.find((x) => x.chore_id === "c2")?.member_id, "m-dad");
  assertEquals((out.body.load as Array<{ member_id: string; week: number }>).find((l) => l.member_id === "m-dad")?.week, 60);
});
