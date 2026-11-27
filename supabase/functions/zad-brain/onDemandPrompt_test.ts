// م٤.٣ — eval حتمي (من غير موديل) لتحميل القواعد والأدوات عند الطلب. بيمشي على الـ٢٠٠ حالة في evals/cases.ts:
// الأداة المتوقعة لازم تفضل معروضة، وقاعدتها تفضل في البرومبت، وحجم السياق ينزل. الدقة الحقيقية (الموديل بيستجيب
// صح؟) بتتقاس بليلة الـeval الحية (acceptance probe) قبل ما ZAD_ONDEMAND_PROMPT يتفتح في الإنتاج.
import { assert, assertEquals } from "jsr:@std/assert@1";
import { buildChatSystemPrompt, CHAT_TOOLS, INTENT_RULE_TOOLS, ruleToolsFor, toolsForCall } from "./index.ts";
import { intentToolHints, routeSpecialists, scopeToolsForSpecialist, specialistPromptBlock } from "./specialists.ts";
import { soulBlock } from "./soul.ts";
import { EVAL_CASES } from "./evals/cases.ts";

const SNAP = { currency: "EGP", country: "EG", name_asked_in_conversation: true };

function withFlag<T>(on: boolean, f: () => T): T {
  const prev = Deno.env.get("ZAD_ONDEMAND_PROMPT");
  if (on) Deno.env.set("ZAD_ONDEMAND_PROMPT", "1"); else Deno.env.delete("ZAD_ONDEMAND_PROMPT");
  try { return f(); } finally { if (prev === undefined) Deno.env.delete("ZAD_ONDEMAND_PROMPT"); else Deno.env.set("ZAD_ONDEMAND_PROMPT", prev); }
}

function turn(message: string, on: boolean) {
  return withFlag(on, () => {
    const { primary, secondary } = routeSpecialists(message);
    const hinted = intentToolHints(message, "");
    const scoped = scopeToolsForSpecialist(CHAT_TOOLS, primary, secondary, hinted, message);
    const chat = buildChatSystemPrompt(SNAP, false, ruleToolsFor(scoped, hinted));
    const tools = toolsForCall(scoped, hinted, [], 0);
    const chars = JSON.stringify(tools).length + chat.length + soulBlock(undefined).length + (specialistPromptBlock(primary, secondary) ?? "").length;
    return { scoped, hinted, chat, tools, tok: Math.round(chars / 3.5) };
  });
}

Deno.test("م٤.٣ on-demand: expected tools stay offered, rules for them stay, context shrinks", () => {
  const off: number[] = [], on: number[] = [];
  let lostRule = 0, leanExpected = 0, expectedTools = 0;
  for (const c of EVAL_CASES) {
    const a = turn(c.message, false), b = turn(c.message, true);
    off.push(a.tok); on.push(b.tok);
    const e = c.expect as { proposes?: string; executes?: string };
    const want = e.proposes ?? e.executes;
    if (!want) continue;
    expectedTools++;
    assert(b.scoped.some((t) => t.name === want), `${c.id}: ${want} not offered`);
    // الأداة موجودة دايماً في الاتنين؛ لو خفيفة فالـschema بأنواعها لسه موجود.
    const sent = b.tools.find((t) => t.name === want)!;
    assert(sent.input_schema, `${c.id}: ${want} lost its schema`);
    if (sent.description !== CHAT_TOOLS.find((t) => t.name === want)!.description) leanExpected++;
    if (INTENT_RULE_TOOLS.has(want) && a.scoped.some((t) => t.name === want) && !b.hinted.includes(want)) lostRule++;
  }
  off.sort((x, y) => x - y); on.sort((x, y) => x - y);
  const q = (r: number[], p: number) => r[Math.min(r.length - 1, Math.floor(r.length * p))];
  console.log(`[م٤.٣ ondemand] cases=${EVAL_CASES.length} expectedTool=${expectedTools} leanExpected=${leanExpected} lostRule=${lostRule}\n  off p50=${q(off, .5)} p90=${q(off, .9)}  on p50=${q(on, .5)} p90=${q(on, .9)} (tok, no snapshot)`);
  assertEquals(lostRule, 0);
  assert(q(on, .5) < q(off, .5), "on-demand must shrink the median turn");
});

Deno.test("م٤.٣ on-demand: money tool and hinted tools stay full; flag off = unchanged", () => {
  const msg = "صرفت ٥٠ على القهوة";
  const on = turn(msg, true), off = turn(msg, false);
  const full = (r: ReturnType<typeof turn>, n: string) => r.tools.find((t) => t.name === n)?.description === CHAT_TOOLS.find((t) => t.name === n)?.description;
  assert(full(on, "log_transaction"));
  assert(!full(on, "add_inventory_item") || !on.scoped.some((t) => t.name === "add_inventory_item"));
  assert(full(off, "add_inventory_item") || !off.scoped.some((t) => t.name === "add_inventory_item"));
  const rec = turn("اطبخ ايه النهارده", true);
  assert(rec.chat.includes("suggest_recipes"), "recipe rule loads on recipe intent");
  assert(!turn("صرفت ٥٠ على القهوة", true).chat.includes("suggest_recipes"), "recipe rule absent without intent");
});

// م٤.٣ الخطوة ٢ — نطاق أضيق لكل تخصص: القفل = نفس الأدوات بالظبط (مع الرسالة وبدونها)، والفتح بيشيل أدوات التعديل
// والمسح بس لو مفيش فعل تعديل ولا نية، وفعل التعديل بيرجّعها.
Deno.test("م٤.٣ specialty scope: flag closed = identical tool set; open defers edit/delete until intent", () => {
  for (const c of EVAL_CASES) {
    const { primary, secondary } = routeSpecialists(c.message);
    const hinted = intentToolHints(c.message, "");
    const names = (msg?: string) => withFlag(false, () => scopeToolsForSpecialist(CHAT_TOOLS, primary, secondary, hinted, msg).map((t) => t.name));
    assertEquals(names(c.message), names(undefined), `${c.id}: closed flag must not change the tool set`);
    assertEquals(names(undefined), scopeToolsForSpecialist(CHAT_TOOLS, primary, secondary, hinted).map((t) => t.name), c.id);
  }
  const names = (msg: string) => withFlag(true, () => {
    const { primary, secondary } = routeSpecialists(msg);
    return scopeToolsForSpecialist(CHAT_TOOLS, primary, secondary, intentToolHints(msg, ""), msg).map((t) => t.name);
  });
  assert(!names("مصاريف الشهر ده كام وايه القسط الجاي").includes("delete_obligation"));
  assert(names("امسح القسط ده").includes("delete_obligation"), "edit verb brings delete back");
  assert(names("عدل القسط بتاعي").includes("update_obligation"));
  assert(withFlag(true, () => scopeToolsForSpecialist(CHAT_TOOLS, "finance", null, []).some((t) => t.name === "delete_obligation")), "no message = full scope");
});
