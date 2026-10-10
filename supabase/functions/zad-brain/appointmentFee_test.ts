// ميعاد دكتور ⇒ مبلغ الكشف في «المحجوز» (الموجة ٣، 20261010190000): التكلفة اللي العميل قالها بس.
import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { freshContext, validateAddAppointment, validateUpdateAppointment } from "./validators.ts";
import { CHAT_TOOLS } from "./index.ts";

const SOON = new Date(Date.now() + 3 * 86_400_000).toISOString().replace(/\.\d+Z$/, "Z");
const add = (over: Record<string, unknown>, heard?: string) => {
  const ctx = freshContext("u");
  if (heard !== undefined) ctx.heard = heard;
  return validateAddAppointment({ title: "دكتور الأسنان", starts_at: SOON, kind: "medical", ...over }, {}, ctx) as { ok: boolean; reason?: string };
};

Deno.test("appointment fee: reserved only when it is the number the customer said", () => {
  assert(add({ expected_cost: 400 }, "عندي دكتور الأسنان الخميس والكشف بـ400").ok);
  assert(add({ expected_cost: 400 }, "الكشف بـ٤٠٠").ok);
  assert(add({ expected_cost: 1200 }, "الكشف ١٬٢٠٠ جنيه").ok);
  const guessed = add({ expected_cost: 400 }, "عندي دكتور الأسنان الخميس");
  assertEquals(guessed.ok, false);
  assertStringIncludes(guessed.reason!, "الكشف بكام؟");
  // بالحروف = مش رقم اتقال؛ يتسأل بالرقم.
  assertEquals(add({ expected_cost: 400 }, "الكشف بأربعمية").ok, false);
  // برّه الشات (مفيش كلام عميل) = مرفوض.
  assertEquals(add({ expected_cost: 400 }).ok, false);
});

Deno.test("appointment fee: no fee is fine, a bad one isn't", () => {
  assert(add({}, "عندي دكتور الخميس").ok);
  assert(add({ expected_cost: null }, "x").ok);
  for (const bad of [0, -50, 2_000_000, "مش عارف"]) assertEquals(add({ expected_cost: bad }, "0 -50 2000000").ok, false, String(bad));
});

Deno.test("appointment fee: the answer to «الكشف بكام؟» is an update on its own, and null lifts it", () => {
  const ctx = freshContext("u");
  ctx.heard = "دكتور الأسنان\n٣٥٠";
  const id = "00000000-0000-0000-0000-000000000001";
  assertEquals(validateUpdateAppointment({ appointment_id: id, expected_cost: 350 }, {}, ctx), { ok: true });
  assertEquals(validateUpdateAppointment({ appointment_id: id, expected_cost: null }, {}, ctx), { ok: true });
  assertEquals((validateUpdateAppointment({ appointment_id: id, expected_cost: 500 }, {}, ctx) as { ok: boolean }).ok, false);
  assertEquals((validateUpdateAppointment({ appointment_id: id }, {}, ctx) as { ok: boolean }).ok, false);
});

Deno.test("appointment fee: both tools take it, and a medical visit without one is asked once", () => {
  const tool = (name: string) => CHAT_TOOLS.find((t) => t.name === name)!;
  const addProps = (tool("add_appointment").input_schema as { properties: Record<string, { type: string; nullable?: boolean }> }).properties;
  const updProps = (tool("update_appointment").input_schema as { properties: Record<string, { type: string; nullable?: boolean }> }).properties;
  assertEquals(addProps.expected_cost.type, "number");
  // Gemini takes «nullable», not a type array.
  assertEquals([updProps.expected_cost.type, updProps.expected_cost.nullable], ["number", true]);
  assertStringIncludes(tool("add_appointment").description, "«الكشف بكام؟ أحجزه من المتاح»");
});
