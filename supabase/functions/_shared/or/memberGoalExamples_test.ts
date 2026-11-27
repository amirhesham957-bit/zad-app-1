import { assert, assertEquals } from "jsr:@std/assert";
import { gymSessionsInWindow, ownedOrShared, pickWithinAllowance, proteinFromPantry, supplementRunout, tasteScore } from "./memberGoalExamples.ts";

Deno.test("privacy: ownedOrShared keeps own + explicitly shared only", () => {
  const rows = [{ id: "a", member_id: "me" }, { id: "b", member_id: "bro" }, { id: "c", member_id: "bro" }];
  assertEquals(ownedOrShared(rows, "me").map((r) => r.id), ["a"]);
  assertEquals(ownedOrShared(rows, "me", new Set(["c"])).map((r) => r.id), ["a", "c"]);
});

Deno.test("protein: unknown values are listed, not guessed", () => {
  const p = proteinFromPantry([
    { name: "بيض", quantity: 10, proteinPerUnitG: 6 }, { name: "تونة", quantity: 2, proteinPerUnitG: 25 },
    { name: "فراخ", quantity: 1 }, { name: "رز", quantity: 3, proteinPerUnitG: 0 }, { name: "لبن", quantity: 0, proteinPerUnitG: 8 },
  ], 150);
  assertEquals([p.coveredG, p.shortfallG], [110, 40]);
  assertEquals(p.usable, ["بيض", "تونة"]);
  assertEquals(p.unknownProtein, ["فراخ"]);
});

Deno.test("supplement runout", () => {
  assertEquals(supplementRunout(30, 2, "2026-11-27"), { daysLeft: 15, runsOutOn: "2026-12-12", reorderBy: "2026-12-09" });
  assertEquals(supplementRunout(30, 0, "2026-11-27"), null);
  assertEquals(supplementRunout(2, 1, "2026-11-27")!.reorderBy, "2026-11-27");
});

Deno.test("gym sessions: window, status, title", () => {
  const a = [
    { title: "جيم", starts_at: "2026-11-28T17:00:00Z", status: "upcoming" },
    { title: "تمرين رجل", starts_at: "2026-11-30T17:00:00Z" },
    { title: "جيم", starts_at: "2026-11-29T17:00:00Z", status: "cancelled" },
    { title: "دكتور", starts_at: "2026-11-29T10:00:00Z" },
    { title: "جيم", starts_at: "2026-12-20T17:00:00Z" },
  ];
  assertEquals(gymSessionsInWindow(a, "2026-11-27T00:00:00Z"), { count: 2, dates: ["2026-11-28", "2026-11-30"] });
});

Deno.test("allowance: taste first, never over budget", () => {
  const sig = [{ text: "عايزة روج", kind: "asked" as const }, { text: "اشترت بيجامة ستان", kind: "bought" as const }];
  const cands = [{ name: "روج مات", price: 150 }, { name: "بيجامة ستان", price: 300 }, { name: "ماسكارا", price: 100 }];
  assert(tasteScore(cands[1], sig) > tasteScore(cands[0], sig));
  const r = pickWithinAllowance(cands, 400, sig);
  assertEquals(r.picks.map((c) => c.name), ["بيجامة ستان", "ماسكارا"]);
  assertEquals([r.spent, r.left, r.skippedOverBudget], [400, 0, ["روج مات"]]);
  assertEquals(pickWithinAllowance(cands, 0, sig).picks, []);
});
