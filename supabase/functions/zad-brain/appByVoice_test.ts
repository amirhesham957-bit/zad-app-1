// ZAD_PLAN ١٠.٢(أ) شريحة ١: اللي بيتعمل من شاشة يتعمل بالكلام — منطقة اللهجة من «ملفي»،
// مفاتيح الإعدادات (نداءات زادو، صورة الأكل)، و«انسى» من شاشة الذاكرة.
import { assert, assertEquals } from "jsr:@std/assert@1";
import { sanitizeProfilePatch } from "../_shared/customerProfile.ts";
import { intentToolHints } from "./specialists.ts";
import { freshContext, MUTATING_TOOLS, validateTool } from "./validators.ts";

Deno.test("the Saudi region from «ملفي» can be set by talking, with the same five values as the column", () => {
  for (const region of ["SA_HIJAZ", "SA_NAJD", "SA_EAST", "SA_SOUTH", "GENERAL"]) {
    const { patch, rejected } = sanitizeProfilePatch({ dialect_region: region });
    assertEquals(rejected, []);
    assertEquals(patch.dialect_region, region);
  }
  assertEquals(sanitizeProfilePatch({ dialect_region: "sa_najd" }).patch.dialect_region, "SA_NAJD");
  // Anything else would break the column's check and the whole profile write with it.
  assertEquals(sanitizeProfilePatch({ dialect_region: "SA_RIYADH" }).rejected, ["dialect_region"]);
  // null = back to the city, as the «ملفي» chip does.
  const clear = sanitizeProfilePatch({ dialect_region: null }).patch;
  assert("dialect_region" in clear);
  assertEquals(clear.dialect_region, null);
});

Deno.test("asking for a dialect brings the profile tool", () => {
  for (const msg of ["كلمني حجازي", "اتكلم معايا نجدي لو سمحت", "أنا شرقاوي", "لهجتي جنوبي"]) {
    assert(intentToolHints(msg).includes("update_customer_profile"), msg);
  }
});

Deno.test("an app setting is set by talking: two switches, a boolean, no more than twice a turn", async () => {
  const ctx = freshContext("u1");
  const ok = (input: Record<string, unknown>) => validateTool("set_app_setting", input, {}, ctx);
  assertEquals((await ok({ setting: "pet_calls", on: false })).ok, true);
  assertEquals((await ok({ setting: "food_pattern", on: true })).ok, true);
  assertEquals((await ok({ setting: "notifications", on: false })).ok, false);
  assertEquals((await ok({ setting: "pet_calls", on: "no" })).ok, false);
  ctx.counts["set_app_setting"] = 2;
  assertEquals((await ok({ setting: "pet_calls", on: true })).ok, false);
  assert(MUTATING_TOOLS.includes("set_app_setting"));
});

Deno.test("«stop Zado calling me» and «bring back the food picture» bring the settings tool", () => {
  for (const msg of ["بطّل زادو ينده عليا", "وقف النداءات", "رجّع صورة الأكل", "شيل صورة الأكل من الرئيسية"]) {
    assert(intentToolHints(msg).includes("set_app_setting"), msg);
  }
  assertEquals(intentToolHints("زادو عامل ايه").includes("set_app_setting"), false);
});

Deno.test("forgetting takes one note the customer can see, never an invented id", async () => {
  const snap = { memory: [{ id: "m1", note: "بيحب السمك" }, { id: "m2", note: "شغله محاسب" }] };
  const ctx = freshContext("u1");
  assertEquals((await validateTool("delete_memory", { memory_id: "m1" }, snap, ctx)).ok, true);
  assertEquals((await validateTool("delete_memory", { memory_id: "m9" }, snap, freshContext("u1"))).ok, false);
  assertEquals((await validateTool("delete_memory", {}, snap, freshContext("u1"))).ok, false);
  ctx.counts["delete_memory"] = 1;
  assertEquals((await validateTool("delete_memory", { memory_id: "m2" }, snap, ctx)).ok, false);
  assert(MUTATING_TOOLS.includes("delete_memory"));
});

Deno.test("«forget that…» brings the forget tool, «I forgot» does not", () => {
  for (const msg of ["انسى إني بحب السمك", "امسح اللي قلتهولك عن شغلي", "شيل ده من ذاكرتك", "ماتفتكرش موضوع الدكتور"]) {
    assert(intentToolHints(msg).includes("delete_memory"), msg);
  }
  for (const msg of ["نسيت أسجل القهوة", "إنسان طيب"]) {
    assertEquals(intentToolHints(msg).includes("delete_memory"), false, msg);
  }
});
