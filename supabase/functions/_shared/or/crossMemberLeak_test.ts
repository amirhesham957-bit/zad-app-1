import { assertEquals } from "jsr:@std/assert@1";
import { findCrossMemberLeaks, isCrossMemberLeak, type OutgoingMessage } from "./crossMemberLeak.ts";

const consent = { m1: true, m2: false };

Deno.test("محتوى الفرد نفسه مش تسريب", () => {
  const msg: OutgoingMessage = { toMemberId: "m1", text: "x", sourceMemberIds: ["m1"] };
  assertEquals(isCrossMemberLeak(msg, consent), false);
});

Deno.test("محتوى فرد تاني موافق عليه ما يتعدّش تسريب", () => {
  const msg: OutgoingMessage = { toMemberId: "m2", text: "x", sourceMemberIds: ["m1"] };
  assertEquals(isCrossMemberLeak(msg, consent), false);
});

Deno.test("محتوى فرد تاني ما وافقش ⇒ تسريب", () => {
  const msg: OutgoingMessage = { toMemberId: "m1", text: "x", sourceMemberIds: ["m2"] };
  assertEquals(isCrossMemberLeak(msg, consent), true);
});

Deno.test("فرد مش موجود في الخريطة ⇒ تسريب (fail closed)", () => {
  const msg: OutgoingMessage = { toMemberId: "m1", text: "x", sourceMemberIds: ["m9"] };
  assertEquals(isCrossMemberLeak(msg, consent), true);
});

Deno.test("مصادر مختلطة: يكفي مصدر واحد غير موافق", () => {
  const msg: OutgoingMessage = { toMemberId: "m1", text: "x", sourceMemberIds: ["m1", "m2"] };
  assertEquals(isCrossMemberLeak(msg, consent), true);
});

Deno.test("بدون مصادر ⇒ مش تسريب", () => {
  const msg: OutgoingMessage = { toMemberId: "m1", text: "x", sourceMemberIds: [] };
  assertEquals(isCrossMemberLeak(msg, consent), false);
});

Deno.test("findCrossMemberLeaks: بيرجّع الرسايل المتسرّبة بس، والعدد 0 لما مفيش", () => {
  const messages: OutgoingMessage[] = [
    { toMemberId: "m1", text: "a", sourceMemberIds: ["m1"] },
    { toMemberId: "m1", text: "b", sourceMemberIds: ["m2"] },
    { toMemberId: "m2", text: "c", sourceMemberIds: ["m1"] },
  ];
  assertEquals(findCrossMemberLeaks(messages, consent).map((m) => m.text), ["b"]);
  assertEquals(findCrossMemberLeaks([messages[0], messages[2]], consent).length, 0);
});
