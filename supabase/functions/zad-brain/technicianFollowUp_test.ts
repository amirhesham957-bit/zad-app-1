// سؤال في وقته (الموجة ٣): «صلحت الحنفية» ⇒ «مين السباك؟ أحفظه في الفنيين؟»، والرقم بيتحفظ بس لو العميل قاله.
import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { repairTradeOf, TECHNICIAN_ASK_MARK, technicianFollowUp } from "./homeEmergency.ts";
import { intentToolHints, scopeToolsForSpecialist } from "./specialists.ts";
import { freshContext, MUTATING_TOOLS, validateSaveTrustedTechnician, VALIDATORS, CHILD_BLOCKED_TOOLS } from "./validators.ts";
import { CHAT_TOOLS } from "./index.ts";

Deno.test("repair: a thing fixed in the past, or a tradesman who came, names the trade", () => {
  assertEquals(repairTradeOf("صلحت الحنفية النهارده"), "plumber");
  assertEquals(repairTradeOf("السباك جه وصلّح السيفون"), "plumber");
  assertEquals(repairTradeOf("الحمدلله التكييف اتصلح"), "ac");
  assertEquals(repairTradeOf("جالي الكهربائي وغيرلي الفيشة"), "electrician");
  assertEquals(repairTradeOf("ركبت كالون جديد للباب"), "locksmith");
  assertEquals(repairTradeOf("الغسالة اتصلحت أخيراً"), "appliances");
  assertEquals(repairTradeOf("صلحنا البوتاجاز"), "gas");
});

Deno.test("repair: wanting a fix, a broken thing, or an unrelated «جه» is not a repair", () => {
  assertEquals(repairTradeOf("عايز اصلح الحنفية"), null);
  assertEquals(repairTradeOf("هصلح التكييف بكرة"), null);
  // «صلحها» جوه «اصلحها» و«نصلحه»: مضارع مش ماضي.
  assertEquals(repairTradeOf("الحنفية بتنقط ولازم اصلحها"), null);
  assertEquals(repairTradeOf("التكييف محتاج نصلحه"), null);
  assertEquals(repairTradeOf("المية بتنزل من السقف"), null);
  assertEquals(repairTradeOf("جه الشتا بدري السنة دي"), null);
  // ماضي بس مفيش حاجة في البيت.
  assertEquals(repairTradeOf("صلحت الواجب مع ابني"), null);
});

const PRIOR_NONE: string[] = [];

Deno.test("follow-up: asked once, only when no technician of that trade is saved", () => {
  const block = technicianFollowUp("صلحت الحنفية", [], PRIOR_NONE);
  assertStringIncludes(block, "=== سؤال في وقته ===");
  assertStringIncludes(block, `«مين السباك؟ ${TECHNICIAN_ASK_MARK}؟»`);
  assertStringIncludes(block, "save_trusted_technician (trade = plumber)");
  assertStringIncludes(block, "ردّ على رسالته الأول");
  // عنده سباك ⇒ مفيش سؤال. عنده كهربائي بس ⇒ السؤال عن السباك لسه.
  assertEquals(technicianFollowUp("صلحت الحنفية", [{ name: "عم محمد", trade: "سباك" }], PRIOR_NONE), "");
  assert(technicianFollowUp("صلحت الحنفية", [{ name: "حسن", trade: "كهربائي" }], PRIOR_NONE).length > 0);
  // اتسأل قبل كده في المحادثة (حتى لو اتجاهل) ⇒ مايتسألش تاني.
  assertEquals(technicianFollowUp("السباك جه تاني", [], ["تمام! مين السباك؟ أحفظه في الفنيين؟"]), "");
  assertEquals(technicianFollowUp("عامل إيه", [], PRIOR_NONE), "");
});

Deno.test("follow-up: the answer to the question brings the tool, in any specialist", () => {
  assert(intentToolHints("اسمه محمد ورقمه 01001234567", "تمام! مين السباك؟ أحفظه في الفنيين؟").includes("save_trusted_technician"));
  assert(intentToolHints("سجل رقم السباك محمد ٠١٠٠١٢٣٤٥٦٧").includes("save_trusted_technician"));
  assert(!intentToolHints("اسمه محمد ورقمه 01001234567").includes("save_trusted_technician"));
  const tools = scopeToolsForSpecialist(CHAT_TOOLS, "general", null, ["save_trusted_technician"]);
  assert(tools.some((t) => t.name === "save_trusted_technician"));
});

Deno.test("save: the number has to be one the customer said — Zad never makes one up", () => {
  const ctx = freshContext("u");
  const input = { name: "عم محمد", trade: "plumber", phone: "01001234567" };
  ctx.heard = "صلحت الحنفية\nاسمه عم محمد ورقمه ٠١٠٠١٢٣٤٥٦٧";
  assertEquals(validateSaveTrustedTechnician(input, {}, ctx), { ok: true });
  // الرقم بشرطات أو مسافات زي ما قاله = نفس الرقم.
  ctx.heard = "رقمه 0100-123-4567";
  assertEquals(validateSaveTrustedTechnician(input, {}, ctx), { ok: true });
  ctx.heard = "اسمه عم محمد بس مش فاكر رقمه";
  assertEquals((validateSaveTrustedTechnician(input, {}, ctx) as { ok: boolean }).ok, false);
  // من غير كلام العميل خالص (مسار مش شات) ⇒ مرفوض.
  assertEquals((validateSaveTrustedTechnician(input, {}, freshContext("u")) as { ok: boolean }).ok, false);
});

Deno.test("save: the table's own limits, checked before the write", () => {
  const ctx = freshContext("u");
  ctx.heard = "01001234567";
  const ok = (over: Record<string, unknown>) =>
    (validateSaveTrustedTechnician({ name: "عم محمد", trade: "plumber", phone: "01001234567", ...over }, {}, ctx) as { ok: boolean }).ok;
  assert(ok({}));
  assert(!ok({ name: "م" }));
  assert(!ok({ trade: "doctor" }));
  assert(!ok({ phone: "مش عارف" }));
  assert(!ok({ notes: "x".repeat(121) }));
  ctx.counts["save_trusted_technician"] = 3;
  assert(!ok({}));
});

Deno.test("save: wired as a mutating tool, kept from a child's account", () => {
  assert(VALIDATORS.save_trusted_technician === validateSaveTrustedTechnician);
  assert(MUTATING_TOOLS.includes("save_trusted_technician"));
  assert(CHILD_BLOCKED_TOOLS.includes("save_trusted_technician"));
  const tool = CHAT_TOOLS.find((t) => t.name === "save_trusted_technician");
  assert(tool);
  assertEquals((tool.input_schema as { required: string[] }).required, ["name", "trade", "phone"]);
});
