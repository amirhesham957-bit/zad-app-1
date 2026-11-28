import { assertEquals } from "jsr:@std/assert@1";
import { canSee, type Domain, type Person, type Subject } from "./visibilityMatrix.ts";

const F = "fam1";
const parent: Person = { id: "parent", minor: false, guardian: true, familyId: F };
const adult: Person = { id: "adult", minor: false, guardian: false, familyId: F };
const other: Subject = { id: "other", minor: false, guardian: false, familyId: F };
const child: Subject = { id: "kid", minor: true, guardian: false, familyId: F };
const stranger: Person = { id: "x", minor: false, guardian: true, familyId: "fam2" };

Deno.test("child sees only own tasks and goals", () => {
  const all: Domain[] = ["tasks", "goals", "spending", "budget_total", "medicines", "inventory"];
  assertEquals(all.filter((d) => canSee(child, child, d)), ["tasks", "goals"]);
});

Deno.test("child sees nobody else, even with consent", () => {
  assertEquals(canSee(child, other, "tasks", { tasks: true }), false);
  assertEquals(canSee(child, parent, "inventory"), false);
});

Deno.test("guardian sees child tasks and goals; the rest needs the child's share", () => {
  assertEquals(canSee(parent, child, "tasks"), true);
  assertEquals(canSee(parent, child, "goals"), true);
  assertEquals(canSee(parent, child, "spending"), false);
  assertEquals(canSee(parent, child, "spending", { spending: true }), true);
  assertEquals(canSee(parent, child, "medicines", { medicines: true }), true);
});

Deno.test("an adult's spending, tasks and goals need explicit consent", () => {
  assertEquals(canSee(adult, other, "spending"), false);
  assertEquals(canSee(adult, other, "tasks"), false);
  assertEquals(canSee(adult, other, "goals"), false);
  assertEquals(canSee(adult, other, "spending", { spending: true }), true);
  assertEquals(canSee(adult, other, "goals", { tasks: true }), true);
  // a parent has no special right over another adult
  assertEquals(canSee(parent, other, "spending"), false);
});

Deno.test("household pharmacy is open to adults unless private; consent opens private", () => {
  assertEquals(canSee(adult, other, "medicines"), true);
  assertEquals(canSee(adult, { ...other, medicinePrivate: true }, "medicines"), false);
  assertEquals(canSee(adult, { ...other, medicinePrivate: true }, "medicines", { medicines: true }), true);
});

Deno.test("family budget total is for adults only and never crosses families", () => {
  assertEquals(canSee(adult, other, "budget_total"), true);
  assertEquals(canSee(adult, child, "budget_total"), false);
  assertEquals(canSee(stranger, other, "budget_total"), false);
  assertEquals(canSee(stranger, other, "medicines"), false);
});
