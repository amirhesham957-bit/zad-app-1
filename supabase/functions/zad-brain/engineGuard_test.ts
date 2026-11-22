import { assertEquals } from "jsr:@std/assert@1";
import { ENGINE_TOOLS, guardEngineReply, templateFrom } from "./engineGuard.ts";

const out = {
  tool: "restock_on_budget",
  content: "الميزانية: 300 جنيه.\nاشتري (180 جنيه، يفضل 120 جنيه):\n- رز — 60 جنيه\n- زيت — 120 جنيه\nالأرقام دي بس اللي تتقال.",
};

Deno.test("reply using only engine numbers passes untouched", () => {
  const r = guardEngineReply("اشتري الرز بـ60 والزيت بـ120، الإجمالي 180 ويفضل 120.", "معايا 300", [out]);
  assertEquals(r.replaced, false);
});

Deno.test("Arabic-Indic digits are the same numbers", () => {
  assertEquals(guardEngineReply("الرز ٦٠ والزيت ١٢٠", "معايا ٣٠٠", [out]).replaced, false);
});

Deno.test("an invented number replaces the reply with the engine's own text", () => {
  const r = guardEngineReply("اشتري الرز بـ75 والزيت بـ120", "معايا 300", [out]);
  assertEquals(r.replaced, true);
  assertEquals(r.unknown, [75]);
  assertEquals(r.reply.includes("رز — 60 جنيه"), true);
  assertEquals(r.reply.includes("الأرقام دي بس"), false);
});

Deno.test("a number the customer said is allowed", () => {
  assertEquals(guardEngineReply("زي ما قلت 450 هنشوف", "ميزانيتي 450", [out]).replaced, false);
});

Deno.test("no engine tool this turn: never touches the reply", () => {
  const r = guardEngineReply("رصيدك 9999", "رصيدي؟", [{ tool: "get_balance", content: "رصيد 100" }]);
  assertEquals(r.replaced, false);
  assertEquals(guardEngineReply("رصيدك 9999", "؟", []).replaced, false);
});

Deno.test("a refused engine call has no template: reply untouched", () => {
  const r = guardEngineReply("هنعمل 500", "؟", [{ tool: "plan_menu", content: "مرفوض: dishes لازم قايمة" }]);
  assertEquals(r.replaced, false);
});

Deno.test("free small numbers do not trip it", () => {
  assertEquals(guardEngineReply("خلال 3 أيام، 100% مضمون", "؟", [out]).replaced, false);
});

Deno.test("empty reply and template cleanup", () => {
  assertEquals(guardEngineReply("  ", "؟", [out]).replaced, false);
  assertEquals(templateFrom([{ tool: "plan_menu", content: "أ\nقول للعميل كده\nالأرقام دي بس" }]), "أ");
  assertEquals(ENGINE_TOOLS.has("plan_menu") && ENGINE_TOOLS.has("restock_on_budget"), true);
});
