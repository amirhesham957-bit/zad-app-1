import { assert, assertEquals } from "jsr:@std/assert@1";
import { familyPersonaBlock, familyPersonaEnabled, redactFamilyForPersona, markOwn } from "./familyPersona.ts";

const fam = {
  mine: { role: "parent", alias: "أحمد", balance: 100, savings_goal: 500 },
  members: [
    { alias: "أحمد", role: "parent", balance: 100, savings_goal: 500, online_now: true },
    { alias: "منى", role: "parent", balance: 9999, savings_goal: 777, online_now: false },
  ],
  goals: [{ target: 1000, current: 200, month: "2026-11", reward: null }],
};
const on = (k: string) => (k === "ZAD_FAMILY_PERSONA" ? "1" : undefined);
const off = () => undefined;

Deno.test("closed by default: no block, zero tokens", () => {
  assertEquals(familyPersonaEnabled(off), false);
  assertEquals(familyPersonaBlock({ family: fam }, off), "");
});

Deno.test("open: block present with privacy rules, no other member numbers", () => {
  const b = familyPersonaBlock({ family: fam }, on);
  assert(b.includes("بيرسونا العيلة"));
  assert(b.includes("ماتقولش رصيده"));
  assert(!b.includes("9999") && !b.includes("777"));
});

Deno.test("no block: no family, single member, child account", () => {
  assertEquals(familyPersonaBlock({ family: null }, on), "");
  assertEquals(familyPersonaBlock({ family: { ...fam, members: [fam.members[0]] } }, on), "");
  assertEquals(familyPersonaBlock({ family: { ...fam, mine: { ...fam.mine, role: "child" } } }, on), "");
});

Deno.test("redact: others' numbers gone, own `mine` and household goals kept", () => {
  const r = redactFamilyForPersona(fam);
  assertEquals(r.mine, fam.mine);
  assertEquals(r.goals, fam.goals);
  const json = JSON.stringify(r.members);
  assert(!json.includes("9999") && !json.includes("777") && !json.includes("balance") && !json.includes("savings_goal"));
  assertEquals(r.members![1].alias, "منى");
  assertEquals(redactFamilyForPersona(null), null);
});

Deno.test("redact: أشجار التسبيحة بتاعة فرد تاني بتتشال، وبتاعتي وغير المعلّمة (الأمان أولاً)", () => {
  const fam = {
    members: [{ alias: "أ" }, { alias: "ب" }],
    tasbiha: [markOwn({ name: "شجرتي" }, true), markOwn({ name: "شجرة_ب" }, false), { name: "بلا_علامة" }],
    chores: [{ title: "غسيل" }], goals: [{ target: 5 }],
  };
  const r = redactFamilyForPersona(fam);
  assertEquals(r.tasbiha.map((t: { name: string }) => t.name), ["شجرتي"]);
  assertEquals(r.chores.length, 1);
  assertEquals(r.goals.length, 1);
  assertEquals(JSON.stringify(r).includes("شجرة_ب"), false);
  assertEquals(JSON.stringify(r).includes('"own"'), false);
});
