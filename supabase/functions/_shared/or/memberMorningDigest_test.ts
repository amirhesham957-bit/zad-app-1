import { assertEquals } from "jsr:@std/assert@1";
import { buildHouseholdDigests, buildMemberDigest, type DigestItem } from "./memberMorningDigest.ts";
import { findMatrixLeaks } from "./crossMemberLeak.ts";
import type { Subject } from "./visibilityMatrix.ts";

const F = "f";
const parent: Subject = { id: "p", minor: false, guardian: true, familyId: F };
const adult: Subject = { id: "a", minor: false, guardian: false, familyId: F };
const kid: Subject = { id: "k", minor: true, guardian: false, familyId: F };
const items: DigestItem[] = [
  { id: "kid-goal", subject: kid, domain: "goals", text: "هدف سلمى", value: 5, cost: 1 },
  { id: "kid-spend", subject: kid, domain: "spending", text: "مصروف سلمى", value: 9, cost: 1 },
  { id: "adult-spend", subject: adult, domain: "spending", text: "مصروف أ", value: 9, cost: 1 },
  { id: "adult-med-private", subject: { ...adult, medicinePrivate: true }, domain: "medicines", text: "دوا خاص", value: 9, cost: 1, critical: true },
  { id: "own-task", subject: parent, domain: "tasks", text: "مهمتي", value: 1, cost: 1 },
];

Deno.test("child gets only own goal: nothing about others, not even critical items", () => {
  const d = buildMemberDigest(kid, items, {}, 10);
  assertEquals(d.send.map((i) => i.id), ["kid-goal"]);
  assertEquals(d.hidden.length, 4);
});

Deno.test("child sees own task and goal", () => {
  const own: DigestItem[] = [
    { id: "g", subject: kid, domain: "goals", text: "", value: 1, cost: 1 },
    { id: "m", subject: kid, domain: "medicines", text: "", value: 1, cost: 1 },
  ];
  assertEquals(buildMemberDigest(kid, own, {}, 5).send.map((i) => i.id), ["g"]);
});

Deno.test("guardian: child goal yes, child spending needs consent, adult private medicine never (even critical)", () => {
  const d = buildMemberDigest(parent, items, {}, 10);
  assertEquals(d.send.map((i) => i.id).sort(), ["kid-goal", "own-task"]);
  assertEquals(d.hidden.sort(), ["adult-med-private", "adult-spend", "kid-spend"]);
  const c = buildMemberDigest(parent, items, { k: { spending: true } }, 10);
  assertEquals(c.send.map((i) => i.id).includes("kid-spend"), true);
});

Deno.test("attention budget applies after visibility, per member", () => {
  const d = buildMemberDigest(parent, items, { k: { spending: true } }, 1);
  assertEquals(d.send.map((i) => i.id), ["kid-spend"]);
  assertEquals(d.deferred.sort(), ["kid-goal", "own-task"]);
  const all = buildHouseholdDigests([parent, kid], items, {}, { p: 1 }, 2);
  assertEquals(all.map((x) => x.memberId), ["p", "k"]);
});

Deno.test("a built digest never leaks against the matrix", () => {
  const consent = { k: { spending: true } };
  for (const to of [parent, adult, kid]) {
    const d = buildMemberDigest(to, items, consent, 10);
    const sources = d.send.map((i) => ({ subject: i.subject, domain: i.domain }));
    assertEquals(findMatrixLeaks([{ to, text: "", sources, consentBy: consent }]), []);
  }
});

Deno.test("matrix leak detector catches a leaked source", () => {
  assertEquals(findMatrixLeaks([{ to: adult, text: "x", sources: [{ subject: kid, domain: "spending" }] }]).length, 1);
});
